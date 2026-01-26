---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
version: 4.3.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**When to use:** GitHub Issues, new features, bugfixes spanning multiple layers (DB → Backend → Frontend).

> ℹ️ **Hooks handle:** Context recovery, phase validation, auto-commits, retry management, approval gates.
> This skill focuses only on: What to do, not how to control it.

---

## Startup

### 1. Check Project
```bash
cat CLAUDE.md 2>/dev/null | head -10 || echo "NOT FOUND"
```
If no CLAUDE.md → Ask user: "No CLAUDE.md found. Should I run /init?"

### 2. Workflow Directory + .gitignore
```bash
mkdir -p .workflow
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
```
⚠️ `.workflow/` must NEVER be committed!

### 3. Check Workflow State
```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

| Status | Action |
|--------|--------|
| `"active"` | Resume at `currentPhase` |
| `"paused"` | Inform user, offer `/wf:resume` |
| Not found | Start new workflow |

### 4. Argument Handling
```
/full-stack-feature                    → Prompt for feature
/full-stack-feature #42                → Load GitHub Issue
/full-stack-feature #42 --from=develop → Issue + Branch
/full-stack-feature "Description"      → Inline feature
```

### 5. Create Branch (with user confirmation)
```bash
git fetch --prune
git branch -r | grep -v HEAD | sed 's/origin\///' | head -10
```
Let user choose → then:
```bash
git checkout <fromBranch> && git pull
git checkout -b feature/issue-{N}-{slug}
```

### 6. Ask Test Coverage
```
"What test coverage level should be targeted?"
1. 50% (Basic)
2. 70% (Standard)
3. 85% (High)
4. 95% (Critical)
```
→ Store `targetCoverage` in state

### 7. Initialize Workflow

If state not found → Create `.workflow/workflow-state.json`:

```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": 42, "title": "...", "url": "..." },
  "branch": "feature/issue-42-...",
  "fromBranch": "develop",
  "targetCoverage": 70,
  "currentPhase": 0,
  "startedAt": "[ISO-TIMESTAMP]",
  "phases": {},
  "nextStep": { "action": "START_PHASE", "phase": 0 },
  "context": {}
}
```

---

## Phase Overview

```
Phase 0: Tech Spec      → byt8:architect-planner     ⏸️ Approval
Phase 1: Wireframes     → byt8:ui-designer           ⏸️ Approval
Phase 2: API Design     → byt8:api-architect
Phase 3: Migrations     → byt8:postgresql-architect
Phase 4: Backend        → byt8:spring-boot-developer  🧪 mvn test
Phase 5: Frontend       → byt8:angular-frontend-dev   🧪 npm test
Phase 6: E2E + Security → byt8:test-engineer          ⏸️ Approval
                        → byt8:security-auditor
Phase 7: Review         → byt8:code-reviewer          ⏸️ Approval
Phase 8: Push & PR      → Claude directly
```

**Legend:**
- ⏸️ Approval = Hook waits for user confirmation
- 🧪 = Hook runs tests, on fail → Retry (max 3x)

---

## Agent Calls

For each phase, call the corresponding agent with task prompt:

### Phase 0: Tech Spec
```
Agent: byt8:architect-planner
Task: Create Technical Specification for Issue #${issue.number}: ${issue.title}
```

### Phase 1: Wireframes
```
Agent: byt8:ui-designer
Task: Create wireframes based on Tech Spec. Output: wireframes/*.html
```

### Phase 2: API Design
```
Agent: byt8:api-architect
Task: Define REST API based on Tech Spec and Wireframes.
```

### Phase 3: Migrations
```
Agent: byt8:postgresql-architect
Task: Create Flyway migrations based on Tech Spec (entities, tables, relationships).
```

### Phase 4: Backend
```
Agent: byt8:spring-boot-developer
Task: Implement backend based on Tech Spec (entities), API Design (endpoints, DTOs), and Migrations (schema).
      Output: Entity, Repository, Service, Controller + Unit Tests.
```

### Phase 5: Frontend
```
Agent: byt8:angular-frontend-developer
Task: Implement frontend based on Wireframes (UI structure) and API Design (service calls).
      Output: Components, Services, Routing + Unit Tests.
```

### Phase 6: E2E + Security
```
Agent: byt8:test-engineer
Task: Create Playwright E2E tests.

Agent: byt8:security-auditor
Task: Perform security audit.
```

### Phase 7: Review
```
Agent: byt8:code-reviewer
Task: Code review all changes. On issues → Hotfix loop.
```

---

## Context Keys

Each agent stores its output in `context.<key>`:

| Phase | Key | Content |
|-------|-----|---------|
| 0 | `technicalSpec` | Architecture, entities, risks |
| 1 | `wireframes` | File paths, components |
| 2 | `apiDesign` | Endpoints, DTOs, error codes |
| 3 | `migrations` | SQL files, tables |
| 4 | `backendImpl` | Java classes, test coverage |
| 5 | `frontendImpl` | Components, services |
| 6 | `testResults` | E2E status, security findings |
| 7 | `reviewFeedback` | Status (APPROVED/CHANGES_REQUESTED) |

**Format:** Agent outputs at the end:
```
CONTEXT STORE: <key>
{ ...summary JSON... }
```

---

## Phase 8: Push & PR

Phase 8 runs without agent, Claude handles directly:

### 8.1 Ask Target Branch
```
"Which branch should the PR target? (Default: ${fromBranch})"
```
→ Store in `phases["8"].intoBranch`

### 8.2 Generate PR
- Title: `feat(#${issue.number}): ${issue.title}`
- Body: Compile from context keys

### 8.3 Show PR + Approval
```
"Should I push and create PR? [Yes/No]"
```

### 8.4 Push + Create PR
```bash
git push -u origin ${branch}
gh pr create --base ${intoBranch} --title "${title}" --body "${body}"
```

### 8.5 Complete
- `status` → `"completed"`
- Calculate duration
- Output success message

---

## Hotfix Loop

On error in Phase 4-7 → Review (Phase 7) can request hotfix:

| Problem | Hotfix Start |
|---------|--------------|
| Database | Phase 3 |
| Backend | Phase 4 |
| Frontend | Phase 5 |
| Tests | Phase 6 |

Hook automatically sets all phases from hotfix start to `pending`.
After hotfix, workflow runs through all phases again until Phase 7 APPROVED.

---

## Escape Commands

| Command | Function |
|---------|----------|
| `/wf:status` | Show current status |
| `/wf:pause` | Pause workflow |
| `/wf:resume` | Resume workflow |
| `/wf:retry-reset` | Reset retry counter |
| `/wf:skip` | Skip phase (emergency) |

---

## Checklist for Claude

On each skill invocation:

1. ✅ Read state (`.workflow/workflow-state.json`)
2. ✅ If `status: active` → Resume at `currentPhase`
3. ✅ Call agent for current phase
4. ✅ Wait for agent output
5. ✅ **Hook handles:** Validation, commit, phase transition, approval gate

**Claude no longer needs to:**
- ❌ Manually update state (hook does this)
- ❌ Make commits (hook does this)
- ❌ Enforce approval gates (hook does this)
- ❌ Manage retry counter (hook does this)
- ❌ Handle context overflow recovery (hook does this)
