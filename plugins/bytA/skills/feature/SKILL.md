---
description: Deterministic full-stack feature orchestration with Boomerang + Ralph-Loop automation.
author: byteagent - Hans Pickelmann
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block_orchestrator_code_edit.sh"
    - matcher: "Task"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block_orchestrator_explore.sh"
---

# Full-Stack Feature Development (bytA — Boomerang + Ralph-Loop)

## Deine Rolle

Du bist ein **Transport-Layer**. Du fuehrst aus, was die Hooks dir sagen.

## Regeln

1. **Du triffst KEINE inhaltlichen Entscheidungen.** Der Stop Hook sagt dir, was zu tun ist.
2. **Du schreibst KEINEN Code.** Hooks blockieren Edit/Write auf Code-Dateien.
3. **Du aenderst NICHT den Workflow-State** (ausser bei Startup und Approval Gates per Hook-Anweisung).
4. **Du liest NUR workflow-state.json.** Keine Spec-Dateien — Agents lesen diese selbst.
5. **Du explorierst NICHT.** Hook blockiert Task(Explore) und Task(general-purpose).

### Hook-Steuerung (Deterministisch)

- **Stop Hook** (`wf_orchestrator.sh`): Ralph-Loop — verifiziert extern, advanced automatisch, spawnt Agents via `decision:block`.
- **UserPromptSubmit Hook** (`wf_user_prompt.sh`): Injiziert Approval-Gate-Anweisungen + Option C Rollback.
- **PreToolUse Hooks**: Blockieren Code-Edits und Exploration durch Orchestrator.
- **SubagentStop Hook** (`subagent_done.sh`): Erstellt WIP-Commits deterministisch.

---

## Phasen

| Phase | Agent | Typ | Done-Kriterium |
|-------|-------|-----|----------------|
| 0 | `bytA:architect-planner` | APPROVAL | Spec-Datei existiert |
| 1 | `bytA:ui-designer` | APPROVAL | Wireframe HTML existiert |
| 2 | `bytA:api-architect` | AUTO | API-Spec existiert |
| 3 | `bytA:postgresql-architect` | AUTO | Migration SQL existiert |
| 4 | `bytA:spring-boot-developer` | AUTO | Backend-Report MD existiert |
| 5 | `bytA:angular-frontend-developer` | AUTO | Frontend-Report MD existiert |
| 6 | `bytA:test-engineer` | AUTO | allPassed == true |
| 7 | `bytA:security-auditor` | APPROVAL | Audit-Datei existiert |
| 8 | `bytA:code-reviewer` | APPROVAL | userApproved == true |
| 9 | Orchestrator direkt (Push & PR) | APPROVAL | PR URL in State |

---

## Startup

### Schritt 0: Session-Marker setzen (ALLERERSTER Befehl!)

```bash
mkdir -p .workflow && echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > .workflow/bytA-session
```

**Warum?** Der Stop Hook erkennt daran, dass der Skill aktiv ist. Ohne Marker sind ALLE Hooks inert — der Ralph-Loop springt nie an. Bei fehlendem workflow-state.json erzwingt der Stop Hook dann den Startup.

### Schritt 1: Cleanup (PFLICHT!)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wf_cleanup.sh
```

| Exit Code | Bedeutung | Aktion |
|-----------|-----------|--------|
| 0 | OK (kein Workflow oder aufgeraeumt) | Weiter mit Schritt 2 |
| 1 | BLOCKED (aktiver Workflow) | STOPP! User entscheidet |

### Schritt 2: Prüfe ob Workflow existiert

```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

- **Existiert:** Lies `status` und `currentPhase`, handle entsprechend.
- **Neu:** Initialisiere.

### Initialisierung

```bash
mkdir -p .workflow/logs .workflow/specs .workflow/recovery
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
git fetch --prune
```

**Frage User:**
1. "Von welchem Branch starten?" (Default: main/develop)
2. "Welches Coverage-Ziel?" (50% / 70% / 85% / 95%)

### State erstellen

```bash
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > .workflow/workflow-state.json << EOF
{
  "workflow": "bytA-feature",
  "status": "active",
  "issue": { "number": ISSUE_NUM, "title": "ISSUE_TITLE", "url": "..." },
  "branch": "feature/issue-ISSUE_NUM-...",
  "fromBranch": "FROM_BRANCH",
  "targetCoverage": COVERAGE,
  "currentPhase": 0,
  "startedAt": "$STARTED_AT",
  "phases": {},
  "context": {},
  "recovery": {},
  "stopHookBlockCount": 0
}
EOF
git checkout -b feature/issue-ISSUE_NUM-kurzer-name
```

Phase 0 starten: `Task(bytA:architect-planner, "Phase 0: Create Technical Specification for Issue #N: Title")`

### Nach Phase 0: APPROVAL GATE

1. Lies die Spec-Datei aus `context.technicalSpec.specFile`
2. Zeige dem User eine Zusammenfassung
3. Frage: "Spec OK? Soll ich fortfahren?"
4. **WARTE auf User** — der Stop-Hook setzt `status = "awaiting_approval"`
5. ERST nach User-Approval: Naechste Phase starten

---

## Was bei Auto-Advance passiert

Der Stop Hook gibt `decision:block` mit einer `reason`.
Die `reason` sagt dir exakt welchen Task() du starten sollst.
**Fuehre ihn aus. Interpretiere NICHTS.**

## Was bei Approval Gates passiert

Der UserPromptSubmit Hook injiziert dir Anweisungen.
**Befolge sie woertlich. Interpretiere NICHTS.**

## Phase Skipping

Wenn eine Phase uebersprungen wird (z.B. Backend-only, keine DB):

```bash
jq '
  .phases["1"] = {"name":"ui-designer","status":"skipped","reason":"Backend-only"}
  | .context.wireframes = {"skipped":true,"reason":"Backend-only"}
' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
```

## Phase 9: Push & PR

_(Status ist bereits `awaiting_approval` aus Phase 8)_

1. User fragen: "PR erstellen? Ziel-Branch?" (Default: `fromBranch`)
2. Bei Ja:
   ```bash
   jq '.status = "active" | .pushApproved = true' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
   git push -u origin $BRANCH
   gh pr create --base $INTO_BRANCH --title "feat(#N): Title" --body "$PR_BODY"
   jq '.status = "completed"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
   ```

---

## Escape Commands

| Command | Funktion |
|---------|----------|
| `/bytA:wf-status` | Status anzeigen |
| `/bytA:wf-pause` | Pausieren |
| `/bytA:wf-resume` | Fortsetzen |
| `/bytA:wf-retry-reset` | Retry-Counter zuruecksetzen |
| `/bytA:wf-skip` | Phase ueberspringen (Notfall) |
