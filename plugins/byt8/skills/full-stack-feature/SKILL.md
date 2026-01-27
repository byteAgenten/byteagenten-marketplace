---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
version: 5.2.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**Deterministische Hook-Steuerung:** Der Stop-Hook gibt EXAKTE Anweisungen. Claude führt NUR diese aus.

---

## ⚠️ WICHTIGSTE REGEL

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  DER HOOK STEUERT - CLAUDE FÜHRT AUS                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. Claude führt EINE Aktion aus                                            │
│  2. Stop-Hook feuert am Ende der Antwort                                    │
│  3. Hook gibt EXAKTE Anweisung: "AKTION FÜR CLAUDE: ..."                    │
│  4. Claude führt GENAU diese Anweisung aus                                  │
│                                                                              │
│  ⛔ VERBOTEN:                                                                │
│     - Eigene Entscheidungen treffen                                         │
│     - Andere Agents aufrufen als vom Hook vorgegeben                        │
│     - Mehrere Phasen hintereinander ausführen                               │
│     - Hook-Anweisungen ignorieren                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Startup (nur bei neuem Workflow)

### 1. Prüfe ob Workflow existiert
```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

**Wenn Workflow existiert:** Lies `status` und `currentPhase`, dann führe Hook-Anweisungen aus.

**Wenn kein Workflow:** Initialisiere (siehe unten).

### 2. Initialisierung (nur bei neuem Workflow)

```bash
# 2.1 Projekt prüfen
cat CLAUDE.md 2>/dev/null | head -10 || echo "No CLAUDE.md"

# 2.2 Workflow-Verzeichnis erstellen
mkdir -p .workflow
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

### 4. Erste Phase starten

```
Task(byt8:architect-planner, "Create Technical Specification for Issue #N: Title")
```

**STOPP** - Hook übernimmt ab hier.

---

## Bei jedem weiteren Aufruf

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. Lies .workflow/workflow-state.json                                       │
│  2. Lies den letzten Hook-Output (im Chat-Verlauf)                          │
│  3. Führe GENAU die "AKTION FÜR CLAUDE" aus dem Hook aus                    │
│  4. STOPP - Hook feuert und gibt nächste Anweisung                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Hook-Output Beispiele

### Beispiel 1: Phase fertig, Auto-Advance

```
═══════════════════════════════════════════════════════════════════════════════
WORKFLOW ENGINE - NÄCHSTE AKTION
═══════════════════════════════════════════════════════════════════════════════
STATUS: active
PHASE: 2 (API Design) ✅ DONE

▶️  AUTO-ADVANCE zu Phase 3

AKTION FÜR CLAUDE:
  → Task(byt8:postgresql-architect)
    "Phase 3 (Migrations) für Issue #42"
───────────────────────────────────────────────────────────────────────────────
```

**→ Claude ruft `Task(byt8:postgresql-architect, "...")` auf. Fertig.**

### Beispiel 2: Approval Gate

```
═══════════════════════════════════════════════════════════════════════════════
WORKFLOW ENGINE - NÄCHSTE AKTION
═══════════════════════════════════════════════════════════════════════════════
STATUS: awaiting_approval
PHASE: 1 (Wireframes)

WARTE AUF USER-INPUT:

┌─────────────────────────────────────────────────────────────────────────────┐
│ WENN USER 'Ja/OK/Weiter/Approve':                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. WIP-Commit erstellen                                                      │
│ 2. State updaten: currentPhase = 2                                          │
│ 3. → Task(byt8:api-architect)                                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ WENN USER FEEDBACK GIBT:                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. State: status = "active"                                                  │
│ 2. → Task(byt8:ui-designer, "Revise: {FEEDBACK}")                           │
└─────────────────────────────────────────────────────────────────────────────┘
───────────────────────────────────────────────────────────────────────────────
```

**→ Claude fragt User. Bei "Ja" → nächste Phase. Bei Feedback → gleiche Phase wiederholen.**

### Beispiel 3: Code Review mit Fixes

```
═══════════════════════════════════════════════════════════════════════════════
WORKFLOW ENGINE - NÄCHSTE AKTION
═══════════════════════════════════════════════════════════════════════════════
STATUS: active
PHASE: 7 (Code Review) ❌ NICHT FERTIG

🔄 CODE REVIEW: CHANGES REQUESTED (Iteration 1/3)

FIXES:
  → [backend] Add authorization check
  → [frontend] Fix form validation

AKTION FÜR CLAUDE:

  1. Task(byt8:spring-boot-developer, "Fix: Add authorization check")
  2. Task(byt8:angular-frontend-developer, "Fix: Fix form validation")
  3. context.reviewFeedback zurücksetzen
  4. Task(byt8:code-reviewer, "Re-review after fixes")
───────────────────────────────────────────────────────────────────────────────
```

**→ Claude ruft die Agents in der angegebenen Reihenfolge auf.**

---

## Phasen-Übersicht (zur Info)

| Phase | Agent | Approval? | WIP-Commit? |
|-------|-------|-----------|-------------|
| 0 | `byt8:architect-planner` | ⏸️ Ja | ❌ |
| 1 | `byt8:ui-designer` | ⏸️ Ja | ✅ |
| 2 | `byt8:api-architect` | ▶️ Auto | ❌ |
| 3 | `byt8:postgresql-architect` | ▶️ Auto | ✅ |
| 4 | `byt8:spring-boot-developer` | ▶️ Auto | ✅ |
| 5 | `byt8:angular-frontend-developer` | ▶️ Auto | ✅ |
| 6 | `byt8:test-engineer` + `byt8:security-auditor` | ⏸️ Ja | ✅ |
| 7 | `byt8:code-reviewer` | ⏸️ Ja | ❌ |
| 8 | Claude direkt (Push & PR) | ⏸️ Ja | ❌ |

**Claude muss diese Tabelle NICHT kennen** - der Hook gibt den richtigen Agent vor.

---

## Phase 8: Push & PR (Spezialfall)

Phase 8 hat keinen Agent - Claude führt direkt aus:

1. **Ziel-Branch fragen:** "Welcher Branch? (Default: fromBranch)"
2. **PR-Body generieren** aus allen context.* Keys
3. **User zeigen** und fragen: "Soll ich pushen?"
4. **Bei Ja:**
   ```bash
   git push -u origin $BRANCH
   gh pr create --base $INTO_BRANCH --title "feat(#N): Title" --body "$PR_BODY"
   ```
5. **State updaten:** `status: "idle"`, `phases["8"].prUrl: "..."`

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
│  HOOK SAGT WAS ZU TUN IST → CLAUDE TUT ES → HOOK PRÜFT → NÄCHSTE ANWEISUNG  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Das ist alles.** Claude muss keine komplexen Regeln verstehen - nur die Hook-Anweisungen befolgen.
