---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

## WICHTIGSTE REGEL: KONTINUIERLICHER WORKFLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CLAUDE LÄUFT DURCH BIS ZUM NÄCHSTEN APPROVAL GATE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Nach JEDEM Agent-Aufruf:                                                   │
│                                                                              │
│  1. Prüfe: Ist die NÄCHSTE Phase ein Approval Gate? (0, 1, 7, 8, 9)       │
│                                                                              │
│  2. WENN NEIN (Phasen 2, 3, 4, 5, 6):                                     │
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
| 6 | `byt8:test-engineer` | ▶️ AUTO | → Sofort Phase 7 starten |
| 7 | `byt8:security-auditor` | ⏸️ APPROVAL | → Stopp, Findings anzeigen |
| 8 | `byt8:code-reviewer` | ⏸️ APPROVAL | → Stopp, User fragen |
| 9 | Claude direkt (Push & PR) | ⏸️ APPROVAL | → Stopp, User fragen |

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

### Phase 2-6: Auto-Advance (KEIN STOPP!)

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
  12. Agent fertig → Phase 5 ist AUTO → WEITERMACHEN!
  13. State: currentPhase = 6
  14. Task(byt8:test-engineer, "...")
  15. Agent fertig → Phase 6 ist AUTO → WEITERMACHEN!
  16. State: currentPhase = 7
  17. Task(byt8:security-auditor, "...")
  18. Agent fertig → Phase 7 ist APPROVAL
  19. State: status = "awaiting_approval"
  20. Security Findings anzeigen → STOPP
```

### Phase 7-9: Mit Approval Gates

```
User: "Weiter" (oder "Fix critical+high")

Claude:
  1. Falls Fixes: An zuständige Agents delegieren, dann Re-Audit
  2. Falls Weiter: State: currentPhase = 8
  3. Task(byt8:code-reviewer, "...")
  4. Phase 8 ist APPROVAL
  5. Wenn APPROVED: "Code Review bestanden. PR erstellen?" → STOPP
  6. Wenn CHANGES_REQUESTED: Fixes durchführen, erneut reviewen

User: "Ja"

Claude:
  1. Phase 9: Push & PR erstellen
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
│  WENN nächste_phase IN (2, 3, 4, 5, 6):                                    │
│    → (SubagentStop Hook erstellt automatisch WIP-Commit)                   │
│    → State updaten: currentPhase = nächste_phase                            │
│    → SOFORT nächsten Agent aufrufen                                         │
│                                                                              │
│  WENN nächste_phase IN (0, 1, 7, 8, 9) ODER aktuelle_phase IN (7, 8, 9):  │
│    → (SubagentStop Hook erstellt automatisch WIP-Commit)                   │
│    → State updaten: status = "awaiting_approval"                            │
│    → User fragen: "Phase X fertig. Zufrieden?"                              │
│    → STOPP                                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## WIP-Commits (Automatisch via SubagentStop Hook)

Der **SubagentStop Hook** erstellt automatisch WIP-Commits für Phasen 1, 3, 4, 5, 6.

Format:
```
wip(#ISSUE_NUM/phase-N): PHASE_NAME - ISSUE_TITLE_KURZ
```

Beispiel:
```
wip(#351/phase-4): Backend - Projektliste erweitern
```

**Du musst KEINE Commits manuell erstellen** — der Hook macht das deterministisch nach jedem `Task()` Aufruf.

---

## Phase 7: Security Audit Spezialfall

Der Security-Auditor zeigt alle Findings im Approval Gate an. Der User entscheidet:

### Weiter (keine Fixes)
```
→ State: currentPhase = 8, status = "awaiting_approval"
→ Findings akzeptiert, weiter zu Code Review
```

### Findings fixen
```
→ User kann granular wählen: "fix alle", "fix critical+high", "fix HIGH-001, MED-003"
→ Claude filtert Findings nach User-Auswahl
→ securityFixCount incrementieren
→ Delegation an zuständige Agents basierend auf Finding-Location:
  - Backend (.java) → byt8:spring-boot-developer
  - Frontend (.ts/.html) → byt8:angular-frontend-developer
→ Context für Re-Validierung löschen:
  - context.securityAudit
  - context.testResults
→ Rollback zu Phase 6 (E2E Tests)
→ Auto-Advance: Phase 6 → Phase 7 (Re-Audit) → Approval Gate
```

**Max 3 Fix-Iterationen**, danach nur noch "Weiter" oder Pause.

---

## Phase 8: Code Review Spezialfall

Der Code-Reviewer kann zwei Ergebnisse liefern:

### APPROVED
```
→ State: currentPhase = 9, status = "awaiting_approval"
→ User fragen: "Code Review bestanden. PR erstellen?"
```

### CHANGES_REQUESTED
```
→ Lies context.reviewFeedback.fixes[] (jeder Fix hat type + issue)
→ Dynamisches Rollback basierend auf frühestem Fix-Typ:
  - type: "database" → Rollback zu Phase 3 (Migrations)
  - type: "backend"  → Rollback zu Phase 4 (Backend)
  - type: "frontend" → Rollback zu Phase 5 (Frontend)
  - type: "tests"    → Rollback zu Phase 6 (E2E Tests)
→ Context ab Rollback-Ziel löschen (alle downstream Phasen)
→ Review-Feedback als Kontext an den Rollback-Agent übergeben
→ Auto-Advance-Kette läuft automatisch bis Phase 8 (Re-Review)
```

**Prinzip:** Kein separates Fix-Routing. Rollback zum frühesten betroffenen Punkt,
die Agents der Folgephasen erkennen selbständig was sich geändert hat.

**Max 3 Review-Iterationen**, danach pausieren.

---

## Phase 9: Push & PR

Phase 9 hat keinen Agent - Claude führt direkt aus:

1. **Ziel-Branch fragen:** "In welchen Branch mergen? (Default: fromBranch)"
2. **PR-Body generieren** aus allen context.* Keys
3. **User zeigen** und fragen: "Soll ich pushen und PR erstellen?"
4. **Bei Ja:**
   ```bash
   git push -u origin $BRANCH
   gh pr create --base $INTO_BRANCH --title "feat(#N): Title" --body "$PR_BODY"
   ```
5. **State updaten:** `status: "completed"`, `phases["9"].prUrl: "..."`

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
│  APPROVAL GATES: 0, 1, 7, 8, 9  →  STOPP und User fragen                    │
│  AUTO-ADVANCE:   2, 3, 4, 5, 6  →  SOFORT weitermachen                      │
│                                                                              │
│  SubagentStop Hook erstellt WIP-Commits automatisch (Phasen 1, 3, 4, 5, 6) │
│  → Deterministisch nach jedem Task() Aufruf                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```
