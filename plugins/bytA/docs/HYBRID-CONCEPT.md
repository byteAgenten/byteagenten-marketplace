# bytA v2.0 - Hybrid: Boomerang + Ralph

## Kernidee

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   RALPH-STRUKTUR          +        BOOMERANG-AGENTS            │
│   ─────────────────              ─────────────────              │
│   • Loop mit fresh context       • Spezialisierte Agents        │
│   • PLAN.md als State            • Domänenwissen                │
│   • Tests als Backpressure       • Fokussierte System-Prompts   │
│   • Git ist das Gedächtnis       • permissionMode               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Von Ralph übernommen

| Konzept | Warum |
|---------|-------|
| **Loop-Struktur** | Fresh context jede Iteration → keine Context-Rot |
| **PLAN.md** | Disk-basierter State → überlebt Context-Resets |
| **Tests als Backpressure** | Deterministisch → kann nicht umgangen werden |
| **1 Task pro Iteration** | Fokus → 100% Smart-Zone Nutzung |
| **Git = Gedächtnis** | Commits sind atomare Completion-Units |

## Von Boomerang übernommen

| Konzept | Warum |
|---------|-------|
| **Spezialisierte Agents** | Domänenwissen → bessere Qualität |
| **permissionMode** | Deterministisch → AUTO-Phasen laufen durch |
| **Orchestrator** | Entscheidet welcher Agent für welchen Task |

## Der Hybrid-Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  bytA Hybrid Loop                                               │
│                                                                 │
│  PHASE 1: PLANNING (einmalig)                                   │
│  ─────────────────────────────                                  │
│  1. Issue laden                                                 │
│  2. Task(byt8:architect-planner) → erstellt PLAN.md             │
│  3. USER APPROVAL für Plan                                      │
│                                                                 │
│  PHASE 2: BUILDING (Loop)                                       │
│  ─────────────────────────────                                  │
│  while tasks in PLAN.md:                                        │
│      task = get_next_incomplete_task(PLAN.md)                   │
│                                                                 │
│      # Agent-Routing basierend auf Task-Typ                     │
│      agent = route_to_agent(task.type)                          │
│      # → "api"      → byt8:api-architect                        │
│      # → "database" → byt8:postgresql-architect                 │
│      # → "backend"  → bytA-auto-backend-dev (bypassPermissions) │
│      # → "frontend" → bytA-auto-frontend-dev (bypassPermissions)│
│      # → "test"     → bytA-auto-test-engineer (bypassPermissions)│
│                                                                 │
│      # Task ausführen                                           │
│      Task(agent, task.description)                              │
│                                                                 │
│      # BACKPRESSURE: Tests müssen passieren                     │
│      if not run_tests():                                        │
│          continue  # Nächste Iteration fixt es                  │
│                                                                 │
│      # Task als erledigt markieren                              │
│      update_plan(task, status="done")                           │
│                                                                 │
│      # Commit                                                   │
│      git_commit(task.description)                               │
│                                                                 │
│  PHASE 3: REVIEW (einmalig)                                     │
│  ─────────────────────────────                                  │
│  1. Task(byt8:security-auditor)                                 │
│  2. Task(byt8:code-reviewer)                                    │
│  3. USER APPROVAL für Merge                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## PLAN.md Format

```markdown
# Implementation Plan: Issue #123 - Feature XYZ

## Status: IN_PROGRESS

## Tasks

### API Design
- [x] Define REST endpoints for /api/users
- [x] Create DTOs for request/response

### Database
- [x] Create Flyway migration V007__add_users_table.sql
- [ ] Add indexes for performance

### Backend
- [ ] Implement UserController
- [ ] Implement UserService
- [ ] Write unit tests for UserService

### Frontend
- [ ] Create UserListComponent
- [ ] Create UserFormComponent
- [ ] Add routing

### E2E Tests
- [ ] Test user creation flow
- [ ] Test user list display

## Completion Criteria
- [ ] All tasks checked
- [ ] All tests pass
- [ ] Security audit passed
- [ ] Code review passed
```

## Agent-Routing

```
Task-Typ        → Agent                        → permissionMode
─────────────────────────────────────────────────────────────────
"spec"          → byt8:architect-planner       → default (APPROVAL)
"ui-design"     → byt8:ui-designer             → default (APPROVAL)
"api"           → byt8:api-architect           → default (APPROVAL)
"database"      → byt8:postgresql-architect    → bypassPermissions
"backend"       → bytA-auto-backend-dev        → bypassPermissions
"frontend"      → bytA-auto-frontend-dev       → bypassPermissions
"test"          → bytA-auto-test-engineer      → bypassPermissions
"security"      → byt8:security-auditor        → default (APPROVAL)
"review"        → byt8:code-reviewer           → default (APPROVAL)
```

## Backpressure-Mechanismen

| Mechanismus | Wann | Was passiert bei Fehler |
|-------------|------|-------------------------|
| **Tests** | Nach jedem Task | Loop wiederholt mit Fix-Instruktion |
| **Build** | Nach Backend/Frontend | Loop wiederholt |
| **Lint** | Nach Code-Änderungen | Loop wiederholt |
| **Type-Check** | Nach TypeScript | Loop wiederholt |

## Determinismus-Garantien

| Was | Wie garantiert |
|-----|----------------|
| Plan wird erstellt | APPROVAL-Gate nach Phase 1 |
| Tasks werden abgearbeitet | Loop prüft PLAN.md |
| Code ist korrekt | Tests als Backpressure |
| AUTO-Tasks laufen durch | permissionMode: bypassPermissions |
| APPROVAL-Tasks stoppen | default permissionMode |
| Nichts wird vergessen | PLAN.md persistiert auf Disk |

## Vorteile gegenüber bytA v1

| Problem v1 | Lösung v2 |
|------------|-----------|
| Claude ignoriert SKILL.md | Loop-Struktur erzwingt Ablauf |
| State-Management fragil | PLAN.md auf Disk |
| Tests optional | Backpressure erzwingt Tests |
| Kein klares "Done" | Alle Tasks in PLAN.md checked |

## Implementation

Siehe `scripts/loop.sh` für die Loop-Implementation.
