---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
version: 5.3.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

## ⚠️ WICHTIGSTE REGEL: KONTINUIERLICHER WORKFLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CLAUDE LÄUFT DURCH BIS ZUM NÄCHSTEN APPROVAL GATE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Nach JEDEM Agent-Aufruf:                                                   │
│                                                                              │
│  1. Prüfe: Ist die NÄCHSTE Phase ein Approval Gate? (0, 1, 6, 7, 8)        │
│                                                                              │
│  2. WENN NEIN (Phasen 2, 3, 4, 5):                                          │
│     → SOFORT nächsten Agent aufrufen                                        │
│     → NICHT stoppen, NICHT auf User warten                                  │
│                                                                              │
│  3. WENN JA (Approval Gate):                                                │
│     → State updaten: status = "awaiting_approval"                           │
│     → User fragen: "Phase X fertig. Zufrieden?"                             │
│     → STOPP - Warte auf User                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phasen-Übersicht

| Phase | Agent | Typ | Nach Abschluss |
|-------|-------|-----|----------------|
| 0 | `byt8:architect-planner` | ⏸️ APPROVAL | → Stopp, User fragen |
| 1 | `byt8:ui-designer` | ⏸️ APPROVAL | → Stopp, User fragen |
| 2 | `byt8:api-architect` | ▶️ AUTO | → Sofort Phase 3 starten |
| 3 | `byt8:postgresql-architect` | ▶️ AUTO | → Sofort Phase 4 starten |
| 4 | `byt8:spring-boot-developer` | ▶️ AUTO | → Sofort Phase 5 starten |
| 5 | `byt8:angular-frontend-developer` | ▶️ AUTO | → Sofort Phase 6 starten |
| 6 | `byt8:test-engineer` + `byt8:security-auditor` | ⏸️ APPROVAL | → Stopp, User fragen |
| 7 | `byt8:code-reviewer` | ⏸️ APPROVAL | → Stopp, User fragen |
| 8 | Claude direkt (Push & PR) | ⏸️ APPROVAL | → Stopp, User fragen |

---

## Workflow-Ablauf

### Phase 0-1: Mit Approval Gates

```
User: /byt8:full-stack-feature #42

Claude:
  1. Initialisiere Workflow (siehe unten)
  2. Task(byt8:architect-planner, "...")
  3. Agent fertig → Phase 0 ist APPROVAL
  4. State: status = "awaiting_approval", currentPhase = 0
  5. "Tech Spec fertig. Zufrieden?" → STOPP

User: "Ja"

Claude:
  1. State: status = "active", currentPhase = 1
  2. Task(byt8:ui-designer, "...")
  3. Agent fertig → Phase 1 ist APPROVAL
  4. State: status = "awaiting_approval"
  5. "Wireframes fertig. Zufrieden?" → STOPP
```

### Phase 2-5: Auto-Advance (KEIN STOPP!)

```
User: "Ja" (nach Wireframes)

Claude:
  1. State: status = "active", currentPhase = 2
  2. Task(byt8:api-architect, "...")
  3. Agent fertig → Phase 2 ist AUTO → WEITERMACHEN!
  4. State: currentPhase = 3
  5. Task(byt8:postgresql-architect, "...")
  6. Agent fertig → Phase 3 ist AUTO → WEITERMACHEN!
  7. State: currentPhase = 4
  8. Task(byt8:spring-boot-developer, "...")
  9. Agent fertig → Phase 4 ist AUTO → WEITERMACHEN!
  10. State: currentPhase = 5
  11. Task(byt8:angular-frontend-developer, "...")
  12. Agent fertig → Phase 5 führt zu Phase 6 = APPROVAL
  13. State: status = "awaiting_approval", currentPhase = 6
  14. "Frontend fertig. Bereit für Tests?" → STOPP
```

### Phase 6-8: Mit Approval Gates

```
User: "Ja"

Claude:
  1. Task(byt8:test-engineer, "...")
  2. Task(byt8:security-auditor, "...")
  3. Phase 6 ist APPROVAL
  4. "Tests + Security Audit fertig. Zufrieden?" → STOPP

User: "Ja"

Claude:
  1. Task(byt8:code-reviewer, "...")
  2. Phase 7 ist APPROVAL
  3. Wenn APPROVED: "Code Review bestanden. PR erstellen?" → STOPP
  4. Wenn CHANGES_REQUESTED: Fixes durchführen, erneut reviewen

User: "Ja"

Claude:
  1. Phase 8: Push & PR erstellen
  2. "PR erstellt: [URL]. Workflow abgeschlossen."
```

---

## Startup (nur bei neuem Workflow)

### 1. Prüfe ob Workflow existiert

```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

**Wenn Workflow existiert:** Lies `status` und `currentPhase`, dann entsprechend handeln.

**Wenn kein Workflow:** Initialisiere (siehe unten).

### 2. Initialisierung

```bash
# 2.1 Projekt prüfen
cat CLAUDE.md 2>/dev/null | head -10 || echo "No CLAUDE.md"

# 2.2 Workflow-Verzeichnis erstellen
mkdir -p .workflow/logs
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore

# 2.3 Branches zeigen
git fetch --prune
git branch -r | grep -v HEAD | sed 's/origin\///' | head -10
```

**Frage User:**
1. "Von welchem Branch starten?" (Default: main/develop)
2. "Welches Coverage-Ziel?" (50% / 70% / 85% / 95%)

### 3. State initialisieren

```bash
cat > .workflow/workflow-state.json << 'EOF'
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": ISSUE_NUM, "title": "ISSUE_TITLE", "url": "..." },
  "branch": "feature/issue-ISSUE_NUM-...",
  "fromBranch": "FROM_BRANCH",
  "targetCoverage": COVERAGE,
  "currentPhase": 0,
  "startedAt": "ISO_TIMESTAMP",
  "phases": {},
  "context": {}
}
EOF
```

### 4. Branch erstellen und erste Phase starten

```bash
git checkout -b feature/issue-ISSUE_NUM-kurzer-name
```

Dann:
```
Task(byt8:architect-planner, "Create Technical Specification for Issue #N: Title")
```

---

## Nach jedem Agent-Aufruf

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ENTSCHEIDUNGSLOGIK                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  aktuelle_phase = currentPhase aus State                                     │
│  nächste_phase = aktuelle_phase + 1                                          │
│                                                                              │
│  WENN nächste_phase IN (2, 3, 4, 5):                                        │
│    → WIP-Commit erstellen (falls Änderungen)                                │
│    → State updaten: currentPhase = nächste_phase                            │
│    → SOFORT nächsten Agent aufrufen                                         │
│                                                                              │
│  WENN nächste_phase IN (0, 1, 6, 7, 8) ODER aktuelle_phase IN (6, 7, 8):   │
│    → WIP-Commit erstellen (falls Änderungen)                                │
│    → State updaten: status = "awaiting_approval"                            │
│    → User fragen: "Phase X fertig. Zufrieden?"                              │
│    → STOPP                                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## WIP-Commits

Erstelle WIP-Commits für Phasen 1, 3, 4, 5, 6:

```bash
git add -A
git commit -m "wip(#ISSUE_NUM/phase-N): PHASE_NAME - ISSUE_TITLE_KURZ"
```

Beispiel:
```bash
git commit -m "wip(#351/phase-4): Backend - Projektliste erweitern"
```

---

## Phase 7: Code Review Spezialfall

Der Code-Reviewer kann zwei Ergebnisse liefern:

### APPROVED
```
→ State: currentPhase = 8, status = "awaiting_approval"
→ User fragen: "Code Review bestanden. PR erstellen?"
```

### CHANGES_REQUESTED
```
→ Lies context.reviewFeedback.fixes[]
→ Für jeden Fix den passenden Agent aufrufen:
   - type: "backend" → byt8:spring-boot-developer
   - type: "frontend" → byt8:angular-frontend-developer
   - type: "database" → byt8:postgresql-architect
   - type: "tests" → byt8:test-engineer
→ Danach: context.reviewFeedback löschen
→ Erneut: Task(byt8:code-reviewer, "Re-review after fixes")
```

**Max 3 Iterationen**, danach pausieren.

---

## Phase 8: Push & PR

Phase 8 hat keinen Agent - Claude führt direkt aus:

1. **Ziel-Branch fragen:** "In welchen Branch mergen? (Default: fromBranch)"
2. **PR-Body generieren** aus allen context.* Keys
3. **User zeigen** und fragen: "Soll ich pushen und PR erstellen?"
4. **Bei Ja:**
   ```bash
   git push -u origin $BRANCH
   gh pr create --base $INTO_BRANCH --title "feat(#N): Title" --body "$PR_BODY"
   ```
5. **State updaten:** `status: "completed"`, `phases["8"].prUrl: "..."`

---

## Bei User-Feedback an Approval Gates

Wenn User nicht "Ja/OK/Weiter" sagt, sondern Änderungswünsche hat:

```
1. State: status = "active" (bleibt bei aktueller Phase)
2. Task(AKTUELLER_AGENT, "Revise based on feedback: USER_FEEDBACK")
3. Nach Agent: wieder Approval Gate → User fragen
```

---

## Escape Commands

| Command | Funktion |
|---------|----------|
| `/byt8:wf-status` | Status anzeigen |
| `/byt8:wf-pause` | Pausieren |
| `/byt8:wf-resume` | Fortsetzen |
| `/byt8:wf-retry-reset` | Retry-Counter zurücksetzen |
| `/byt8:wf-skip` | Phase überspringen (Notfall) |

---

## Zusammenfassung

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  APPROVAL GATES: 0, 1, 6, 7, 8  →  STOPP und User fragen                    │
│  AUTO-ADVANCE:   2, 3, 4, 5     →  SOFORT weitermachen                      │
│                                                                              │
│  Der Stop-Hook validiert im Hintergrund und erstellt WIP-Commits.           │
│  Claude wartet NICHT auf Hook-Output für Auto-Advance Phasen.               │
└─────────────────────────────────────────────────────────────────────────────┘
```
