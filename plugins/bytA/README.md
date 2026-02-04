# bytA Plugin

**Version 2.0.0** | Hybrid: Boomerang + Ralph

## Philosophie

Kombiniert das Beste aus zwei Welten:

| Von Ralph | Von Boomerang |
|-----------|---------------|
| Loop-Struktur | Spezialisierte Agents |
| PLAN.md als State | permissionMode |
| Tests als Backpressure | Domänenwissen |
| Fresh Context pro Iteration | Agent-Routing |
| Git = Gedächtnis | APPROVAL/AUTO Modi |

## Der Hybrid-Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  PHASE 1: PLANNING                                              │
│  ────────────────────                                           │
│  Task(byt8:architect-planner) → PLAN.md                         │
│  USER APPROVAL ✋                                                │
│                                                                 │
│  PHASE 2: BUILDING LOOP                                         │
│  ────────────────────────                                       │
│  while tasks in PLAN.md:                                        │
│      task = next_open_task(PLAN.md)                             │
│      agent = route(task.category)    # Spezialisierter Agent    │
│      Task(agent, task)               # bypassPermissions=AUTO   │
│      run_tests()                     # Backpressure!            │
│      mark_done(task)                                            │
│      git_commit()                                               │
│                                                                 │
│  PHASE 3: REVIEW                                                │
│  ────────────────────                                           │
│  Task(byt8:security-auditor) → USER APPROVAL ✋                  │
│  Task(byt8:code-reviewer) → USER APPROVAL ✋                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Zwei Modi

### Interaktiv (in Claude Code)
```
/bytA:feature #391
```
Claude führt den Workflow Schritt für Schritt aus.

### Autonom (Terminal)
```bash
# Planning
./plugins/bytA/scripts/loop.sh plan 391

# Building Loop (max 50 Iterationen)
./plugins/bytA/scripts/loop.sh build

# Status prüfen
./plugins/bytA/scripts/loop.sh status
```

## PLAN.md Format

```markdown
# Implementation Plan: Issue #391 - Feature XYZ

## Status: IN_PROGRESS

## Tasks

### API Design
- [x] Define REST endpoints
- [x] Create DTOs

### Database
- [x] Create migration V007__add_table.sql

### Backend
- [ ] Implement Controller        ← Nächster Task
- [ ] Implement Service
- [ ] Write unit tests

### Frontend
- [ ] Create Component
- [ ] Add routing

### E2E Tests
- [ ] Test happy path

## Completion Criteria
- [ ] All tasks checked
- [ ] All tests pass
```

## Agent-Routing

| Task-Kategorie | Agent | Mode |
|----------------|-------|------|
| Planning | byt8:architect-planner | APPROVAL |
| API Design | byt8:api-architect | APPROVAL |
| Database | bytA-auto-db-architect | AUTO |
| Backend | bytA-auto-backend-dev | AUTO |
| Frontend | bytA-auto-frontend-dev | AUTO |
| E2E Tests | bytA-auto-test-engineer | AUTO |
| Security | byt8:security-auditor | APPROVAL |
| Review | byt8:code-reviewer | APPROVAL |

**AUTO** = `permissionMode: bypassPermissions` → läuft ohne User-Frage
**APPROVAL** = `permissionMode: default` → User wird gefragt

## Backpressure

Tests erzwingen Korrektheit - deterministisch, kann nicht umgangen werden:

```bash
# Backend
cd backend && ./mvnw test

# Frontend
cd frontend && npm test

# E2E
cd frontend && npm run e2e
```

Wenn Tests fehlschlagen → Loop macht nächste Iteration mit Fix.

## Hook-Enforcement

Der Stop-Hook erzwingt den Workflow:

1. Prüft ob `.workflow/bytA-session` existiert (Skill aktiv)
2. Prüft ob `.workflow/PLAN.md` existiert (Planning done)
3. Prüft ob offene Tasks existieren (Building nicht fertig)

→ `decision:block` erzwingt nächsten Schritt

## Struktur

```
bytA/
├── .claude-plugin/plugin.json
├── agents/
│   ├── orchestrator.md           # (Legacy, nicht mehr primär)
│   ├── auto-api-architect.md     # AUTO
│   ├── auto-db-architect.md      # AUTO
│   ├── auto-backend-dev.md       # AUTO
│   ├── auto-frontend-dev.md      # AUTO
│   └── auto-test-engineer.md     # AUTO
├── commands/feature.md
├── docs/
│   └── HYBRID-CONCEPT.md         # Detaillierte Dokumentation
├── hooks/hooks.json
├── scripts/
│   ├── enforce_orchestrator.sh   # Hook-Script
│   └── loop.sh                   # Autonomer Loop
├── skills/feature/SKILL.md
└── README.md
```

## Warum Hybrid?

| Problem | Ralph-Lösung | Boomerang-Lösung | Hybrid |
|---------|--------------|------------------|--------|
| Claude ignoriert Prompts | Tests als Backpressure | - | ✓ Tests |
| Generalist-Agent | - | Spezialisierte Agents | ✓ Routing |
| Context-Rot | Fresh Context | - | ✓ Loop |
| State verloren | PLAN.md auf Disk | - | ✓ PLAN.md |
| AUTO/APPROVAL | - | permissionMode | ✓ Modes |

## Quellen

- [Ralph Playbook](https://claytonfarr.github.io/ralph-playbook/)
- [Everything is a Ralph Loop](https://ghuntley.com/loop/)
- [Roo Code Boomerang](https://docs.roocode.com/features/boomerang-tasks)
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)
