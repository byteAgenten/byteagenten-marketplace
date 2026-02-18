"""Team Planning Protocol for Phase 0.

Generates a prompt where the MAIN AGENT acts as the hub architect:
1. Spawns specialists (backend, frontend, quality) in parallel
2. Receives their summaries via SendMessage
3. Consolidates into plan-consolidated.md ITSELF
4. Cleans up team

Previous design spawned a separate architect sub-agent, but that caused
a deadlock: the architect's "Done" never reached the main agent because
SendMessage can only go to named teammates, not to the unnamed main agent.

Fix: Main agent IS the architect. Specialists send summaries directly to it.
"""

from .config import Scope, WorkflowConfig


def build_team_planning_prompt(config: WorkflowConfig) -> str:
    """Build the team planning protocol prompt for Phase 0.

    The main agent acts as the hub architect:
    1. TeamCreate a planning team
    2. Spawn specialists in parallel (scope-dependent)
    3. Wait for SendMessage summaries from each specialist
    4. Read full plans, validate consistency, write consolidated spec
    5. Cleanup: shutdown teammates + TeamDelete
    """
    issue_num = config.issue_num
    issue_title = config.issue_title
    scope = config.scope
    coverage = config.target_coverage
    team_name = f"bytcode-plan-{issue_num}"

    # --- Build specialist blocks based on scope ---
    specialists: list[str] = []
    specialist_names: list[str] = []
    plan_reads: list[str] = []
    plan_verify: list[str] = []

    if scope != Scope.FRONTEND_ONLY:
        specialists.append(_backend_specialist(issue_num, issue_title))
        specialist_names.append("backend")
        plan_reads.append(f"  - .workflow/specs/issue-{issue_num}-plan-backend.md")
        plan_verify.append(f"  .workflow/specs/issue-{issue_num}-plan-backend.md")

    if scope != Scope.BACKEND_ONLY:
        specialists.append(_frontend_specialist(issue_num, issue_title))
        specialist_names.append("frontend")
        plan_reads.append(f"  - .workflow/specs/issue-{issue_num}-plan-frontend.md")
        plan_verify.append(f"  .workflow/specs/issue-{issue_num}-plan-frontend.md")

    # Quality specialist is always present
    specialists.append(_quality_specialist(issue_num, issue_title, coverage))
    specialist_names.append("quality")
    plan_reads.append(f"  - .workflow/specs/issue-{issue_num}-plan-quality.md")
    plan_verify.append(f"  .workflow/specs/issue-{issue_num}-plan-quality.md")

    specialist_count = len(specialists)

    # --- Consolidation instructions (for main agent) ---
    consolidation = _consolidation_instructions(
        issue_num, issue_title, scope, coverage, plan_reads,
    )

    # --- Assemble full protocol ---
    specialist_blocks = "\n".join(specialists)
    verify_files = "\n".join(plan_verify)
    all_names = ", ".join(specialist_names)

    return f"""=== PHASE 0: TEAM PLANNING PROTOCOL ===

You are the ARCHITECT and CONSOLIDATOR. You spawn specialists, receive their
summaries, then consolidate everything into the final plan. Follow these steps EXACTLY:

## Step 1: Create Team

```
TeamCreate(team_name: "{team_name}")
```

If TeamCreate fails (Agent Teams not enabled), use the FALLBACK at the bottom.

## Step 2: Spawn Specialists in Parallel

Spawn ALL of the following agents IN PARALLEL in a SINGLE message with multiple Task calls:

{specialist_blocks}

## Step 3: Wait for Summaries

You will receive {specialist_count} SendMessage summaries from your specialists.
WAIT until you have received ALL {specialist_count} summaries before proceeding.
Each specialist writes their full plan to disk AND sends you a short summary.

DO NOT proceed to Step 4 until all {specialist_count} summaries have arrived.

## Step 4: Consolidate

After receiving ALL {specialist_count} summaries:

{consolidation}

## Step 5: Verify

Check that ALL these files exist (use Glob or Read):
  .workflow/specs/issue-{issue_num}-plan-consolidated.md
{verify_files}

## Step 6: Cleanup

Send shutdown_request to ALL teammates: {all_names}
Then: TeamDelete (ignore errors — agents may already be gone)

Say "Done."

---

## FALLBACK (if TeamCreate fails)

If TeamCreate throws an error, do the planning yourself as a single agent:
1. Read .workflow/issue.json
2. Analyze the codebase (backend + frontend)
3. Write the consolidated spec directly to .workflow/specs/issue-{issue_num}-plan-consolidated.md
4. Say "Done."
"""


def _backend_specialist(issue_num: int, title: str) -> str:
    return f"""--- Task: backend specialist ---
subagent_type: "bytA:spring-boot-developer"
name: "backend"
model: "sonnet"
run_in_background: true
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Analyze the existing codebase and create a backend implementation plan.
  Focus on: entities, repositories, services, controllers, DTOs, migrations.
  Read the GitHub issue from .workflow/issue.json first.
  Read existing backend code to understand patterns and conventions.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-backend.md
  Then send a SHORT SUMMARY (max 20 lines) to the team lead via SendMessage.
  Summary must include: new/modified entities, new endpoints (method + path), DTO changes.
  After sending, say 'Done.'
"""


def _frontend_specialist(issue_num: int, title: str) -> str:
    return f"""--- Task: frontend specialist ---
subagent_type: "bytA:angular-frontend-developer"
name: "frontend"
model: "sonnet"
run_in_background: true
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Analyze the existing codebase and create a frontend implementation plan.
  Focus on: components, services, models, routes, templates.
  Read the GitHub issue from .workflow/issue.json first.
  Read existing frontend code to understand patterns and conventions.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-frontend.md
  Then send a SHORT SUMMARY (max 20 lines) to the team lead via SendMessage.
  Summary must include: new/modified components, service changes, route changes.
  After sending, say 'Done.'
"""


def _quality_specialist(issue_num: int, title: str, coverage: int) -> str:
    return f"""--- Task: quality specialist ---
subagent_type: "bytA:test-engineer"
name: "quality"
model: "sonnet"
run_in_background: true
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Target Coverage: {coverage}%.
  Start with Existing Test Impact Analysis.
  Plan E2E scenarios, unit test strategy, integration test strategy.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-quality.md
  MUST include section: ## Existing Tests to Update
  Then send a SHORT SUMMARY (max 20 lines) to the team lead via SendMessage.
  Summary must include: count of existing tests that will break, new test count, coverage estimate.
  After sending, say 'Done.'
"""


def _consolidation_instructions(
    issue_num: int,
    title: str,
    scope: Scope,
    coverage: int,
    plan_reads: list[str],
) -> str:
    plan_files = "\n".join(plan_reads)

    # Scope-dependent sections
    sections: list[str] = [
        "## Executive Summary (structured with ### sub-headings, see below)",
        "## Architecture Overview",
        f"## Implementation Scope ({scope.value})",
        "## Existing Tests to Update (from quality plan)",
    ]
    if scope != Scope.FRONTEND_ONLY:
        sections.append("## API Contract")
        sections.append("## Data Model")
    if scope != Scope.BACKEND_ONLY:
        sections.append("## Frontend Structure")

    sections_str = "\n    ".join(sections)

    return f"""1. Read the full specialist plans from disk (one at a time):
{plan_files}

2. Validate CONSISTENCY between plans:
   - Endpoints match between backend and frontend (field names, types, URLs)
   - DTOs match (same field names, same types)
   - If CONFLICTS found: SendMessage to affected specialist, wait for correction

3. Write CONSOLIDATED SPEC to .workflow/specs/issue-{issue_num}-plan-consolidated.md
   MUST contain these sections:
    {sections_str}

   The Executive Summary MUST use this structure:
    ### What & Why (2-3 sentences, user perspective)
    ### Architecture Approach (2-4 sentences, patterns + rationale)
    ### Scope of Changes (bullet list: Database, Backend, Frontend with file counts)
    ### Key Design Decisions (2-3 decisions with rationale)
    ### Risks & Mitigations (1-3 bullet points)"""
