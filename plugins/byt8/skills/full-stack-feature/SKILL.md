---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
author: byteagent - Hans Pickelmann
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block_orchestrator_code_edit.sh"
---

# Full-Stack Feature Development Skill

## Regeln

1. **AUTO-ADVANCE:** Nach Phasen 2–6 sofort nächste Phase starten — NICHT stoppen. _(Erzwungen durch Stop Hook: decision:block)_
2. **APPROVAL GATES:** Nach Phasen 0, 1, 7, 8, 9 → `status = "awaiting_approval"`, User fragen, STOPP. _(UserPromptSubmit Hook injiziert Rollback-Regeln bei User-Antwort)_
3. **Kein Code schreiben:** Hook blockiert Edit/Write. Jede Änderung → `Task(byt8:AGENT)`.
4. **Keine Spec-Dateien lesen:** Nur `workflow-state.json` lesen. Agents lesen Specs selbst via Read-Tool.

### Hook-Enforcement (v7.0)

Drei Hooks steuern den Workflow deterministisch:
- **Stop Hook** (`wf_engine.sh`): JSON `decision:block` erzwingt Auto-Advance. Claude KANN NICHT stoppen bei Phasen 2-6.
- **UserPromptSubmit Hook** (`wf_user_prompt.sh`): Injiziert Workflow-Status und Rollback-Regeln in Claudes Kontext bei jedem User-Prompt.
- **PreToolUse Hook** (`block_orchestrator_code_edit.sh`): Blockiert Code-Edits durch den Orchestrator.

---

## Phasen

| Phase | Agent | Typ |
|-------|-------|-----|
| 0 | `byt8:architect-planner` | APPROVAL |
| 1 | `byt8:ui-designer` | APPROVAL |
| 2 | `byt8:api-architect` | AUTO |
| 3 | `byt8:postgresql-architect` | AUTO |
| 4 | `byt8:spring-boot-developer` | AUTO |
| 5 | `byt8:angular-frontend-developer` | AUTO |
| 6 | `byt8:test-engineer` | AUTO |
| 7 | `byt8:security-auditor` | APPROVAL |
| 8 | `byt8:code-reviewer` | APPROVAL |
| 9 | Orchestrator direkt (Push & PR) | APPROVAL |

WIP-Commits werden automatisch vom SubagentStop Hook erstellt (Phasen 1, 3, 4, 5, 6 + Safety Net: Agent-basiert bei Hotfixes).

---

## Startup

### Prüfe ob Workflow existiert

```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

- **Wenn existiert:** Lies `status` und `currentPhase`, handle entsprechend.
- **Wenn neu:** Initialisiere (siehe unten).

### Initialisierung

```bash
cat CLAUDE.md 2>/dev/null | head -10 || echo "No CLAUDE.md"
mkdir -p .workflow/logs
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
git fetch --prune
git branch -r | grep -v HEAD | sed 's/origin\///' | head -10
```

**Frage User:**
1. "Von welchem Branch starten?" (Default: main/develop)
2. "Welches Coverage-Ziel?" (50% / 70% / 85% / 95%)

### State erstellen

```bash
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > .workflow/workflow-state.json << EOF
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": ISSUE_NUM, "title": "ISSUE_TITLE", "url": "..." },
  "branch": "feature/issue-ISSUE_NUM-...",
  "fromBranch": "FROM_BRANCH",
  "targetCoverage": COVERAGE,
  "currentPhase": 0,
  "startedAt": "$STARTED_AT",
  "phases": {},
  "context": {}
}
EOF
```

```bash
git checkout -b feature/issue-ISSUE_NUM-kurzer-name
```

Dann Phase 0 starten: `Task(byt8:architect-planner, "Create Technical Specification for Issue #N: Title")`

---

## Agent-Aufruf (File Reference Protocol)

Vor jedem Aufruf: `Read(.workflow/workflow-state.json)` → nur Pfade extrahieren, keine Spec-Dateien lesen.

### Phase-Dependency-Map

| Phase | SPEC FILES im Prompt |
|-------|---------------------|
| 1 | `technicalSpec.specFile` |
| 2 | `technicalSpec.specFile` |
| 3 | `technicalSpec.specFile`, `apiDesign.apiDesignFile` |
| 4 | `technicalSpec.specFile`, `apiDesign.apiDesignFile`, `migrations.databaseFile` |
| 5 | `technicalSpec.specFile`, `apiDesign.apiDesignFile` + `wireframes.paths` |
| 6 | `technicalSpec.specFile` |
| 7 | `technicalSpec.specFile` |
| 8 | `technicalSpec.specFile`, `apiDesign.apiDesignFile` |

### Task()-Prompt Format

```
Task(byt8:[agent], "
Phase [N]: [Name] for Issue #[NUM]

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: [context.technicalSpec.specFile]
- [Weitere gemäß Dependency-Map]

## WORKFLOW CONTEXT
- Issue: #[NUM] - [TITLE]
- Target Coverage: [targetCoverage]%

## YOUR TASK
[Anweisungen]
")
```

---

## Phase 7: Security Audit

User entscheidet nach Findings:
- **Weiter:** `currentPhase = 8`, `status = "awaiting_approval"`
- **Fixen:** Rückdelegation (siehe unten), max 3 Iterationen. Context löschen: `securityAudit`, `testResults`.

## Phase 8: Code Review

- **APPROVED:** `currentPhase = 9`, User fragen: "PR erstellen?"
- **CHANGES_REQUESTED:** Rückdelegation (siehe unten), max 3 Iterationen.

## Phase 9: Push & PR

1. Ziel-Branch fragen (Default: `fromBranch`)
2. PR-Body generieren aus `context.*` Keys
3. User fragen: "Soll ich pushen?"
4. Bei Ja:
   ```bash
   # ZUERST pushApproved setzen (Guard-Hook prüft!)
   jq '.pushApproved = true' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
   git push -u origin $BRANCH
   gh pr create --base $INTO_BRANCH --title "feat(#N): Title" --body "$PR_BODY"
   ```
5. State: `status = "completed"`
6. Zusammenfassung mit Dauer anzeigen (`startedAt` bis jetzt)

---

## Rückdelegation

### Fall 1: Revision der aktuellen Phase

User will Änderung an aktueller Phase → `Task(AKTUELLER_AGENT, "Revise: FEEDBACK")` → erneut Approval Gate.

### Fall 2: Rollback auf frühere Phase

Typische Situationen: User will bei Phase 7/8 noch UI-Änderungen, Backend-Fixes, oder Feature-Erweiterungen.

| Fix-Typ | Ziel | Agent |
|---------|------|-------|
| Spec / Architektur | Phase 0 | `byt8:architect-planner` |
| Wireframes / UI | Phase 1 | `byt8:ui-designer` |
| API Design | Phase 2 | `byt8:api-architect` |
| DB Migration | Phase 3 | `byt8:postgresql-architect` |
| Backend / Java | Phase 4 | `byt8:spring-boot-developer` |
| Frontend / Angular | Phase 5 | `byt8:angular-frontend-developer` |
| Tests / E2E | Phase 6 | `byt8:test-engineer` |

Ablauf — **Reihenfolge ist PFLICHT:**

1. **ZUERST** `currentPhase = Ziel-Phase` setzen + downstream Context löschen:
   ```bash
   jq '.currentPhase = ZIEL | .status = "active" | del(.context.securityAudit) | del(.context.testResults)' \
     .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
   ```
   Bei ZIEL ≤ 5: zusätzlich `del(.context.frontendImpl)`
   Bei ZIEL ≤ 4: zusätzlich `del(.context.backendImpl)`
   Bei ZIEL ≤ 3: zusätzlich `del(.context.migrations)`
2. **DANN** Agent starten: `Task(byt8:AGENT, "Phase [N] (Hotfix): ## SPEC FILES [Pfade] ## ZU FIXENDE PUNKTE [Details] ## YOUR TASK Fixe NUR diese Punkte.")`
3. Auto-Advance läuft automatisch bis zum nächsten Approval Gate (via wf_engine.sh Stop Hook)

**⛔ NIEMALS** Agents aufrufen ohne vorher `currentPhase` zu setzen — sonst: keine WIP-Commits, Phase-Skip-Gefahr!

---

## Escape Commands

| Command | Funktion |
|---------|----------|
| `/byt8:wf-status` | Status anzeigen |
| `/byt8:wf-pause` | Pausieren |
| `/byt8:wf-resume` | Fortsetzen |
| `/byt8:wf-retry-reset` | Retry-Counter zurücksetzen |
| `/byt8:wf-skip` | Phase überspringen (Notfall) |
