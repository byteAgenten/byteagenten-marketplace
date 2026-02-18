"""Prompt builder for each workflow phase."""

import json
import re
from pathlib import Path

from .codebase import read_context
from .config import Phase, Scope, WorkflowConfig

# Directory containing agent definition files (copied from bytA)
_AGENTS_DIR = Path(__file__).parent / "agents"

# Minimal fallback instructions for phases without agent files (e.g., Phase 7)
PHASE_FALLBACK: dict[int, str] = {
    7: (
        "IMPORTANT: You are running in AUTOMATED HEADLESS MODE. "
        "Execute ALL commands directly. Do NOT ask for confirmation. "
        "Do NOT present plans or proposals. Just DO it.\n\n"
        "Push all changes and create a pull request. Execute these steps:\n\n"
        "1. Stage ALL changes:\n"
        "   git add -A\n\n"
        "2. Commit with a descriptive message:\n"
        "   git commit -m 'feat(#{issue}): <title from issue>'\n\n"
        "3. Push the branch:\n"
        "   git push -u origin feature/issue-{issue}\n\n"
        "4. Create PR:\n"
        '   gh pr create --base {from_branch} '
        "--title 'feat(#{issue}): <title>' "
        "--body '<summary of changes>'\n\n"
        "5. Capture the PR URL from gh output and update workflow-state.json:\n"
        '   jq \'.prUrl = "THE_PR_URL"\' '
        ".workflow/workflow-state.json > /tmp/ws.json "
        "&& mv /tmp/ws.json .workflow/workflow-state.json\n\n"
        "Execute each step immediately. Do not stop to explain or ask."
    ),
}


def _read_agent(agent_name: str) -> str:
    """Read agent definition file, strip YAML frontmatter, return body."""
    agent_file = _AGENTS_DIR / f"{agent_name}.md"
    if not agent_file.exists():
        return ""

    content = agent_file.read_text(encoding="utf-8", errors="replace")

    # Strip YAML frontmatter (--- ... ---)
    stripped = re.sub(r"\A---\n.*?\n---\n*", "", content, count=1, flags=re.DOTALL)
    return stripped.strip()


def _scope_sections(scope: Scope) -> str:
    """Generate planning sections based on scope."""
    sections: list[str] = []
    if scope != Scope.FRONTEND_ONLY:
        sections.append("database schema changes")
        sections.append("backend API endpoints")
    if scope != Scope.BACKEND_ONLY:
        sections.append("frontend components")
    sections.append("test strategy")
    return " " + ", ".join(sections)


def _read_issue(project_dir: Path) -> str:
    """Read the persisted GitHub issue from .workflow/issue.json."""
    issue_file = project_dir / ".workflow" / "issue.json"
    if not issue_file.exists():
        return ""

    try:
        data = json.loads(issue_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return ""

    parts: list[str] = []
    parts.append(f"**#{data.get('number', '?')}: {data.get('title', 'Untitled')}**")

    labels = data.get("labels", [])
    if labels:
        label_names = ", ".join(l["name"] for l in labels)
        parts.append(f"Labels: {label_names}")

    body = data.get("body", "")
    if body:
        parts.append(f"\n{body}")

    return "\n".join(parts)


def _read_specs(project_dir: Path) -> str:
    """Read all existing spec files from .workflow/specs/."""
    specs_dir = project_dir / ".workflow" / "specs"
    if not specs_dir.exists():
        return ""

    parts: list[str] = []
    for f in sorted(specs_dir.glob("*.md")):
        content = f.read_text(encoding="utf-8", errors="replace")
        parts.append(f"### {f.name}\n{content}")

    return "\n\n".join(parts)


def _read_state(project_dir: Path) -> str:
    """Read workflow-state.json if it exists."""
    state_file = project_dir / ".workflow" / "workflow-state.json"
    if state_file.exists():
        return state_file.read_text(encoding="utf-8", errors="replace")
    return ""


def _architecture_update_instructions(phase: Phase, project_dir: Path) -> str:
    """Generate instructions for the agent to update architecture.md."""
    arch_file = project_dir / ".workflow" / "context" / "architecture.md"
    rel_path = ".workflow/context/architecture.md"

    # Read-only phases don't update architecture
    if phase.number in (5, 6):  # Security, Review — read-only analysis
        return ""

    sections_by_phase: dict[int, str] = {
        0: "Entities & Data Model, API Endpoints, Frontend Components, Key Patterns & Conventions, Relationships & Dependencies",
        1: "Entities & Data Model (new tables, columns, constraints, relationships)",
        2: "API Endpoints (new/changed endpoints with HTTP methods and paths), Key Patterns & Conventions",
        3: "Frontend Components (new/changed components, routes, services)",
        4: "Key Patterns & Conventions (test patterns, test utilities)",
        7: "",
    }

    sections = sections_by_phase.get(phase.number, "")
    if not sections:
        return ""

    return (
        f"\n\n## IMPORTANT: Update Architecture Context\n\n"
        f"After completing your main task, you MUST update `{rel_path}` "
        f"with what you built or changed.\n\n"
        f"Update these sections: {sections}\n\n"
        f"Be specific: list entity names with fields, endpoint paths with methods, "
        f"component names with their purpose. This context is read by subsequent "
        f"agents who need to understand what exists in the codebase.\n\n"
        f"Read the file first, then use Edit to update the relevant sections. "
        f"Keep existing content from previous phases — only ADD or UPDATE, never delete."
    )


def build_prompt(phase: Phase, config: WorkflowConfig, project_dir: Path) -> str:
    """Build the full prompt for a phase's Claude invocation.

    Structure:
    1. Phase header + metadata
    2. Codebase Context (structure.md + architecture.md)
    3. GitHub Issue (from .workflow/issue.json)
    4. Agent definition (from agents/*.md — full persona + instructions)
    5. Phase-specific context (scope, coverage, output paths)
    6. Architecture update instructions
    7. Existing specs from previous phases
    8. Current workflow state
    """
    issue_num = str(config.issue_num)

    parts: list[str] = [
        f"# Phase {phase.number}: {phase.name}",
        f"Agent: {phase.agent}",
        f"Issue: #{issue_num}",
        f"Scope: {config.scope.value}",
        f"Target Coverage: {config.target_coverage}%",
        f"Project directory: {project_dir}",
    ]

    # 1. Codebase context (structure + architecture)
    context = read_context(project_dir)
    if context:
        parts.extend(["", "## Codebase Context", context])

    # 2. Issue context
    issue_text = _read_issue(project_dir)
    if issue_text:
        parts.extend(["", "## GitHub Issue", issue_text])

    # 3. Agent definition (full persona from agents/*.md)
    agent_body = _read_agent(phase.agent)
    if agent_body:
        parts.extend(["", "## Agent Instructions", agent_body])
    else:
        # Fallback for phases without agent file (e.g., Phase 7 push-pr)
        fallback = PHASE_FALLBACK.get(phase.number, "")
        if fallback:
            fallback = fallback.replace("{issue}", issue_num)
            fallback = fallback.replace("{from_branch}", config.from_branch)
            parts.extend(["", "## Your Task", fallback])

    # 4. Phase-specific context
    phase_context: list[str] = []
    phase_context.append(f"Issue number for file naming: {issue_num}")
    phase_context.append(f"Scope: {config.scope.value}")

    if phase.number == 0:
        sections = _scope_sections(config.scope)
        phase_context.append(f"Plan must cover:{sections}")
        phase_context.append(
            f"Write plan to: .workflow/specs/issue-{issue_num}-plan-consolidated.md"
        )
    elif phase.number == 4:
        phase_context.append(f"Target coverage: {config.target_coverage}%")
        phase_context.append(
            "CRITICAL — After tests pass, you MUST update .workflow/workflow-state.json:\n"
            "Use this jq command to set the test results:\n"
            "```bash\n"
            'jq \'.phases["4"].context.testResults = '
            '{"allPassed": true, "reportFile": '
            f'"issue-{issue_num}-ph04-test-engineer.md"'
            "}'  .workflow/workflow-state.json > /tmp/ws.json "
            "&& mv /tmp/ws.json .workflow/workflow-state.json\n"
            "```\n"
            "This is required for phase verification to pass."
        )
    elif phase.number == 7:
        phase_context.append(f"PR base branch: {config.from_branch}")
        phase_context.append(
            "CRITICAL — After creating the PR, you MUST update .workflow/workflow-state.json:\n"
            "Use this jq command to set the PR URL:\n"
            "```bash\n"
            'jq \'.prUrl = "YOUR_PR_URL"\' '
            ".workflow/workflow-state.json > /tmp/ws.json "
            "&& mv /tmp/ws.json .workflow/workflow-state.json\n"
            "```\n"
            "This is required for phase verification to pass."
        )

    parts.extend(["", "## Phase Context", "\n".join(phase_context)])

    # 5. Architecture update instructions (tells agent to update architecture.md)
    arch_instructions = _architecture_update_instructions(phase, project_dir)
    if arch_instructions:
        parts.append(arch_instructions)

    # 6. Specs from previous phases
    specs = _read_specs(project_dir)
    if specs:
        parts.extend(["", "## Existing Specs (from previous phases)", specs])

    # 7. Workflow state
    state = _read_state(project_dir)
    if state:
        parts.extend(["", "## Current Workflow State", f"```json\n{state}\n```"])

    return "\n".join(parts)
