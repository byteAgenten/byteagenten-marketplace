---
description: Hybrid Workflow - Boomerang + Ralph Style
author: byteAgenten
---

# bytA Feature (Hybrid v2.0)

Kombiniert Boomerang (spezialisierte Agents) + Ralph (Loop-Struktur, PLAN.md).

## Zwei Modi

### Modus 1: Interaktiv (in Claude Code)
Du bist jetzt im interaktiven Modus. Folge dem Workflow unten.

### Modus 2: Autonom (Terminal)
```bash
# Externes Script für autonomen Loop
${CLAUDE_PLUGIN_ROOT}/scripts/loop.sh plan 391   # Planning
${CLAUDE_PLUGIN_ROOT}/scripts/loop.sh build      # Building Loop
```

---

## INTERAKTIVER WORKFLOW

### PHASE 1: Setup

```bash
mkdir -p .workflow
echo "$(date)" > .workflow/bytA-session
```

### PHASE 2: Planning (APPROVAL)

```
Task(byt8:architect-planner, "
Erstelle Implementation Plan für Issue #{ISSUE_NUMBER}.

Schreibe nach .workflow/PLAN.md im Format:

# Implementation Plan: Issue #{NUMBER} - [TITLE]

## Status: IN_PROGRESS

## Tasks

### API Design
- [ ] Task 1
- [ ] Task 2

### Database
- [ ] Task 1

### Backend
- [ ] Task 1

### Frontend
- [ ] Task 1

### E2E Tests
- [ ] Task 1

## Completion Criteria
- [ ] All tasks checked
- [ ] All tests pass
")
```

**→ ZEIGE dem User den Plan und frage: "Plan OK? Soll ich mit Building starten?"**

### PHASE 3: Building Loop

Für JEDEN offenen Task in `.workflow/PLAN.md`:

1. **Lies PLAN.md**, finde ersten `- [ ]` Task
2. **Route zum Agent** basierend auf Kategorie:

| Kategorie | Agent | Mode |
|-----------|-------|------|
| API Design | byt8:api-architect | APPROVAL |
| Database | bytA-auto-db-architect | AUTO |
| Backend | bytA-auto-backend-dev | AUTO |
| Frontend | bytA-auto-frontend-dev | AUTO |
| E2E Tests | bytA-auto-test-engineer | AUTO |

3. **Führe Task aus**:
```
Task(AGENT, "Implementiere: [TASK_DESCRIPTION]. Update .workflow/PLAN.md wenn fertig.")
```

4. **Backpressure** - Tests laufen lassen:
```bash
# Backend
cd backend && ./mvnw test -q

# Frontend
cd frontend && npm test -- --watch=false

# Wenn Tests fehlschlagen → Fix in nächster Iteration
```

5. **Wenn Tests OK**:
   - Task in PLAN.md als `[x]` markieren
   - Commit erstellen

6. **Wiederholen** bis alle Tasks `[x]` sind

### PHASE 4: Review (APPROVAL)

Wenn alle Tasks erledigt:

```
Task(byt8:security-auditor, "Security Audit. Prüfe alle Änderungen.")
```
→ User Approval

```
Task(byt8:code-reviewer, "Code Review. Prüfe alle Änderungen.")
```
→ User Approval

### PHASE 5: Abschluss

```bash
# Finaler Commit
git add -A && git commit -m "feat(#ISSUE): [Feature Description]"

# PR erstellen?
gh pr create --title "..." --body "..."
```

---

## REGELN

1. **PLAN.md ist die Wahrheit** - Lies es vor jeder Aktion
2. **1 Task pro Agent-Aufruf** - Nicht mehrere auf einmal
3. **Tests sind Pflicht** - Kein Commit ohne grüne Tests
4. **AUTO-Agents laufen durch** - bytA-auto-* haben bypassPermissions
5. **APPROVAL-Agents fragen** - byt8:* haben default permission
