---
description: Start a full-stack feature workflow with a fixed 4-agent team and cross-validation.
author: byteagent - Hans Pickelmann
---

# bytM Full-Stack Feature Workflow

## YOUR ROLE

You are the **TEAM LEAD** coordinating specialized agents through 4 rounds: **PLAN -> IMPLEMENT -> VERIFY -> SHIP**.

You are in **DELEGATE MODE**: you coordinate, you do NOT write code or explore the codebase.

---

## EXECUTION MODEL: TeamCreate + Round-Scoped Agents

Each round spawns **fresh teammates** via `Task` with `team_name`. Within a round, agents communicate via `SendMessage`. Between rounds, agents are shut down and information flows via `.workflow/specs/` files.

```
Round N:
  1. Spawn teammates (Task with team_name + name)
  2. Agents work in parallel, communicate via SendMessage
  3. Agents write results to .workflow/specs/
  4. shutdown_request to all round agents
  5. WIP commit

Round N+1:
  1. Spawn FRESH teammates (clean context!)
  2. They read previous round's specs from disk
  ...
```

**Why fresh per round:** Persistent agents accumulate context across rounds and hit overflow by Round 3-4. Fresh agents get a clean 200k context window every round.

---

## AGENT TYPES + MODEL STRATEGY

The user chooses a **model tier** at startup: `fast` (Sonnet) or `quality` (Opus). This is stored in `workflow-state.json` as `modelTier` and determines the `{MODEL}` variable used in all Task calls.

| Tier | Model | Best for |
|------|-------|----------|
| `fast` (default) | sonnet | Standard-Features, CRUD, einfache UI |
| `quality` | opus | Komplexe Business-Logik, verschachtelte State-Patterns, Performance-kritisch |

| Subagent Type | Role | Used In |
|---------------|------|---------|
| `bytM:architect-planner` | Tech spec, API design, consolidation | Plan |
| `bytM:spring-boot-developer` | Spring Boot, DB, backend tests | Plan, Implement |
| `bytM:angular-frontend-developer` | Angular, routing, state management | Plan, Implement |
| `bytM:ui-designer` | Wireframes (HTML), Material Design, data-testid | Plan (optional) |
| `bytM:test-engineer` | E2E tests, test strategy, coverage | Plan, Verify |
| `bytM:security-auditor` | OWASP security audit | Verify |
| `bytM:code-reviewer` | Code review, quality gates, build verification | Verify |

Agents automatically receive their expertise, CLAUDE.md, MCP servers, and tools via `subagent_type`. You do NOT include domain expertise in prompts.

**IMPORTANT:** Always pass `model: "{MODEL}"` when spawning agents via Task. `{MODEL}` = `"sonnet"` for tier `fast`, `"opus"` for tier `quality`. Do NOT omit the model parameter — otherwise agents inherit Opus from the Team Lead.

---

## STARTUP SEQUENCE

### Step 1: Check for existing workflow

```bash
if [ -f .workflow/workflow-state.json ]; then
  STATUS=$(jq -r '.status // "unknown"' .workflow/workflow-state.json)
  ROUND=$(jq -r '.currentRound // "unknown"' .workflow/workflow-state.json)
  ISSUE=$(jq -r '.issue.number // "?"' .workflow/workflow-state.json)
  echo "EXISTING_WORKFLOW: status=$STATUS round=$ROUND issue=#$ISSUE"
else
  echo "NO_WORKFLOW"
fi
```

- `active|paused|awaiting_approval`: Show status, ask Resume or Abort?
- `completed`: `rm -rf .workflow`, continue
- `NO_WORKFLOW`: continue

### Step 2: Gather info from user

Parse `$ARGUMENTS` for issue number. If not provided, ask for it.

Then use `AskUserQuestion` to collect ALL 4 settings in ONE call (4 questions):

**Question 1 — Base Branch:**
- header: "Branch"
- question: "Von welchem Branch soll abgezweigt werden?"
- options: `main (Recommended)` | `develop`
- (User kann auch eigenen Branch eingeben via "Other")

**Question 2 — Coverage Target:**
- header: "Coverage"
- question: "Welches Test-Coverage-Ziel?"
- options: `70% (Recommended)` | `80%` | `90%`

**Question 3 — Model Tier:**
- header: "Model"
- question: "Welches Model-Tier fuer die Agents?"
- options: `fast (Recommended)` — Sonnet, schnell und kosteneffizient | `quality` — Opus, maximale Code-Qualitaet fuer komplexe Logik

**Question 4 — UI Designer:**
- header: "UI Design"
- question: "UI Designer (Wireframe + data-testid) einschließen?"
- options: `Ja (Recommended)` — Wireframe HTML + data-testid Planung durch UI-Designer Agent | `Nein` — Kein Wireframe, Frontend-Developer plant data-testid selbst

Store all values. Map model tier: `fast` → `MODEL = "sonnet"`, `quality` → `MODEL = "opus"`. Store UI Designer choice as `uiDesigner: true/false`.

### Step 3: Load issue + create branch

```bash
gh issue view {N} --json number,title,body,labels,assignees,milestone
git fetch --prune && git checkout {FROM_BRANCH} && git pull origin {FROM_BRANCH}
git checkout -b feature/issue-{N}-{slug} {FROM_BRANCH}
```

### Step 4: Initialize workflow

```bash
mkdir -p .workflow/logs .workflow/specs .workflow/recovery
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
```

Create `.workflow/workflow-state.json`:
```json
{
  "workflow": "bytM-feature",
  "status": "active",
  "ownerSessionId": "",
  "issue": { "number": "N", "title": "...", "body": "..." },
  "branch": "feature/issue-N-slug",
  "fromBranch": "main",
  "coverageTarget": 70,
  "modelTier": "fast",
  "uiDesigner": true,
  "currentRound": "plan",
  "context": {}
}
```

### Step 5: Create team

```
TeamCreate(team_name: "bytm-{N}")
```

---

## ROUND 1: PLAN — Hub-and-Spoke (4-5 Agents)

The Architect acts as **hub**: specialists plan their domain, send summaries to the Architect, who consolidates everything into a unified tech spec. With ui-designer: 4 specialists + 1 architect = 5 agents. Without: 3 specialists + 1 architect = 4 agents.

### Spawn teammates in parallel

Launch `Task` calls in a **single message** (parallel). Spawn 5 agents if `uiDesigner: true`, otherwise 4 (skip ui-designer):

**backend** → `Task(bytM:spring-boot-developer, name: "backend", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 1: PLAN for Issue #{N} - {TITLE}.
> Issue body: {BODY}
> Plan: DB schema, services, controllers, endpoint signatures, test approach.
> Write full plan to `.workflow/specs/issue-{N}-plan-backend.md`.
> Then send a SHORT SUMMARY (max 20 lines: entities, endpoints, key decisions) to teammate "architect" via SendMessage.
> After sending, say 'Done.'

**frontend** → `Task(bytM:angular-frontend-developer, name: "frontend", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 1: PLAN for Issue #{N} - {TITLE}.
> Issue body: {BODY}
> Plan: Components, routing, state management, service layer.
> Write full plan to `.workflow/specs/issue-{N}-plan-frontend.md`.
> Then send a SHORT SUMMARY (max 20 lines: components, routes, services, key decisions) to teammate "architect" via SendMessage.
> After sending, say 'Done.'

**ui-designer** (ONLY if `uiDesigner: true`) → `Task(bytM:ui-designer, name: "ui-designer", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 1: PLAN for Issue #{N} - {TITLE}.
> Issue body: {BODY}
> Create wireframe HTML with data-testid attributes on all interactive elements.
> Write wireframe to `wireframes/issue-{N}-{slug}.html`.
> Write design notes to `.workflow/specs/issue-{N}-plan-ui.md`.
> Then send a SHORT SUMMARY (max 10 lines: components used, data-testid count, layout decisions) to teammate "architect" via SendMessage.
> After sending, say 'Done.'

**quality** → `Task(bytM:test-engineer, name: "quality", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 1: PLAN for Issue #{N} - {TITLE}.
> Issue body: {BODY}
> Start with your Existing Test Impact Analysis (see your agent instructions). Then plan E2E scenarios, OWASP focus areas, quality gates, coverage strategy for {COVERAGE}%.
> Write full plan to `.workflow/specs/issue-{N}-plan-quality.md` (MUST include `## Existing Tests to Update`).
> Then send a SHORT SUMMARY (max 15 lines: BREAKING TESTS count + list, scenario count, coverage target) to teammate "architect" via SendMessage.
> After sending, say 'Done.'

**architect** → `Task(bytM:architect-planner, name: "architect", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 1: PLAN (Consolidator) for Issue #{N} - {TITLE}.
> Issue body: {BODY}
>
> YOUR ROLE: You are the HUB. You will receive plan summaries from teammates: backend, frontend, quality{+ ui-designer if enabled}.
>
> PROCESS:
> 1. Wait for ALL expected summaries (they arrive as messages). You expect exactly {PLAN_SPECIALIST_COUNT} summaries (3 without ui-designer, 4 with). Track each as received.
> 2. After receiving ALL, read the full plans from disk INCREMENTALLY (one at a time, not all at once):
>    - Read `issue-{N}-plan-backend.md` — note endpoints, DTOs, migrations
>    - Read `issue-{N}-plan-frontend.md` — note services, routes, component structure
>    - Read `issue-{N}-plan-quality.md` — note test scenarios, coverage targets
>    - If ui-designer was included: Read `issue-{N}-plan-ui.md` — note data-testid list, layout decisions. Do NOT read the wireframe HTML (too large).
> 3. Validate consistency:
>    - Backend endpoints match Frontend service calls?
>    - DTOs aligned (field names, types)?
>    - If ui-designer included: data-testid from plan-ui.md match test scenarios?
>    - Any architectural conflicts?
> 4. If conflicts found: send fix request to the relevant specialist via SendMessage, wait for updated summary.
> 5. Write CONSOLIDATED TECH SPEC to `.workflow/specs/issue-{N}-plan-consolidated.md` containing:
>    - **`## Implementation Scope`** (FIRST section, REQUIRED): One of `backend-only`, `frontend-only`, or `full-stack`. This determines which agents are spawned in Round 2.
>    - Architecture overview
>    - API contract (endpoints, DTOs, status codes)
>    - Data model (entities, relationships, migrations)
>    - Frontend structure (components, routing, state)
>    - Wireframe reference (if ui-designer was included; otherwise note "no wireframe — frontend developer defines data-testid")
>    - **`## Existing Tests to Update`** (REQUIRED): From the quality agent's analysis — list every existing test that will break, with file path, test name, and required fix. If none, write "No existing tests affected."
>    - Test strategy summary (new tests to write)
>    - Resolved conflicts (if any)
> 6. Send message to team lead: "Consolidated spec ready. Scope: {backend-only|frontend-only|full-stack}. [summary of findings, conflicts resolved: X]"

### After Round 1

1. Wait for architect's "Consolidated spec ready" message
2. Verify files exist: `ls .workflow/specs/issue-{N}-plan-consolidated.md .workflow/specs/issue-{N}-plan-backend.md .workflow/specs/issue-{N}-plan-frontend.md .workflow/specs/issue-{N}-plan-quality.md` (+ `issue-{N}-plan-ui.md` if uiDesigner enabled)
3. Send `shutdown_request` to all round teammates — do NOT wait for confirmations
4. WIP commit: `git add -A && git diff --cached --quiet || git commit -m "wip(#${N}/plan): ${TITLE}"`
5. Update state: `currentRound = "plan_approval"`

---

## ROUND 1.5: USER APPROVAL

Read the consolidated spec (`issue-{N}-plan-consolidated.md`), present summary:

```
PLANS READY FOR REVIEW
========================================
Issue: #{N} - {TITLE}

SCOPE:        {backend-only | frontend-only | full-stack}
ARCHITECTURE: {overview from consolidated spec}
API:          {endpoints + DTOs}
DATABASE:     {entities + migrations}
FRONTEND:     {components + routing}
WIREFRAME:    {wireframes/issue-{N}-{slug}.html OR "not included (ui-designer disabled)"}
TESTS:        {scenario count, coverage target}
CONFLICTS:    {resolved conflicts or "none"}
========================================
Options:
  1. Approve (proceed to implementation)
  2. Request changes (specify which area)
  3. Abort workflow
```

- **Approve**: proceed to Round 2
- **Request changes**: spawn the relevant specialist with feedback, re-consolidate via Architect, re-present
- **Abort**: set status completed, delete team

---

## ROUND 2: IMPLEMENT (Scope-Based Spawning)

Update state: `currentRound = "implement"`.

### Determine scope

Read the `## Implementation Scope` section from the consolidated spec. Only spawn agents for affected domains:

| Scope | Spawn |
|-------|-------|
| `full-stack` | backend + frontend (2 agents) |
| `backend-only` | backend only (1 agent) |
| `frontend-only` | frontend only (1 agent) |

### Backend agent (if scope is `full-stack` or `backend-only`)

**backend** → `Task(bytM:spring-boot-developer, name: "backend", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 2: IMPLEMENT for Issue #{N} - {TITLE}.
> Read ONLY the consolidated spec: `.workflow/specs/issue-{N}-plan-consolidated.md` (do NOT read individual plan files — consolidated already contains everything).
> Implement: entities, repositories, services, controllers, migrations, tests.
> File domain: `backend/**` ONLY.
>
> CONTEXT MANAGEMENT — CRITICAL:
> - Read source files INCREMENTALLY: read only what you need for the current subtask, implement it, then move to the next.
> - Do NOT read all source files at once before starting — this wastes context window.
> - Pipe ALL Bash output through `| tail -50` to limit context usage.
>
> The consolidated spec contains a `## Existing Tests to Update` section — follow it.
> Run `mvn test -pl :backend 2>&1 | tail -50` after implementation. Fix ALL test failures before reporting done.
> If you need clarification about frontend expectations, send a message to teammate "frontend".
> Write implementation report to `.workflow/specs/issue-{N}-impl-backend.md`.
> Say 'Done.'

### Frontend agent (if scope is `full-stack` or `frontend-only`)

**frontend** → `Task(bytM:angular-frontend-developer, name: "frontend", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 2: IMPLEMENT for Issue #{N} - {TITLE}.
> Read ONLY the consolidated spec: `.workflow/specs/issue-{N}-plan-consolidated.md` (do NOT read individual plan files — consolidated already contains everything).
> If a wireframe exists at `wireframes/issue-{N}-{slug}.html`, read it for data-testid reference and ensure all data-testid from wireframe are present.
> Implement: components, services, routing, tests.
> File domain: `frontend/**` ONLY.
>
> CONTEXT MANAGEMENT — CRITICAL:
> - Read source files INCREMENTALLY: read one component, implement changes, then move to the next.
> - Do NOT read all source files at once before starting — this wastes context window.
> - Pipe ALL Bash output through `| tail -50` to limit context usage.
>
> The consolidated spec contains a `## Existing Tests to Update` section — follow it.
> Before reporting done, run build AND tests (see your agent instructions for test obligations).
> If you need clarification about backend endpoints/DTOs, send a message to teammate "backend".
> Write implementation report to `.workflow/specs/issue-{N}-impl-frontend.md`.
> Say 'Done.'

### After Round 2

1. Verify impl files exist (only for spawned agents)
2. Send `shutdown_request` to all round teammates — do NOT wait for confirmations
3. WIP commit: `git add -A && git diff --cached --quiet || git commit -m "wip(#${N}/implement): ${TITLE}"`
4. Update state: `currentRound = "verify"`

---

## ROUND 3: VERIFY (3 Agents)

Update state: `currentRound = "verify"`. Spawn 3 fresh specialist agents:

**test-engineer** → `Task(bytM:test-engineer, name: "test-engineer", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 3: VERIFY for Issue #{N} - {TITLE}.
> Read the implementation reports (NOT the consolidated spec — it's too large and redundant at this stage):
> - `.workflow/specs/issue-{N}-impl-backend.md` (if exists)
> - `.workflow/specs/issue-{N}-impl-frontend.md` (if exists)
> Find data-testid selectors directly in the implemented code: `Grep("data-testid", "frontend/src/**/*.html")`
>
> Tasks:
> 1. Write E2E tests (Playwright, Page Object pattern) using data-testid selectors
> 2. Run E2E tests: `cd frontend && npx playwright test 2>&1 | tail -50`
> 3. Run unit tests: Backend `cd backend && mvn test 2>&1 | tail -50`, Frontend `cd frontend && npm test -- --no-watch --browsers=ChromeHeadless 2>&1 | tail -30`
> 4. Measure coverage
>
> CRITICAL: Pipe ALL test/build output through `| tail -50`. Never run unpiped — it fills the context window.
>
> Update `.workflow/workflow-state.json` field `context.testResults`:
> `{ "allPassed": true/false, "e2e": "X/Y", "unitBackend": "X/Y", "unitFrontend": "X/Y", "coverage": "Z%" }`
>
> Output: `.workflow/specs/issue-{N}-verify-test-engineer.md`
> Say 'Done.'

**security-auditor** → `Task(bytM:security-auditor, name: "security-auditor", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 3: VERIFY for Issue #{N} - {TITLE}.
> OWASP security audit of all changed files.
> Use `git diff {FROM_BRANCH}..HEAD --name-only` to scope the audit.
> Do NOT call Context7 MCP tools — review code directly.
> Read files INCREMENTALLY — do NOT read all changed files at once.
> Report: PASS/WARN/BLOCK per OWASP category. Focus on A01 (Access Control), A03 (Injection), A07 (Auth Failures).
> Output: `.workflow/specs/issue-{N}-verify-security-auditor.md`
> Say 'Done.'

**code-reviewer** → `Task(bytM:code-reviewer, name: "code-reviewer", team_name: "bytm-{N}", model: "{MODEL}")`:
> ROUND 3: VERIFY for Issue #{N} - {TITLE}.
> Review changes: `git diff {FROM_BRANCH}..HEAD` (read incrementally per file, NOT all at once)
> Run build gate — pipe ALL output:
> `cd backend && mvn verify 2>&1 | tail -50`
> `cd frontend && npm test -- --no-watch --browsers=ChromeHeadless 2>&1 | tail -30 && npm run build 2>&1 | tail -50`
> Check: clean code, correct patterns, no TODOs, proper error handling.
> Report: APPROVED / CHANGES_REQUIRED.
> Update `.workflow/workflow-state.json` field `context.reviewFeedback`.
> Output: `.workflow/specs/issue-{N}-verify-code-reviewer.md`
> Say 'Done.'

### After Round 3

1. Verify all 3 report files exist
2. Check `context.testResults.allPassed == true` in workflow-state.json
3. Read all reports:
   - All PASS/APPROVED → proceed to Round 3.5
   - WARNs → include in user summary
   - BLOCK/CHANGES_REQUIRED → re-spawn implementer with fix details, then re-verify (max 2 cycles)
4. Send `shutdown_request` to all 3 teammates — do NOT wait for confirmations
5. WIP commit

---

## ROUND 3.5: USER APPROVAL

Read verification reports, present:

```
VERIFICATION COMPLETE
========================================
E2E Tests:       {X}/{Y} PASSED
Unit Tests:      Backend {X}/{Y}, Frontend {X}/{Y}
Coverage:        {X}% (target: {COVERAGE}%)
Security Audit:  {PASS/WARN/BLOCK} ({details})
Code Review:     {APPROVED/CHANGES_REQUIRED} ({details})
========================================
Options:
  1. Approve (push + PR)
  2. Request changes
  3. Rollback to Round 2
```

---

## ROUND 4: SHIP (Team Lead Direct)

No build gate here — the Code Reviewer already ran the full build in Round 3 VERIFY. Proceed directly to push.

### Push + PR

Do NOT create a final squash commit. The WIP commits from each round preserve the workflow history (plan → implement → verify). Push them directly.

```bash
jq '.currentRound = "ship" | .pushApproved = true' \
  .workflow/workflow-state.json > /tmp/wf-tmp.json && mv /tmp/wf-tmp.json .workflow/workflow-state.json
git push -u origin {BRANCH}
gh pr create --title "feat(#{N}): {ISSUE_TITLE}" --body "$(cat <<'EOF'
## Summary
Implements #{N}: {ISSUE_TITLE}

## Changes
### Backend
{from impl report}
### Frontend
{from impl report}

## Quality
- E2E: {results}, Coverage: {X}%
- Security Audit: {result}
- Code Review: {result}
- Architecture validated by Architect during planning
EOF
)"
```

### Complete

1. Set `status = "completed"`, `currentRound = "done"`
2. Send `shutdown_request` to any remaining teammates
3. Try `TeamDelete`. If it fails (zombie agent), proceed anyway — cleanup is non-critical
4. Report PR URL to user

---

## ERROR HANDLING

| Failure | Response |
|---------|----------|
| Specialist doesn't send summary to Architect | Team lead nudges via SendMessage, max 2x |
| Architect reports unresolvable conflict | Escalate to user with conflict details |
| Agent returns without output file | Re-spawn agent (max 2 retries) |
| Build/test failure in Implement | Re-spawn agent with error output (max 3 retries) |
| BLOCK in Verify | Re-spawn implementer with fix details, re-verify (max 2 cycles) |
| **Agent ignores shutdown_request** | Do NOT wait with `sleep`. Proceed to next round immediately. Zombie agents don't block the workflow — fresh agents in the next round work independently. |
| TeamDelete fails (active members) | Proceed anyway. Report to user that `~/.claude/teams/bytm-{N}/` can be cleaned manually. |
| All retries exhausted | Escalate to user |

### Shutdown Protocol (all rounds)

After each round, send `shutdown_request` to all round teammates. **Do NOT block on confirmations.** Proceed to WIP commit and next round immediately. Zombie agents from previous rounds do not affect fresh agents in new rounds — each Task spawn creates an independent instance.

---

## SPEC FILE NAMING

All in `.workflow/specs/`:

| Round | Pattern | Example |
|-------|---------|---------|
| Plan (specialists) | `issue-{N}-plan-{role}.md` | `issue-42-plan-backend.md` |
| Plan (UI) | `issue-{N}-plan-ui.md` | `issue-42-plan-ui.md` |
| Plan (consolidated) | `issue-{N}-plan-consolidated.md` | `issue-42-plan-consolidated.md` |
| Implementation | `issue-{N}-impl-{role}.md` | `issue-42-impl-frontend.md` |
| Verification | `issue-{N}-verify-{role}.md` | `issue-42-verify-test-engineer.md` |
| Wireframes | `wireframes/issue-{N}-{slug}.html` | `wireframes/issue-42-reports.html` |
