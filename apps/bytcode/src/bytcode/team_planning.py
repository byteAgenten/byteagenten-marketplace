"""Team Planning Protocol for Phase 0.

Generates a prompt that instructs the Claude session to spawn a team of
specialists (backend, frontend, quality) + a hub architect that consolidates
their findings into the final plan-consolidated.md.

This mirrors the bytA plugin's Team Planning Protocol but adapted for bytcode.
"""

from .config import Scope, WorkflowConfig


def build_team_planning_prompt(config: WorkflowConfig) -> str:
    """Build the team planning protocol prompt for Phase 0.

    The prompt instructs Claude to:
    1. TeamCreate a planning team
    2. Spawn specialists in parallel (scope-dependent)
    3. Specialists analyze and send summaries to the hub architect
    4. Hub architect consolidates into plan-consolidated.md
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

    # --- Hub architect ---
    hub = _hub_architect(
        issue_num, issue_title, scope, coverage,
        specialist_count, plan_reads,
    )

    # --- Assemble full protocol ---
    specialist_blocks = "\n".join(specialists)
    verify_files = "\n".join(plan_verify)
    all_names = ", ".join(specialist_names + ["architect"])

    return f"""=== PHASE 0: TEAM PLANNING PROTOCOL ===

You are the ORCHESTRATOR for team planning. Follow these steps EXACTLY:

## Step 1: Create Team

```
TeamCreate(team_name: "{team_name}")
```

If TeamCreate fails (Agent Teams not enabled), use the FALLBACK at the bottom.

## Step 2: Spawn ALL Agents in Parallel

Spawn ALL of the following agents IN PARALLEL in a SINGLE message with multiple Task calls:

{specialist_blocks}
{hub}

## Step 3: Wait

Wait for the architect's "Done." message. The architect is the last to finish
(waits for all specialists first).

## Step 4: Verify

Check that ALL these files exist:
  .workflow/specs/issue-{issue_num}-plan-consolidated.md
{verify_files}

If files are missing, warn but continue — verification happens externally.

## Step 5: Cleanup

Send shutdown_request to ALL teammates: {all_names}
Then: TeamDelete (ignore errors — agents may already be gone)

Say "Done."

---

## FALLBACK (if TeamCreate fails)

If TeamCreate throws an error:
1. Run the architect prompt below as a SINGLE agent (no team):
   Task(subagent_type: "bytA:architect-planner", prompt: "<architect prompt without SendMessage references>")
2. Say "Done."
"""


def _backend_specialist(issue_num: int, title: str) -> str:
    return f"""--- Task: backend specialist ---
subagent_type: "bytA:spring-boot-developer"
name: "backend"
model: "sonnet"
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Analyze the existing codebase and create a backend implementation plan.
  Focus on: entities, repositories, services, controllers, DTOs, migrations.
  Read the GitHub issue from .workflow/issue.json first.
  Read existing backend code to understand patterns and conventions.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-backend.md
  Then send a SHORT SUMMARY (max 20 lines) to teammate "architect" via SendMessage.
  Summary must include: new/modified entities, new endpoints (method + path), DTO changes.
  After sending, say 'Done.'
"""


def _frontend_specialist(issue_num: int, title: str) -> str:
    return f"""--- Task: frontend specialist ---
subagent_type: "bytA:angular-frontend-developer"
name: "frontend"
model: "sonnet"
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Analyze the existing codebase and create a frontend implementation plan.
  Focus on: components, services, models, routes, templates.
  Read the GitHub issue from .workflow/issue.json first.
  Read existing frontend code to understand patterns and conventions.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-frontend.md
  Then send a SHORT SUMMARY (max 20 lines) to teammate "architect" via SendMessage.
  Summary must include: new/modified components, service changes, route changes.
  After sending, say 'Done.'
"""


def _quality_specialist(issue_num: int, title: str, coverage: int) -> str:
    return f"""--- Task: quality specialist ---
subagent_type: "bytA:test-engineer"
name: "quality"
model: "sonnet"
prompt: |
  PLAN for Issue #{issue_num} - {title}.
  Target Coverage: {coverage}%.
  Start with Existing Test Impact Analysis.
  Plan E2E scenarios, unit test strategy, integration test strategy.
  Write your full plan to .workflow/specs/issue-{issue_num}-plan-quality.md
  MUST include section: ## Existing Tests to Update
  Then send a SHORT SUMMARY (max 20 lines) to teammate "architect" via SendMessage.
  Summary must include: count of existing tests that will break, new test count, coverage estimate.
  After sending, say 'Done.'
"""


def _hub_architect(
    issue_num: int,
    title: str,
    scope: Scope,
    coverage: int,
    specialist_count: int,
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

    return f"""--- Task: hub architect ---
subagent_type: "bytA:architect-planner"
name: "architect"
model: "opus"
prompt: |
  PLAN (Consolidator) for Issue #{issue_num} - {title}.
  Target Coverage: {coverage}%.
  Scope: {scope.value}

  You are the HUB in a Hub-and-Spoke planning team.
  You will receive {specialist_count} plan summaries via SendMessage from teammates.
  WAIT for ALL {specialist_count} summaries before proceeding.

  After receiving all summaries:
  1. Read full plans from disk (one at a time):
{plan_files}
  2. Validate CONSISTENCY between plans:
     - Endpoints match between backend and frontend (field names, types, URLs)
     - DTOs match (same field names, same types)
  3. If CONFLICTS found: SendMessage to affected specialist, wait for correction
  4. Write CONSOLIDATED SPEC to .workflow/specs/issue-{issue_num}-plan-consolidated.md
     MUST contain these sections:
    {sections_str}

  The Executive Summary MUST use this structure:
    ### What & Why (2-3 sentences, user perspective)
    ### Architecture Approach (2-4 sentences, patterns + rationale)
    ### Scope of Changes (bullet list: Database, Backend, Frontend with file counts)
    ### Key Design Decisions (2-3 decisions with rationale)
    ### Risks & Mitigations (1-3 bullet points)

  After writing consolidated spec, say 'Done.'
"""
