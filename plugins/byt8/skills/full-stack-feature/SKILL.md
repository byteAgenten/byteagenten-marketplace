---
name: full-stack-feature
description: Orchestrates full-stack feature development with approval gates and agent delegation.
version: 2.24.0
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
1. `currentPhase` + `nextStep` notieren
2. ⛔ Skill neu laden: `/byt8:full-stack-feature`
3. ⛔ SKILL.md wird KOMPLETT gelesen (PFLICHT!)
4. `nextStep` VALIDIEREN bevor fortgesetzt wird
5. NIEMALS improvisieren - nur definierte Schritte!

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

⛔ **KEIN Code, KEINE Phase starten, KEIN Commit BEVOR diese Schritte erledigt sind:**

```
1. workflow-state.json lesen → currentPhase + nextStep notieren
2. ⛔ DIESEN SKILL.md KOMPLETT LESEN! (PFLICHT!)
3. nextStep.action VALIDIEREN:
   □ Stimmt nextStep.phase mit currentPhase überein?
   □ Sind alle vorherigen Phasen "completed"?
   □ Bei Hotfix-Feld: → Hotfix-Detection (siehe unten)
4. Erst DANN ab nextStep.action fortsetzen
5. NIEMALS improvisieren - nur definierte Schritte!
```

**Hotfix-Detection (bei Context-Overflow Recovery):**

Wenn `workflow-state.json` ein `hotfix`-Feld enthält:
1. ⛔ STOP - Hotfix-Loop ist aktiv!
2. Prüfe: Alle Phasen ab `hotfix.startedAtPhase` bis 7 auf `"pending"`?
3. Wenn nicht → State korrigieren, DANN erst fortfahren
4. `currentPhase` muss `hotfix.startedAtPhase + 1` sein (nächste Phase nach Fix)

**Phase-8-Recovery (bei Context-Overflow in Phase 8):**

Wenn `currentPhase === 8`:
1. `phases["8"]` auf vorhandene Felder prüfen:
   - Kein `intoBranch` → nextStep = `PHASE_8_QUERY_INTO_BRANCH`
   - `intoBranch` aber kein `prContent` → nextStep = `PHASE_8_GENERATE_PR`
   - `prContent` aber nicht `approved` → nextStep = `PHASE_8_SHOW_PR`
   - `approved = true` aber kein `prUrl` → nextStep = `PHASE_8_EXECUTE_PUSH`
   - `prUrl` vorhanden → nextStep = `PHASE_8_COMPLETE`
2. State korrigieren falls `nextStep` nicht zu den Feldern passt
3. Ab korrektem Sub-Step fortsetzen

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
│ PHASE 8: Push & PR (6 SUB-STEPS!)                    │
│ 8.1 intoBranch abfragen (Default: fromBranch)        │
│     → phases["8"].intoBranch speichern               │
│ 8.2 PR-Inhalt ERZEUGEN (aus Context-Keys)            │
│     → phases["8"].prContent speichern                │
│ 8.3 PR-Inhalt dem User ZEIGEN                        │
│ 8.4 ⛔ STOP: "Soll ich pushen und PR erstellen?"    │
│     → phases["8"].approved = true                    │
│ 8.5 git push + gh pr create --base <intoBranch>      │
│     → phases["8"].prUrl speichern                    │
│ 8.6 Duration + Abschlussmeldung → status "idle"      │
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
| 7 | User Approval | Code Review APPROVED | ❌ |
| 8 | User Approval (6 Sub-Steps!) | Siehe "Phase 8: Push & PR (Detail)" | Push+PR |

**VIOLATION = WORKFLOW FAILURE**

### User Approval: Feedback-Loop

Bei User Approval Gates (Phase 0, 1, 6, 8) hat der User **drei Möglichkeiten:**

| Antwort | Aktion |
|---------|--------|
| ✅ "Ja" / "Akzeptiert" | Weiter zur nächsten Phase |
| ❌ "Nein" / Feedback / Fragen | **An denselben Agent zurückdelegieren!** |
| ❓ "Abbrechen" | Workflow pausieren |

⛔ **Der Orchestrator ist ein ROUTER, kein DENKER!**

**VERBOTEN für den Orchestrator:**
- ❌ Dateien lesen die zum Agent gehören (HTML, SCSS, Java, TypeScript)
- ❌ Screenshots analysieren und Probleme identifizieren
- ❌ Lösungen vordenken und dem Agent vorgeben
- ❌ Design-, Code- oder Architektur-Entscheidungen treffen
- ❌ User-Feedback interpretieren oder zusammenfassen

**PFLICHT für den Orchestrator:**
- ✅ User-Feedback **RAW** an den zuständigen Agent weiterleiten
- ✅ Nur Workflow-Context mitgeben (welche Phase, welcher Agent, was war der Auftrag)
- ✅ Screenshots/Dateipfade weitergeben, NICHT selbst analysieren
- ✅ Den Agent die Analyse, das Denken und die Lösung überlassen

**Beispiel Phase 1 (RICHTIG):**
```
User: "Das sieht nicht sauber aus" + Screenshot-Pfad
→ Orchestrator an byt8:ui-ux-designer:
  "User-Feedback: 'Das sieht nicht sauber aus'. Screenshot: <pfad>. Bitte analysieren und korrigieren."
→ ui-ux-designer liest Screenshot, analysiert, liest bestehende Styles, korrigiert
→ Erneut fragen: "Sind die Wireframes jetzt akzeptiert?"
```

**Beispiel Phase 1 (FALSCH - VIOLATION!):**
```
User: "Das sieht nicht sauber aus" + Screenshot-Pfad
→ Orchestrator liest Screenshot SELBST
→ Orchestrator liest SCSS-Dateien SELBST
→ Orchestrator identifiziert: "border-radius falsch, gap fehlt"
→ Orchestrator an Agent: "Fix border-radius to 4px and add gap: 12px"
→ Agent baut nur nach was Orchestrator sagt (kein eigenes Denken!)
= VIOLATION! Agent wurde zum Copy-Paste-Roboter degradiert!
```

**Beispiel Phase 0:**
```
User: "Warum habt ihr hier REST statt GraphQL gewählt?"
→ Orchestrator an byt8:architect-planner:
  "User fragt: 'Warum REST statt GraphQL?' Bitte erklären oder Architektur überarbeiten."
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

**Claude (Orchestrator) darf:**
- Git-Befehle, Workflow-State lesen/schreiben
- Agents starten, Approvals zeigen
- User-Feedback RAW an Agents weiterleiten

**Claude (Orchestrator) darf NICHT:**
- Code schreiben (auch keine "kleinen Fixes")
- Dateien lesen die zum Agent gehören (HTML, SCSS, Java, .ts)
- Screenshots/Designs analysieren (→ Agent!)
- Lösungen vordenken und Agents nur "ausführen" lassen

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
| 8 | Claude (nur Git, 6 Sub-Steps!) | Push + PR → FERTIG |

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
4. ⛔ **State-Checkpoint ausgeben (PFLICHT!):**
   ```
   ───────────────────────────────────────
   📍 WORKFLOW STATE UPDATE
   Phase X → completed
   Nächste Phase: Y (nextStep: ACTION_NAME)
   ───────────────────────────────────────
   ```
   ⚠️ Wenn diese Ausgabe NICHT erscheint → State wurde NICHT aktualisiert → VIOLATION!

**NIEMALS eine Phase starten ohne vorher Schritt 1-4 für die vorherige Phase abgeschlossen zu haben!**

### nextStep-Werte

| Action | Bedeutung | Voraussetzung |
|--------|-----------|---------------|
| `START_PHASE_X` | Phase X starten | Vorherige completed |
| `CONTINUE_PHASE_X` | Phase X fortsetzen | Phase X in_progress |
| `HOTFIX_PHASE_X` | Hotfix starten | Fehler erkannt |
| `AWAIT_USER_APPROVAL` | Auf User warten | Gate erreicht |
| `PHASE_8_QUERY_INTO_BRANCH` | intoBranch abfragen | Phase 7 APPROVED |
| `PHASE_8_GENERATE_PR` | PR-Inhalt generieren | intoBranch gespeichert |
| `PHASE_8_SHOW_PR` | PR-Inhalt zeigen | prContent gespeichert |
| `PHASE_8_AWAIT_APPROVAL` | User-Approval | PR gezeigt |
| `PHASE_8_EXECUTE_PUSH` | Push + PR erstellen | approved = true |
| `PHASE_8_COMPLETE` | Abschluss + Duration | prUrl gespeichert |

### ⛔ Validation (vor JEDER Aktion!)

```
□ workflow-state.json gelesen?
□ nextStep.action === geplante Aktion?
□ Alle vorherigen Phasen completed?
□ Bei Hotfix: Phasen 7+ auf "pending" zurückgesetzt?
□ Bei Phase 8: phases["8"]-Felder prüfen:
  → intoBranch fehlt? → PHASE_8_QUERY_INTO_BRANCH
  → prContent fehlt? → PHASE_8_GENERATE_PR
  → approved fehlt? → PHASE_8_SHOW_PR
  → Fehlende Felder = Sub-Step übersprungen → STOP!
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
Nach Hotfix: ALLE Phasen ab Hotfix bis Phase 7 durchlaufen → 7 muss APPROVED → dann Phase 8 (ab PHASE_8_QUERY_INTO_BRANCH).

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

### ⛔ Checkpoint VOR JEDER Phase im Hotfix-Loop:

```
□ workflow-state.json gelesen?
□ currentPhase == geplante Phase?
□ Alle vorherigen Phasen "completed"?
□ nextStep.action stimmt mit geplanter Aktion überein?
→ Bei Mismatch: STOP + User informieren!
```

**NIEMALS Phasen überspringen, auch wenn sie "unnötig" erscheinen!**

### Ablauf:

1. `currentPhase` + `nextStep` auf Start-Phase setzen
2. **ALLE Phasen ab Hotfix-Start als `"pending"` setzen** (auch 5, 6, 7!)
3. Agent starten für Fix
4. **ALLE nachfolgenden Phasen durchlaufen** (keine darf übersprungen werden!)
5. WIP-Commit nach jeder Phase
6. Phase 7 APPROVED → dann weiter zu Phase 8

---

## Phase 8: Push & PR (Detail)

⛔ **Phase 8 hat 6 Sub-Steps. JEDER muss einzeln ausgeführt und im State gespeichert werden!**

### 8.1 PHASE_8_QUERY_INTO_BRANCH
- User fragen: "In welchen Branch soll der PR gehen? (Default: `<fromBranch>`)"
- Antwort speichern: `phases["8"].intoBranch = <Antwort>`
- nextStep → `PHASE_8_GENERATE_PR`

### 8.2 PHASE_8_GENERATE_PR
- PR-Title generieren: `feat(#<issue>): <Issue-Titel>`
- PR-Body generieren aus context-Keys (technicalSpec, apiDesign, backendImpl, frontendImpl, testResults)
- Speichern: `phases["8"].prContent = { title, body, generatedAt }`
- nextStep → `PHASE_8_SHOW_PR`

### 8.3 PHASE_8_SHOW_PR
- PR-Inhalt formatiert ausgeben (Title + Body)
- nextStep → `PHASE_8_AWAIT_APPROVAL`

### 8.4 PHASE_8_AWAIT_APPROVAL
- "Soll ich pushen und PR erstellen?"
- Bei "Ja": `phases["8"].approved = true`, nextStep → `PHASE_8_EXECUTE_PUSH`
- Bei "Nein"/Feedback: Zurück zu 8.2 (`PHASE_8_GENERATE_PR`)

### 8.5 PHASE_8_EXECUTE_PUSH
- ⛔ Prüfe: `phases["8"].approved === true` (PFLICHT!)
- `git push -u origin <branch>`
- `gh pr create --base <intoBranch> --title <title> --body <body>`
- PR-URL speichern: `phases["8"].prUrl = <URL>`
- nextStep → `PHASE_8_COMPLETE`

### 8.6 PHASE_8_COMPLETE
- Duration berechnen: `now() - startedAt` (aus workflow-state.json Root-Feld)
- Todos leeren
- `status → "idle"`
- Abschlussmeldung ausgeben:
```
✅ Full-Stack-Feature #XX abgeschlossen!
PR: <prUrl>
Duration: X Stunden Y Minuten
```

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
