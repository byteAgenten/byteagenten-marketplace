"""Prompt builder for each workflow phase."""

import json
import re
import subprocess
from pathlib import Path

from .codebase import read_context
from .config import Phase, Scope, WorkflowConfig

# Directory containing agent definition files (copied from bytA)
_AGENTS_DIR = Path(__file__).parent / "agents"

# Minimal fallback instructions for phases without agent files
PHASE_FALLBACK: dict[int, str] = {
    7: (
        "You are a PR writer. Your task is to create a compelling pull request draft.\n\n"
        "Analyze the changes made in this workflow:\n"
        "1. Run `git diff {from_branch}...HEAD --stat` to see all changed files\n"
        "2. Run `git diff {from_branch}...HEAD` to see the actual changes\n"
        "3. Read the existing specs in .workflow/specs/ for context\n"
        "4. Read the GitHub issue from .workflow/issue.json\n\n"
        "Then write a PR draft to `.workflow/pr-draft.md` with this EXACT format:\n\n"
        "```\n"
        "# PR Draft\n\n"
        "## Title\n"
        "feat(#{issue}): <concise title>\n\n"
        "## Summary\n"
        "<2-3 sentences explaining WHAT was built and WHY, from the user's perspective>\n\n"
        "## Changes\n"
        "<grouped by layer: Database, Backend, Frontend — each with bullet points>\n\n"
        "## Design Decisions\n"
        "<key architectural choices and their rationale>\n\n"
        "## Testing\n"
        "<what was tested, test coverage notes>\n\n"
        "## Screenshots / Notes\n"
        "<any additional context for reviewers>\n"
        "```\n\n"
        "Write a thorough, reviewer-friendly draft. This will be reviewed by the user\n"
        "before the PR is actually created. Focus on explaining the WHY, not just the WHAT."
    ),
    8: (
        "IMPORTANT: You are running in AUTOMATED HEADLESS MODE. "
        "Execute ALL commands directly. Do NOT ask for confirmation. "
        "Do NOT present plans or proposals. Just DO it.\n\n"
        "Read the approved PR draft from `.workflow/pr-draft.md` and execute these steps:\n\n"
        "1. Read `.workflow/pr-draft.md` to get the PR title and body.\n\n"
        "2. Stage ALL changes:\n"
        "   git add -A\n\n"
        "3. Commit with the title from the PR draft:\n"
        "   git commit -m '<title from PR draft>'\n\n"
        "4. Push the branch:\n"
        "   git push -u origin feature/issue-{issue}\n\n"
        "5. Create the PR using the FULL body from the draft:\n"
        '   gh pr create --base {from_branch} '
        "--title '<title from draft>' "
        "--body '<full body from draft>'\n\n"
        "6. Capture the PR URL from gh output and update workflow-state.json:\n"
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


# Max total characters for pre-read file content (avoid prompt bloat)
_PRE_READ_LIMIT = 60_000


def _extract_file_paths(spec_content: str) -> list[str]:
    """Extract file paths mentioned in the plan spec.

    Matches patterns like:
    - `backend/src/main/.../Foo.java`
    - `frontend/src/app/.../bar.component.ts`
    - **File:** `some/path.java`
    """
    # Match paths that look like project files (contain / and a file extension)
    pattern = r'(?:backend|frontend)/[\w/.-]+\.\w+'
    matches = re.findall(pattern, spec_content)
    # Deduplicate while preserving order
    seen: set[str] = set()
    result: list[str] = []
    for m in matches:
        if m not in seen:
            seen.add(m)
            result.append(m)
    return result


def _git_changed_files(project_dir: Path, base_branch: str) -> list[str]:
    """Get list of files changed on the current branch vs base branch."""
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", f"{base_branch}...HEAD"],
            capture_output=True, text=True,
            cwd=str(project_dir), timeout=10,
        )
        if result.returncode == 0:
            return [f for f in result.stdout.strip().splitlines() if f]
    except Exception:
        pass

    # Fallback: uncommitted changes
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"],
            capture_output=True, text=True,
            cwd=str(project_dir), timeout=10,
        )
        if result.returncode == 0:
            files = [f for f in result.stdout.strip().splitlines() if f]
            # Also include untracked files
            result2 = subprocess.run(
                ["git", "ls-files", "--others", "--exclude-standard"],
                capture_output=True, text=True,
                cwd=str(project_dir), timeout=10,
            )
            if result2.returncode == 0:
                files.extend(f for f in result2.stdout.strip().splitlines() if f)
            return files
    except Exception:
        pass

    return []


def _read_files_content(project_dir: Path, file_paths: list[str]) -> str:
    """Read file contents up to the character limit, return formatted block."""
    parts: list[str] = []
    total_chars = 0

    for rel_path in file_paths:
        full_path = project_dir / rel_path
        if not full_path.exists() or not full_path.is_file():
            continue
        # Skip binary / large files
        if full_path.suffix in (".class", ".jar", ".png", ".jpg", ".gif", ".pdf", ".lock"):
            continue
        try:
            content = full_path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        if total_chars + len(content) > _PRE_READ_LIMIT:
            remaining = _PRE_READ_LIMIT - total_chars
            if remaining > 500:  # only include if we can fit something meaningful
                content = content[:remaining] + "\n... (truncated)"
                parts.append(f"### {rel_path}\n```\n{content}\n```")
            parts.append(f"\n_Stopped pre-reading: character limit reached ({_PRE_READ_LIMIT:,} chars)_")
            break

        parts.append(f"### {rel_path}\n```\n{content}\n```")
        total_chars += len(content)

    return "\n\n".join(parts)


def _pre_read_files(phase: Phase, config: WorkflowConfig, project_dir: Path) -> str:
    """Pre-read relevant files for a phase to reduce agent exploration turns.

    Phase 0, 7: no pre-reading
    Phase 1-3:  files mentioned in the plan spec (existing ones only)
    Phase 4:    changed files + their test counterparts
    Phase 5-6:  all git-changed files (for review/audit)
    """
    if phase.number in (0, 8):
        return ""

    files_to_read: list[str] = []

    if phase.number in (1, 2, 3):
        # Extract file paths from the plan spec
        specs_dir = project_dir / ".workflow" / "specs"
        plan_files = list(specs_dir.glob("*plan-consolidated.md")) if specs_dir.exists() else []
        if plan_files:
            spec_content = plan_files[0].read_text(encoding="utf-8", errors="replace")
            all_paths = _extract_file_paths(spec_content)

            # Filter by phase scope
            if phase.number == 1:
                # DB phase: migration files + entity files
                files_to_read = [
                    p for p in all_paths
                    if "/migration/" in p or "/entity/" in p or "/model/" in p
                ]
            elif phase.number == 2:
                # Backend: all backend files
                files_to_read = [p for p in all_paths if p.startswith("backend/")]
            elif phase.number == 3:
                # Frontend: all frontend files
                files_to_read = [p for p in all_paths if p.startswith("frontend/")]

    elif phase.number == 4:
        # Tests: read changed files + find corresponding test files
        changed = _git_changed_files(project_dir, config.from_branch)
        for f in changed:
            files_to_read.append(f)
            # Auto-find test counterpart
            if f.endswith(".java") and "/test/" not in f:
                test_path = f.replace("/main/", "/test/").replace(".java", "Test.java")
                if test_path not in files_to_read:
                    files_to_read.append(test_path)
            elif f.endswith(".ts") and ".spec." not in f:
                spec_path = f.replace(".ts", ".spec.ts")
                if spec_path not in files_to_read:
                    files_to_read.append(spec_path)

    elif phase.number in (5, 6, 7):
        # Security + Review + PR Draft: all changed files
        files_to_read = _git_changed_files(project_dir, config.from_branch)

    if not files_to_read:
        return ""

    content = _read_files_content(project_dir, files_to_read)
    if not content:
        return ""

    return content


def _architecture_update_instructions(phase: Phase, project_dir: Path) -> str:
    """Generate instructions for the agent to update architecture.md."""
    arch_file = project_dir / ".workflow" / "context" / "architecture.md"
    rel_path = ".workflow/context/architecture.md"

    # Read-only / non-code phases don't update architecture
    if phase.number in (5, 6, 7, 8):  # Security, Review, PR Draft, Push
        return ""

    sections_by_phase: dict[int, str] = {
        0: "Entities & Data Model, API Endpoints, Frontend Components, Key Patterns & Conventions, Relationships & Dependencies",
        1: "Entities & Data Model (new tables, columns, constraints, relationships)",
        2: "API Endpoints (new/changed endpoints with HTTP methods and paths), Key Patterns & Conventions",
        3: "Frontend Components (new/changed components, routes, services)",
        4: "Key Patterns & Conventions (test patterns, test utilities)",
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
        phase_context.append(
            "IMPORTANT — Spec format requirement:\n"
            "Your spec MUST begin with a `## Executive Summary` section.\n"
            "This summary is displayed to the user in the terminal UI as the basis for\n"
            "their Approve/Feedback decision. It must be detailed enough to judge the plan.\n\n"
            "Structure the summary with these 5 paragraphs (use ### sub-headings):\n\n"
            "### What & Why\n"
            "What does the feature do from the user's perspective? Why is it needed?\n"
            "(2-3 sentences, no technical details)\n\n"
            "### Architecture Approach\n"
            "Which architectural approach did you choose? Which existing codebase patterns\n"
            "are you following and WHY is that the right choice? What alternatives did you\n"
            "consider and why were they rejected?\n"
            "(2-4 sentences, be specific about pattern names and file locations)\n\n"
            "### Scope of Changes\n"
            "Which layers are affected? How many files per layer (new vs modified)?\n"
            "Format as a compact list:\n"
            "- **Database:** 1 new migration (V*__add_column.sql)\n"
            "- **Backend:** 5 files (2 new, 3 modified) — Repository, Service, DTO, Controller\n"
            "- **Frontend:** 4 files (1 new, 3 modified) — Component, Service, Model, Template\n\n"
            "### Key Design Decisions\n"
            "The 2-3 most important decisions with rationale. Each as one sentence:\n"
            "- Decision X because Y (not Z because W)\n\n"
            "### Risks & Mitigations\n"
            "What could go wrong? How does the design handle it?\n"
            "(1-3 bullet points)\n\n"
            "Example:\n"
            "## Executive Summary\n\n"
            "### What & Why\n"
            "This feature adds a \"Last Entry\" column to the project list and sorts projects\n"
            "by most recent activity, so users immediately see the projects they are actively\n"
            "working on instead of scrolling through an alphabetical list.\n\n"
            "### Architecture Approach\n"
            "The implementation follows the exact same batch-query-then-map pattern already\n"
            "established for `usedHours`, `memberCount`, and `primaryContactName` in\n"
            "`ProjectService.getProjects()`. A new JPQL batch query in `TimeEntryRepository`\n"
            "fetches `MAX(created_at)` grouped by `project_id`, and the result is mapped into\n"
            "a new `lastTimeEntryAt` field on `ProjectDto`. DB-level sorting was considered but\n"
            "rejected because the codebase consistently uses `ProjectService.sortProjects()`\n"
            "for all 9 existing sort fields — mixing approaches would create inconsistency.\n\n"
            "### Scope of Changes\n"
            "- **Database:** 1 new Flyway migration (add `last_time_entry_at` view or query)\n"
            "- **Backend:** 4 files modified — TimeEntryRepository, ProjectService, ProjectDto, ProjectController\n"
            "- **Frontend:** 3 files modified — project-list component, project model, project service\n\n"
            "### Key Design Decisions\n"
            "- Using `created_at` instead of `date` because it answers \"when was this project last\n"
            "  touched in the system\" and provides `LocalDateTime` for relative display (\"vor 2 Stunden\")\n"
            "- In-memory sorting via `sortProjects()` instead of DB ORDER BY to stay consistent with\n"
            "  all existing sort fields\n\n"
            "### Risks & Mitigations\n"
            "- Adding a field to `ProjectDto` (Java record) breaks all existing test constructors —\n"
            "  mechanical fix, no logic impact\n"
            "- Performance: batch query scales O(n) with projects, acceptable at current data volume\n"
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
        # PR Draft phase — needs from_branch for git diff
        phase_context.append(f"Base branch for diff: {config.from_branch}")
        phase_context.append(
            f"Write the PR draft to: .workflow/pr-draft.md"
        )
    elif phase.number == 8:
        # Push & PR phase — needs from_branch for push target
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

    # 5. Phase Summary instruction (all phases that write a spec)
    if phase.number not in (0, 8):
        # Phase 0 has its own Executive Summary format; Phase 8 has no spec
        _summary_hints: dict[int, str] = {
            1: "What migrations were created (or skipped and why). Tables/columns affected.",
            2: "What endpoints, services, entities were created or modified. Key implementation patterns used.",
            3: "What components, routes, services were created or modified. UX decisions made.",
            4: "Test results: how many tests, pass/fail, coverage achieved. What was tested (unit, integration, e2e).",
            5: "Security findings by severity (critical/high/medium/low). Key recommendations.",
            6: "Code quality assessment. Issues found by severity. Overall recommendation (approve/needs-work).",
            7: "Brief note on what the PR covers and key points for reviewers.",
        }
        hint = _summary_hints.get(phase.number, "What was done and what the user should know.")
        parts.extend([
            "",
            "## IMPORTANT: Phase Summary in Spec File",
            "Your spec file MUST begin with a `## Phase Summary` section (3-5 sentences).\n"
            "This summary is displayed to the user in the terminal UI so they can follow\n"
            "the progress of the workflow without reading the full spec.\n\n"
            f"Focus on: {hint}\n\n"
            "Be specific — name actual files, endpoints, components, not vague descriptions.\n"
            "Write as prose, not bullet points. Keep it concise but informative.",
        ])

    # 6. Architecture update instructions (tells agent to update architecture.md)
    arch_instructions = _architecture_update_instructions(phase, project_dir)
    if arch_instructions:
        parts.append(arch_instructions)

    # 6. Pre-read files (reduces agent exploration turns)
    pre_read = _pre_read_files(phase, config, project_dir)
    if pre_read:
        parts.extend([
            "",
            "## Pre-Read Files (already loaded — do NOT re-read these)",
            "The following files are relevant to your task and pre-loaded for you.",
            "You can reference them directly without using the Read tool.",
            pre_read,
        ])

    # 7. Specs from previous phases
    specs = _read_specs(project_dir)
    if specs:
        parts.extend(["", "## Existing Specs (from previous phases)", specs])

    # 8. Workflow state
    state = _read_state(project_dir)
    if state:
        parts.extend(["", "## Current Workflow State", f"```json\n{state}\n```"])

    return "\n".join(parts)
