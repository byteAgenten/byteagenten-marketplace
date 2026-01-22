---
name: full-stack-feature
description: Orchestrates full-stack feature development with approval gates and agent delegation.
version: 2.20.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**When to use:** GitHub Issues, neue Features, Bugfixes die mehrere Layer betreffen (DB → Backend → Frontend).

---

## Startup (Bootstrap + State-Check + Argument-Handling)

### Bei JEDEM Skill-Aufruf diese Schritte ausführen:

**1. CLAUDE.md prüfen:**
```bash
cat CLAUDE.md 2>/dev/null | head -20 || echo "NICHT VORHANDEN"
```
Falls nicht vorhanden → User fragen: "Keine CLAUDE.md gefunden. Soll ich /init ausführen?"

**2. Recovery-Sektion in CLAUDE.md sicherstellen:**
Prüfe ob `## byt8 Workflow Recovery` existiert. Falls nicht → am ANFANG hinzufügen:
```markdown
## byt8 Workflow Recovery

Bei Session-Start oder Context-Overflow IMMER prüfen:

\`\`\`bash
cat .workflow/workflow-state.json 2>/dev/null || echo "KEIN WORKFLOW"
\`\`\`

Falls `"status": "active"`:
→ Skill neu laden: `/byt8:full-stack-feature`
→ Workflow wird automatisch fortgesetzt

---
```

**3. Workflow-Verzeichnis + .gitignore:**
```bash
mkdir -p .workflow
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
```
⚠️ `.workflow/` darf NIEMALS eingecheckt werden!

**4. State prüfen:**
```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NICHT VORHANDEN"
```

| Status | Aktion |
|--------|--------|
| `"status": "active"` | Resume: "Aktiver Workflow (Phase X). Fortsetzen?" |
| `"status": "idle"` oder nicht vorhanden | Neuen Workflow starten |

**5. Context Overflow Recovery:**
Bei "This session is being continued from a previous conversation...":
→ State lesen → `currentPhase` + `nextStep` notieren → ab `nextStep.action` fortsetzen

**6. Argument-Handling:**
```
/full-stack-feature                                          # Fragt nach allem
/full-stack-feature #42                                      # GitHub Issue → fragt nach Branch
/full-stack-feature #42 --from=develop                       # GitHub Issue + Branch
/full-stack-feature "Featurebeschreibung hier..."            # Inline → fragt nach Branch
/full-stack-feature "Featurebeschreibung" --from=main        # Inline + Branch
/full-stack-feature --file=feature.md                        # Aus Datei → fragt nach Branch
/full-stack-feature --file=feature.md --from=develop         # Aus Datei + Branch
```

| Argument | Aktion |
|----------|--------|
| `#42` | GitHub Issue laden (Titel + Beschreibung aus GitHub) |
| `"Featurebeschreibung"` | Featurebeschreibung inline (bis ~500 Zeichen praktikabel) |
| `--file=<path>` | Längere Featurebeschreibung aus Markdown-Datei |
| `--from=<branch>` | `fromBranch` vormerken |
| Keine Argumente | Fragen: "Was möchtest du implementieren?" |

**Parsing-Regeln:**
- `#42`, `"..."` und `--file=` sind **mutually exclusive** (nur eins davon)
- `--from=<branch>` kann mit allen kombiniert werden
- Ohne `--from=` → Schritt 7 fragt nach Branch
- Unbekannte Argumente → Warnung: "Unbekanntes Argument."

**7. Branch-Bestätigung (PFLICHT!):**

⛔ **NIEMALS Branch erstellen ohne User-Bestätigung!**

**Zuerst verfügbare Branches vom Remote holen:**
```bash
git fetch --prune
git branch -r | grep -v HEAD | sed 's/origin\///'
```

**Branch-Auswahl (max. 10 anzeigen, priorisiert):**

Priorität:
1. `main` oder `master` (falls vorhanden)
2. `develop` (falls vorhanden)
3. `release/*` Branches
4. Restliche Branches (alphabetisch)

Falls mehr als 10 Branches → nur Top 10 anzeigen + Hinweis "Andere eingeben"

| Situation | Aktion |
|-----------|--------|
| `fromBranch` explizit angegeben | Prüfen ob Branch existiert, dann bestätigen lassen |
| `fromBranch` NICHT angegeben | Top-Branches auflisten, User wählen lassen |

**Beispiel-Dialog (Paginierung bei vielen Branches):**
```
Von welchem Branch soll ich für Issue #42 abzweigen?

Seite 1/5 (1-10 von 47 Branches):
1. main
2. develop
3. release/v2.1
4. release/v2.0
5. release/v1.9
6. feature/user-auth
7. feature/dashboard
8. feature/api-v2
9. hotfix/login-bug
10. hotfix/memory-leak

[n] Nächste Seite | [b] Branch-Name eingeben
Auswahl:
```

**Paginierung:**
- 10 Branches pro Seite
- `n` = nächste Seite, `p` = vorherige Seite
- Nummer (1-10) = Branch auswählen
- `b` = Branch-Name manuell eingeben

**Erst NACH User-Bestätigung:**
```bash
git checkout <fromBranch> && git pull
git checkout -b feature/issue-{N}-{kurzbeschreibung}
```

**8. Test-Coverage abfragen:**
Coverage-Level abfragen (50% / 70% / 85% / 95%) → `"targetCoverage"` speichern

**9. Workflow initialisieren:**

Mit Write-Tool `.workflow/workflow-state.json` erstellen:
```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": null, "title": "", "url": "" },
  "branch": "",
  "fromBranch": "",
  "intoBranch": null,
  "currentPhase": 0,
  "startedAt": "[ISO-TIMESTAMP]",
  "phases": {},
  "nextStep": {
    "action": "START_PHASE_0",
    "phase": 0,
    "description": "Technical Specification erstellen",
    "agent": "byt8:architect-planner"
  },
  "context": {}
}
```

---

## Workflow Ablauf

```
START → Issue erkennen → Branch erstellen
    ↓
┌─────────────────────────────────────────────────────┐
│ PHASE 0: Architecture → byt8:architect-planner      │
│ Output: Technical Spec in workflow-state            │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: "Ist die Architektur akzeptiert?"          │
│ Bei Fragen/Feedback → zurück an architect-planner   │
├─────────────────────────────────────────────────────┤
│ PHASE 1: UI/UX → byt8:ui-ux-designer                │
│ Output: wireframes/*.html                           │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: "Sind die Wireframes akzeptiert?"          │
│ Bei Fragen/Feedback → zurück an ui-ux-designer      │
│ ✅ Bei "Ja": WIP-Commit                             │
├─────────────────────────────────────────────────────┤
│ PHASE 2: API Design → byt8:api-architect            │
│ Output: Markdown-Skizze in workflow-state.apiDesign │
├─────────────────────────────────────────────────────┤
│ PHASE 3: Database → byt8:postgresql-architect       │
│ Output: db/migration/V*.sql                         │
│ ✅ WIP-Commit (automatisch)                         │
├─────────────────────────────────────────────────────┤
│ PHASE 4: Backend → byt8:spring-boot-developer       │
│ Output: Java + JUnit Tests                          │
│ Gate: mvn test → PASS                               │
│ ✅ WIP-Commit (automatisch)                         │
├─────────────────────────────────────────────────────┤
│ PHASE 5: Frontend → byt8:angular-frontend-developer │
│ Output: Angular + Jasmine Tests                     │
│ Gate: npm test → PASS                               │
│ ✅ WIP-Commit (automatisch)                         │
├─────────────────────────────────────────────────────┤
│ PHASE 6: QA (SEQUENTIELL!)                          │
│ 1. byt8:test-engineer → E2E-Tests                   │
│    → Bei FAIL: Hotfix-Loop vor Schritt 2            │
│ 2. byt8:security-auditor → Security-Audit           │
│    → Bei FAIL: Hotfix-Loop                          │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: "Ist QA bestanden?"                        │
│ ✅ Bei "Ja": WIP-Commit                             │
├─────────────────────────────────────────────────────┤
│ PHASE 7: Code Review → byt8:code-reviewer           │
│ Status: APPROVED / CHANGES REQUIRED                 │
│ Bei CHANGES REQUIRED: Hotfix-Loop, dann erneut Ph 7 │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: Code Review muss APPROVED sein             │
├─────────────────────────────────────────────────────┤
│ PHASE 8: Push & PR (LETZTER SCHRITT!)               │
│ 1. intoBranch abfragen (Default: fromBranch)        │
│ 2. PR-Inhalt ERZEUGEN + ZEIGEN                      │
│ ⛔ STOP: "Soll ich pushen und PR erstellen?"        │
│ 3. git push + gh pr create --base <intoBranch>      │
│ 4. Duration berechnen + Todos leeren                │
│ 5. status → "idle"                                  │
│ ✅ "Full-Stack-Feature #XX abgeschlossen!" + PR-URL │
└─────────────────────────────────────────────────────┘
```

---

## ⛔ GATES (BLOCKIEREND!)

| Nach Phase | Gate-Typ | Bedingung | WIP-Commit |
|------------|----------|-----------|------------|
| 0 | User Approval | "Architektur akzeptiert?" | ❌ |
| 1 | User Approval | "Wireframes akzeptiert?" | ✅ Nach "Ja" |
| 3 | Automatisch | Phase abgeschlossen | ✅ |
| 4 | Automatisch | `mvn test` → PASS | ✅ |
| 5 | Automatisch | `npm test` → PASS | ✅ |
| 6 | Beide | Security + E2E PASS, "QA bestanden?" | ✅ Nach "Ja" |
| 7 | Automatisch | Code Review APPROVED | ❌ |
| 8 | User Approval | PR-Inhalt zeigen, "PR erstellen?" | Push+PR |

**VIOLATION = WORKFLOW FAILURE**

### User Approval: Feedback-Loop

Bei User Approval Gates (Phase 0, 1, 6, 8) hat der User **drei Möglichkeiten:**

| Antwort | Aktion |
|---------|--------|
| ✅ "Ja" / "Akzeptiert" | Weiter zur nächsten Phase |
| ❌ "Nein" / Feedback / Fragen | **An denselben Agent zurückdelegieren!** |
| ❓ "Abbrechen" | Workflow pausieren |

⛔ **Der Orchestrator darf NIEMALS selbst auf Fragen/Feedback antworten!**
→ Immer an den zuständigen Agent zurückdelegieren.

**Beispiel Phase 0:**
```
User: "Warum habt ihr hier REST statt GraphQL gewählt?"
→ Orchestrator delegiert die Frage an byt8:architect-planner
→ architect-planner antwortet / überarbeitet
→ Erneut fragen: "Ist die Architektur jetzt akzeptiert?"
```

**Feedback-Loop State:**
```json
{
  "nextStep": {
    "action": "AWAIT_USER_APPROVAL",
    "phase": 0,
    "feedbackRound": 2,
    "agent": "byt8:architect-planner"
  }
}
```

Der Loop wiederholt sich bis der User "Ja" sagt.

---

## ⛔ KRITISCHE CONSTRAINTS

### 1. Branch-Strategie
**NIEMALS auf `fromBranch` oder `intoBranch` committen!**
```bash
git checkout <fromBranch> && git pull
git checkout -b feature/issue-{N}-{kurzbeschreibung}
```

### 2. Git Commit Approval
VOR JEDEM Push/PR: User-Genehmigung einholen.
**AUSNAHME:** WIP-Commits nach Test-Gates (Phase 3, 4, 5) erfolgen automatisch.

### 3. PR-Erstellung
```bash
gh pr create --base <intoBranch> --title "..." --body "..."
# intoBranch wird in Phase 8 abgefragt
```

### 4. WIP-Commits

| Phase | Commit? | Wann? |
|-------|---------|-------|
| 0, 2, 7 | ❌ | - |
| 1 | ✅ | Nach User-Approval |
| 3, 4, 5 | ✅ | Automatisch nach PASS |
| 6 | ✅ | Nach QA Approval |
| 8 | ❌ | Nur Push + PR |

### 5. Code-Änderungen NUR über Agents

| Typ | Agent |
|-----|-------|
| Frontend (.ts, .html, .scss) | `byt8:angular-frontend-developer` |
| Backend (.java) | `byt8:spring-boot-developer` |
| Tests (.spec.ts) | `byt8:test-engineer` |
| DB (.sql) | `byt8:postgresql-architect` |

**Claude darf:** Git, Workflow-State, Agents starten, Approvals zeigen
**Claude darf NICHT:** Code schreiben (auch keine "kleinen Fixes")

### 6. Context7 + Angular CLI MCP für Best Practices
**IMMER MCP Tools nutzen** bei Library-Versionen, Framework-Syntax, CLI-Befehlen.
```
# Context7 (allgemeine Libraries)
mcp__plugin_byt8_context7__resolve-library-id → mcp__plugin_byt8_context7__query-docs

# Angular CLI (Angular-spezifisch)
mcp__plugin_byt8_angular-cli__get_best_practices
mcp__plugin_byt8_angular-cli__find_examples
```

### 7. E2E-Tests Infrastruktur
E2E-Tests starten eigene Infrastruktur via Testcontainers (eigene Ports). Kein manuelles Starten nötig.

---

## Agent Mapping

| Phase | Agent | Aufgabe |
|-------|-------|---------|
| 0 | `byt8:architect-planner` | Technical Spec |
| 1 | `byt8:ui-ux-designer` | Wireframes |
| 2 | `byt8:api-architect` | API-Skizze |
| 3 | `byt8:postgresql-architect` | Migrations |
| 4 | `byt8:spring-boot-developer` | Java + Tests |
| 5 | `byt8:angular-frontend-developer` | Angular + Tests |
| 6.1 | `byt8:test-engineer` | E2E-Tests (ZUERST) |
| 6.2 | `byt8:security-auditor` | Security-Audit (DANACH) |
| 7 | `byt8:code-reviewer` | Review + Hotfix |
| 8 | Claude (nur Git) | Push + PR → FERTIG |

---

## Workflow State + Context

**Location:** `.workflow/workflow-state.json`

```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": 42, "title": "...", "url": "..." },
  "branch": "feature/issue-42-...",
  "fromBranch": "develop",
  "intoBranch": null,
  "currentPhase": 3,
  "startedAt": "2025-12-29T12:00:00Z",
  "phases": {
    "0": { "status": "completed" },
    "3": { "status": "in_progress" }
  },
  "nextStep": {
    "action": "CONTINUE_PHASE_3",
    "phase": 3,
    "description": "Database Migrations fortsetzen",
    "agent": "byt8:postgresql-architect"
  },
  "context": {
    "technicalSpec": { "storedAt": "...", "storedByPhase": 0, "data": {...} },
    "wireframes": { "storedAt": "...", "storedByPhase": 1, "data": {...} },
    "apiDesign": { "storedAt": "...", "storedByPhase": 2, "data": {...} }
  }
}
```

### Context Keys pro Phase

| Phase | Key | Agent |
|-------|-----|-------|
| 0 | `technicalSpec` | architect-planner |
| 1 | `wireframes` | ui-ux-designer |
| 2 | `apiDesign` | api-architect |
| 3 | `migrations` | postgresql-architect |
| 4 | `backendImpl` | spring-boot-developer |
| 5 | `frontendImpl` | angular-frontend-developer |
| 6 | `testResults` | test-engineer |
| 7 | `reviewFeedback` | code-reviewer |

**Speicher-Format:** `context.<key> = { storedAt, storedByPhase, data: <Agent-Output> }`

---

## State Management (Orchestrator-Pflichten)

### Nach JEDER Phase MUSS Claude:

1. **Agent-Output lesen** (CONTEXT STORE REQUEST)
2. **State-Datei lesen:** `cat .workflow/workflow-state.json`
3. **State aktualisieren** mit Write-Tool:
   - `currentPhase` → Nächste Phase
   - `phases[N].status` → `"completed"`
   - `nextStep` → Nächste Aktion
   - `context[key]` → Agent-Summary

### nextStep-Werte

| Action | Bedeutung | Voraussetzung |
|--------|-----------|---------------|
| `START_PHASE_X` | Phase X starten | Vorherige completed |
| `CONTINUE_PHASE_X` | Phase X fortsetzen | Phase X in_progress |
| `HOTFIX_PHASE_X` | Hotfix starten | Fehler erkannt |
| `AWAIT_USER_APPROVAL` | Auf User warten | Gate erreicht |
| `PUSH_AND_PR` | Push + PR | Phase 7 APPROVED |

### ⛔ Validation (vor JEDER Aktion!)

```
□ workflow-state.json gelesen?
□ nextStep.action === geplante Aktion?
□ Alle vorherigen Phasen completed?
□ Bei Hotfix: Phasen 7+ auf "pending" zurückgesetzt?
```

**Bei Mismatch: STOP! User informieren!**

### Hotfix-Loop State

Bei Hotfix ALLE nachfolgenden Phasen auf `pending` setzen:
```json
{
  "currentPhase": 6,
  "phases": { "6": {"status":"in_progress"}, "7": {"status":"pending"}, "8": {"status":"pending"} },
  "nextStep": { "action": "HOTFIX_PHASE_6", "hotfixReason": "...", "returnToPhase": 8 }
}
```
Nach Hotfix: ALLE Phasen ab Hotfix bis Phase 7 durchlaufen → 7 muss APPROVED → dann PUSH_AND_PR erlaubt.

---

## Test Enforcement

| Phase | Test-Befehl | Pflicht |
|-------|-------------|---------|
| 4 | `mvn test` | ✅ PASS |
| 5 | `npm test -- --no-watch --browsers=ChromeHeadless` | ✅ PASS |
| 6 | `mvn failsafe:integration-test` + `npx playwright test` | ✅ PASS |

---

## Hotfix-Loop

**Bei Fehler in Phase 4-8:**

| Fix-Typ | Agent | Start |
|---------|-------|-------|
| Database | `byt8:postgresql-architect` | Phase 3 |
| Backend | `byt8:spring-boot-developer` | Phase 4 |
| Frontend | `byt8:angular-frontend-developer` | Phase 5 |
| Tests | `byt8:test-engineer` | Phase 6 |

1. `currentPhase` + `nextStep` auf Start-Phase setzen
2. Agent starten für Fix
3. ALLE nachfolgenden Phasen durchlaufen
4. WIP-Commit nach jeder Phase
5. Phase 7 APPROVED → dann weiter zu Phase 8

---

## WIP-Commits

| Phase | Output | Commit? |
|-------|--------|---------|
| 0 | Technical Spec (state) | ❌ |
| 1 | Wireframes (HTML) | ✅ Nach Approval |
| 2 | API Design (state) | ❌ |
| 3 | Migrations (SQL) | ✅ Automatisch |
| 4 | Backend (Java) | ✅ Nach PASS |
| 5 | Frontend (Angular) | ✅ Nach PASS |
| 6 | E2E-Tests (Playwright) | ✅ Nach Approval |
| 7 | Review (Report) | ❌ |

**Format:**
```bash
git add -A && git commit -m "wip(#<issue>/phase-<nr> - <name>): <Beschreibung> - <Issue-Titel>"
```
