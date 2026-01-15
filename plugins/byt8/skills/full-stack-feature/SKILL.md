---
name: full-stack-feature
description: Orchestrates full-stack feature development with approval gates and agent delegation.
version: 2.6.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**When to use:** GitHub Issues, neue Features, Bugfixes die mehrere Layer betreffen (DB → Backend → Frontend).

---

## ⚠️ SKILL BOOTSTRAP - BEI JEDEM AUFRUF PRÜFEN!

### Schritt 1: CLAUDE.md vorhanden?

```bash
cat CLAUDE.md 2>/dev/null | head -20 || echo "NICHT VORHANDEN"
```

**Falls NICHT VORHANDEN → `/init` automatisch aufrufen:**

```
ℹ️ Keine CLAUDE.md gefunden. Führe /init aus...
```

**Claude MUSS das Skill-Tool verwenden um `/init` aufzurufen:**

```
Skill tool aufrufen mit: skill = "init"
```

Dies:
- Scannt das GESAMTE Repository
- Erstellt eine umfassende CLAUDE.md mit Projekt-Kontext
- Ist der offizielle Claude Code Befehl für Projekt-Initialisierung

**Nach `/init` Erfolg:**
```
✅ CLAUDE.md wurde erstellt. Fahre mit Schritt 2 fort.
```

**Weiter zu Schritt 2** (Recovery-Sektion prüfen)

### Schritt 2: Recovery-Sektion in CLAUDE.md vorhanden?

Prüfe ob die Zeile `## byt8 Workflow Recovery` in CLAUDE.md existiert.

**Falls NICHT vorhanden → Mit Edit-Tool am ANFANG der CLAUDE.md hinzufügen:**

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

**Hinweis an User:**
```
✅ Recovery-Sektion zu CLAUDE.md hinzugefügt.
   Bei Context-Overflow wird der Workflow automatisch erkannt.
```

### Schritt 3: Aktiver Workflow vorhanden?

```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "KEIN WORKFLOW"
```

| Status | Aktion |
|--------|--------|
| `"status": "active"` | Resume: "Aktiver Workflow gefunden (Phase X). Fortsetzen?" |
| `"status": "idle"` | Neuen Workflow starten |
| Nicht vorhanden | Neuen Workflow starten |

---

## Context Overflow Recovery (für Claude nach Neustart)

Falls diese Nachricht erscheint:
> "This session is being continued from a previous conversation that ran out of context."

**Der User's CLAUDE.md enthält bereits die Anweisung, diesen Skill zu laden!**

Nach Skill-Load:
1. `workflow-state.json` lesen (Schritt 3 oben)
2. `currentPhase` und `nextStep` notieren
3. Workflow ab `nextStep.action` fortsetzen
4. **NIEMALS improvisieren - nur definierte Schritte!**

---

## Workflow Ablauf

```
START → Issue erkennen → Branch erstellen
    ↓
┌─────────────────────────────────────────────────────┐
│ PHASE 0: Architecture Planning → architect-planner  │
│ Output: Technical Spec in workflow-state            │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: AskUserQuestion                            │
│    → "Ist die Architektur/Technical Spec akzeptiert?"│
│    → Weiter NUR bei "Ja"                            │
├─────────────────────────────────────────────────────┤
│ PHASE 1: UI/UX Design → ui-ux-designer              │
│ Input: Technical Spec (verfügbare Daten, Services)  │
│ Output: frontend/wireframes/*.html                  │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: AskUserQuestion                            │
│    → "Sind die Wireframes akzeptiert?"              │
│    → Weiter NUR bei "Ja"                            │
│ ✅ Bei "Ja": WIP-Commit (nach User Approval)        │
├─────────────────────────────────────────────────────┤
│ PHASE 2: API Design → api-architect                 │
│ Input: Technical Spec + Wireframes                  │
│ Output: Markdown-Skizze in workflow-state.apiDesign │
├─────────────────────────────────────────────────────┤
│ PHASE 3: Database → postgresql-architect            │
│ Output: db/migration/V*.sql                         │
│ ✅ WIP-Commit (nach Phase-Abschluss)                │
├─────────────────────────────────────────────────────┤
│ PHASE 4: Backend → spring-boot-developer            │
│ Output: Java + JUnit Tests                          │
│ Gate: mvn test → muss PASS sein (Claude prüft)      │
│ ✅ Bei PASS: WIP-Commit (automatisch, kein User-Q)  │
├─────────────────────────────────────────────────────┤
│ PHASE 5: Frontend → angular-frontend-developer      │
│ Output: Angular + Jasmine Tests                     │
│ Gate: npm test → muss PASS sein (Claude prüft)      │
│ ✅ Bei PASS: WIP-Commit (automatisch, kein User-Q)  │
├─────────────────────────────────────────────────────┤
│ PHASE 6: Quality Assurance (2 Agents SEQUENTIELL!)  │
│ 1. test-engineer → E2E-Tests erstellen + ausführen  │
│    → Bei FAIL: Hotfix-Loop (Phase 4/5) vor Schritt 2│
│ 2. security-auditor → Security-Audit                │
│    → Bei FAIL: Hotfix-Loop (Phase 4/5)              │
│ Output: E2E Tests + Security Report                 │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: AskUserQuestion                            │
│    → "Ist QA bestanden? (Security + E2E: PASS)"     │
│    → Weiter NUR bei "Ja"                            │
│ ✅ Bei "Ja": WIP-Commit (nach QA Approval)          │
├─────────────────────────────────────────────────────┤
│ PHASE 7: Code Review → code-reviewer                │
│ Output: Strukturierter Review-Report:               │
│    - Status: APPROVED / CHANGES REQUIRED            │
│    - Issues: Liste mit Severity (Critical/Major/    │
│      Minor/Suggestion)                              │
│    - Pro Issue: Datei, Zeile, Beschreibung, Fix     │
│ Bei CHANGES REQUIRED: Hotfix-Loop, dann erneut Ph 7 │
│ Optional: Eskalation an architect-reviewer          │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: Code Review muss APPROVED sein             │
│    → Bei CHANGES REQUIRED: Hotfix-Loop starten      │
│    → Weiter NUR bei APPROVED                        │
├─────────────────────────────────────────────────────┤
│ PHASE 8: Push & PR                                  │
│ 1. Push zu Remote                                   │
│ 2. PR-Inhalt ZEIGEN (Title, Body, Acceptance Crit.) │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: AskUserQuestion                            │
│    → "Soll ich diesen PR erstellen?"                │
│    → Weiter NUR bei "Ja"                            │
├─────────────────────────────────────────────────────┤
│ 3. PR erstellen mit:                                │
│    - Acceptance Criteria aus Issue übernehmen       │
│    - Closes #<issue-nr> verlinken                   │
├─────────────────────────────────────────────────────┤
│ PHASE 9: Merge                                      │
│ 1. VOR MERGE - Claude prüft & hakt ab:              │
│    - Acceptance Criteria: Erfüllt? → [x] setzen     │
│    - Checklist: Erfüllt? → [x] setzen               │
│    - ROADMAP.md: Betroffen? → aktualisieren + [x]   │
├─────────────────────────────────────────────────────┤
│ ⛔ STOP: AskUserQuestion                            │
│    → "Alle [x] gesetzt. Soll ich den PR mergen?"    │
│    → Weiter NUR bei "Ja"                            │
├─────────────────────────────────────────────────────┤
│ 2. PR mergen                                        │
├─────────────────────────────────────────────────────┤
│ PHASE 10: Cleanup (AUTOMATISCH nach PR-Merge!)      │
│ 1. git checkout main && git pull                    │
│ 2. Branch löschen (lokal + remote)                  │
│ 3. Duration berechnen (startedAt → jetzt)           │
│ 4. workflow-state.json → status: "idle"             │
│ 5. Todos leeren                                     │
│ 6. ✅ "Full-Stack-Feature #XX abgeschlossen in Xm!" │
└─────────────────────────────────────────────────────┘
```

---

## ⛔ GATES (BLOCKIEREND!)

**Nach diesen Phasen MUSS Claude die Gate-Bedingung prüfen:**

| Nach Phase | Gate-Typ | Bedingung | Weiter bei | WIP-Commit |
|------------|----------|-----------|------------|------------|
| 0 | User Approval | `AskUserQuestion` → "Architektur akzeptiert?" | "Ja" | ❌ Nein |
| 1 | User Approval | `AskUserQuestion` → "Wireframes akzeptiert?" | "Ja" | ✅ Nach "Ja" |
| 3 | Automatisch | Phase abgeschlossen | Migrations erstellt | ✅ Automatisch |
| 4 | Automatisch | Claude: `mvn test` ausführen | PASS | ✅ Automatisch |
| 5 | Automatisch | Claude: `npm test` ausführen | PASS | ✅ Automatisch |
| 6 | Beide | Security + E2E PASS, dann `AskUserQuestion` → "QA bestanden?" | Beide ✓ | ✅ Nach "Ja" |
| 7 | Automatisch | Code Review Status | APPROVED | ❌ Nein |
| 8 | User Approval | PR-Inhalt ZEIGEN, dann `AskUserQuestion` → "Soll ich diesen PR erstellen?" | "Ja" | ❌ Push+PR |
| 9 | User Approval | Claude: Checkliste abhaken, dann `AskUserQuestion` → "Soll ich mergen?" | "Ja" | ❌ Merge |

**Claude darf NICHT zur nächsten Phase ohne erfüllte Gate-Bedingung!**

**VIOLATION = WORKFLOW FAILURE**

---

## ⛔ KRITISCHE PROJEKT-CONSTRAINTS (Self-Contained)

Diese Regeln gelten für JEDEN Workflow-Durchlauf. **Kein externes CLAUDE.md erforderlich!**

### Constraint 1: Branch-Strategie

**NIEMALS direkt auf `main` committen!**

```bash
# Vor dem ersten Commit prüfen:
git branch --show-current
# Falls "main" → STOP! Erst Branch erstellen!
```

- Feature-Branch erstellen: `feature/issue-{N}-{kurzbeschreibung}`
- Branch erst nach Phase 7 (Code Review) APPROVED pushen
- **VIOLATION = WORKFLOW FAILURE**

### Constraint 2: Git Commit Approval

**VOR JEDEM Push/PR/Merge: User-Genehmigung einholen!**

1. Vollständige Commit Message präsentieren
2. Fragen: "Soll ich diesen Commit durchführen?"
3. Auf Bestätigung ("ja", "yes") warten
4. Erst NACH Bestätigung ausführen

**AUSNAHME:** WIP-Commits nach Test-Gates (Phase 3, 4, 5) erfolgen automatisch nach PASS.

### Constraint 3: Merge-Strategie

```bash
gh pr merge --merge   # NICHT --squash oder --rebase!
```

Commit-Historie erhalten!

### Constraint 4: WIP-Commits pro Phase

| Phase | Commit erlaubt? | Wann? |
|-------|-----------------|-------|
| 0 | ❌ | - |
| 1 | ✅ | Nach User-Approval |
| 2 | ❌ | - |
| 3 | ✅ | Automatisch nach Phase |
| 4 | ✅ | Nach Test PASS |
| 5 | ✅ | Nach Test PASS |
| 6 | ✅ | Nach QA Approval |
| 7 | ❌ | - |

**Phase 8+9:** Kein Commit - nur Push, PR, Merge.

### Constraint 5: Hotfix-Loop

Bei Änderungen im Workflow → zurück zur passenden Phase, dann alle nachfolgenden Phasen erneut durchlaufen. Details siehe "Hotfix-Loop" Sektion.

### Constraint 6: Code-Änderungen NUR über Agents

**Im Workflow-Modus:**

| Typ | Agent |
|-----|-------|
| Frontend (.ts, .html, .scss) | `angular-frontend-developer` |
| Backend (.java) | `spring-boot-developer` |
| Tests (.spec.ts) | `test-engineer` |
| DB (.sql) | `postgresql-architect` |

**Claude darf NUR:** Git, Workflow-State, Agents starten, Approvals zeigen
**Claude darf NICHT:** Code schreiben/ändern (auch keine "kleinen Fixes")

**VIOLATION = WORKFLOW FAILURE**

### Constraint 7: Context7 für Best Practices

**IMMER Context7 MCP nutzen bei:**
- Library-Versionen und Breaking Changes
- Framework-Syntax (Angular 21, Spring Boot 4)
- CLI-Befehle und Flags
- API-Methoden und Parameter

```
mcp__context7__resolve-library-id → mcp__context7__query-docs
```

**NIEMALS:** Flags/Parameter/API-Methoden erfinden!

### Constraint 8: E2E-Tests Infrastruktur

E2E-Tests (Playwright) starten ihre **eigene Infrastruktur** via Testcontainers:

| Komponente | E2E-Port | Dev-Port |
|------------|----------|----------|
| PostgreSQL | Dynamisch | 5432 |
| Backend | 8081 | 8080 |
| Frontend | 4201 | 4200 |

**Kein manuelles Starten nötig!** Tests starten/stoppen alles automatisch.

---

## Agent Mapping (Constraint #6)

| Phase | Agent | Aufgabe | Reihenfolge |
|-------|-------|---------|-------------|
| 0 | `architect-planner` | Technical Spec erstellen | |
| 1 | `ui-ux-designer` | Wireframes (mit Tech Spec Input) | |
| 2 | `api-architect` | API-Skizze (workflow-state) | |
| 3 | `postgresql-architect` | Migrations | |
| 4 | `spring-boot-developer` | Java + Tests | |
| 5 | `angular-frontend-developer` | Angular + Tests | |
| 6.1 | `test-engineer` | E2E-Tests | 1️⃣ ZUERST |
| 6.2 | `security-auditor` | Security-Audit | 2️⃣ DANACH |
| 7 | `code-reviewer` | Review + Hotfix | |
| 8 | Claude (nur Git) | Push + PR | |
| 9 | Claude (nur Git) | Merge (nach Checkliste) | |
| 10 | Claude (Cleanup) | Branch löschen, State → idle | |

**Claude darf NUR:** Git, Workflow-State, Agents starten, Approvals zeigen
**Claude darf NICHT:** Code schreiben/ändern (auch keine "kleinen Fixes")

---

## Usage

```
/full-stack-feature #42
/full-stack-feature "Implement vacation tracking"
/full-stack-feature                                  # Ohne Argument
```

---

## Startup-Logik

### Bei Skill-Start (IMMER ausführen!)

**1. Workflow-Verzeichnis erstellen:**
```bash
mkdir -p .workflow
```

**2. State prüfen:**
```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NICHT VORHANDEN"
```

**3. Entscheidung:**

| State | Aktion |
|-------|--------|
| `"status": "active"` | Resume anbieten: "Aktiver Workflow gefunden (Phase X). Fortsetzen?" |
| `"status": "idle"` oder nicht vorhanden | Neuen Workflow starten |

**4. Falls neuer Workflow:** State initialisieren mit Write-Tool:

```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": null, "title": "", "url": "" },
  "branch": "",
  "currentPhase": 0,
  "startedAt": "[ISO-TIMESTAMP]",
  "phases": {},
  "nextStep": {
    "action": "START_PHASE_0",
    "phase": 0,
    "description": "Technical Specification erstellen",
    "agent": "architect-planner"
  },
  "context": {}
}
```

### Argument-Handling

| Argument | Aktion |
|----------|--------|
| `#42` | GitHub Issue laden, Titel + URL in State speichern |
| `"Implement X"` | Als Titel verwenden, kein Issue-Link |
| Kein Argument | Fragen: "Was möchtest du implementieren?" |

**WICHTIG:** Keine AskUserQuestion für Argument! Einfach auf Eingabe warten.

---

## Workflow State

**Location:** `.workflow/workflow-state.json`

```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": 42, "title": "...", "url": "..." },
  "branch": "feature/issue-42-...",
  "currentPhase": 3,
  "startedAt": "2025-12-29T12:00:00Z",
  "phases": {
    "0": { "status": "completed" },
    "3": { "status": "in_progress" },
    "8": { "status": "pending" }
  },
  "nextStep": {
    "action": "CONTINUE_PHASE_3",
    "phase": 3,
    "description": "Database Migrations fortsetzen",
    "agent": "postgresql-architect"
  },
  "context": {
    "wireframes": {
      "storedAt": "2025-12-29T12:15:00Z",
      "storedByPhase": 0,
      "data": { "paths": [...], "components": [...] }
    },
    "apiDesign": {
      "storedAt": "2025-12-29T12:30:00Z",
      "storedByPhase": 1,
      "data": { "endpoints": [...], "businessRules": [...] }
    },
    "migrations": {
      "storedAt": "2025-12-29T12:45:00Z",
      "storedByPhase": 2,
      "data": { "files": [...], "tables": [...] }
    }
  }
}
```

### nextStep Feld (Context-Overflow Recovery)

**PFLICHT:** Nach jeder Aktion muss `nextStep` aktualisiert werden!

| Situation | nextStep.action | Bedeutung |
|-----------|-----------------|-----------|
| Phase X läuft | `CONTINUE_PHASE_X` | Phase X noch nicht abgeschlossen, fortsetzen |
| Phase X fertig | `START_PHASE_Y` | Phase X completed, nächste Phase Y starten |
| PR gemerged | `RUN_PHASE_10` | Cleanup durchführen |
| Workflow fertig | `null` | Status = idle |

**`context`:** Speichert Phase-Outputs für Downstream-Agents und Session-Recovery.

---

## ⚠️ CLAUDE ORCHESTRATOR: State Update nach JEDER Phase (PFLICHT!)

**Nach Abschluss eines Agents MUSST du als Orchestrator:**

### 1. Agent-Output lesen

Der Agent gibt am Ende einen "CONTEXT STORE REQUEST" oder Summary aus.

### 2. State-Datei lesen

```bash
cat .workflow/workflow-state.json
```

### 3. State aktualisieren mit Write-Tool

**PFLICHT-Felder bei jedem Update:**

| Feld | Aktualisieren auf |
|------|-------------------|
| `currentPhase` | Nächste Phase-Nummer |
| `phases[N].status` | `"completed"` |
| `nextStep.action` | Nächste Aktion (z.B. `START_PHASE_2`) |
| `nextStep.phase` | Nächste Phase-Nummer |
| `nextStep.description` | Beschreibung der nächsten Phase |
| `nextStep.agent` | Agent für nächste Phase |
| `context[key]` | Summary vom Agent |

### 4. Beispiel: Nach Phase 0 (architect-planner)

```json
{
  "currentPhase": 1,
  "phases": {
    "0": { "status": "completed", "completedAt": "2026-01-15T10:30:00Z" }
  },
  "nextStep": {
    "action": "START_PHASE_1",
    "phase": 1,
    "description": "UI/UX Wireframes erstellen",
    "agent": "ui-ux-designer"
  },
  "context": {
    "technicalSpec": {
      "storedAt": "2026-01-15T10:30:00Z",
      "storedByPhase": 0,
      "data": {
        "affectedLayers": ["frontend", "backend"],
        "newEntities": ["VacationRequest"],
        "risks": []
      }
    }
  }
}
```

### 5. ERST DANN zur nächsten Phase/Gate

**REIHENFOLGE:**
1. Agent fertig → Output lesen
2. State-Datei lesen
3. State mit Write-Tool aktualisieren
4. Gate prüfen (falls vorhanden)
5. Nächste Phase starten

**VIOLATION = State geht bei Context-Overflow verloren!**

---

## ⛔ nextStep Validation (KRITISCH!)

**Claude MUSS vor JEDER Workflow-Aktion:**

### 1. State lesen und validieren
```
workflow-state.json lesen
ASSERT: nextStep.action === geplante Aktion
ASSERT: nextStep.phase === Ziel-Phase
```

### 2. Erlaubte Actions

| Action | Bedeutung | Voraussetzung |
|--------|-----------|---------------|
| `START_PHASE_X` | Phase X starten | Vorherige Phase completed/skipped |
| `CONTINUE_PHASE_X` | Phase X fortsetzen | Phase X ist in_progress |
| `HOTFIX_PHASE_X` | Hotfix in Phase X starten | Fehler in späterer Phase erkannt |
| `AWAIT_USER_APPROVAL` | Auf User-Genehmigung warten | Gate erreicht |
| `PUSH_AND_PR` | Push + PR erstellen | Phase 7 APPROVED, alle Tests PASS |
| `MERGE_PR` | PR mergen | PR approved, CI grün, **Claude hat alle [x] gesetzt** |
| `RUN_PHASE_10` | Cleanup starten | PR merged |

### 3. Bei Mismatch: STOP!

```
⛔ STOP! Aktion nicht erlaubt.

Geplante Aktion: [X]
nextStep.action: [Y]

Mögliche Ursachen:
- Phase übersprungen
- Hotfix-Loop nicht korrekt durchlaufen
- User-Approval fehlt

→ User fragen bevor fortgefahren wird!
```

### 4. Hotfix-Loop State Management

**Bei Hotfix MUSS der State korrekt aktualisiert werden:**

```json
{
  "currentPhase": 6,
  "phases": {
    "6": { "status": "in_progress" },
    "7": { "status": "pending" },  // ← RESET auf pending!
    "8": { "status": "pending" }   // ← RESET auf pending!
  },
  "nextStep": {
    "action": "HOTFIX_PHASE_6",
    "phase": 6,
    "description": "E2E-Tests fixen nach Push-Fehler",
    "hotfixReason": "E2E test naming convention",
    "returnToPhase": 8
  }
}
```

**Nach Hotfix-Abschluss:**
- ALLE Phasen ab Hotfix-Phase bis Phase 7 durchlaufen
- Phase 7 MUSS erneut APPROVED werden
- Erst dann `nextStep.action = "PUSH_AND_PR"` erlaubt

### 5. Validierungs-Checkliste (vor jeder Aktion)

```
□ workflow-state.json gelesen?
□ nextStep.action entspricht geplanter Aktion?
□ Alle vorherigen Phasen completed/skipped?
□ Bei Phase 9 (Merge): Alle Checklisten-Punkte [x] gesetzt?
□ Bei MERGE_PR: Claude hat Acceptance Criteria geprüft & [x] gesetzt?
□ Bei MERGE_PR: Claude hat Checklist geprüft & [x] gesetzt?
□ Bei MERGE_PR: ROADMAP.md aktualisiert (falls betroffen)?
□ Bei Hotfix: State korrekt zurückgesetzt?
```

**VIOLATION = WORKFLOW FAILURE → User informieren, nicht fortfahren!**

---

## Context-Speicherung

Claude speichert Phase-Outputs **direkt** in `workflow-state.json` für **Recovery bei Context-Overflow**.

### Summary-Schemas (PFLICHT!)

Nach jeder Phase speichert Claude eine **Summary** mit allen relevanten Details:

| Phase | Key | Schema |
|-------|-----|--------|
| 0 | `technicalSpec` | `{ affectedLayers: [], reuseServices: [], newEntities: [], risks: [] }` |
| 1 | `wireframes` | `{ paths: [], components: [], layout: "" }` |
| 2 | `apiDesign` | `{ endpoints: [], entities: [], rules: [] }` |
| 3 | `migrations` | `{ files: [], tables: [], indexes: [] }` |
| 4 | `backendImpl` | `{ files: [], tests: 0, coverage: "" }` |
| 5 | `frontendImpl` | `{ files: [], tests: 0, coverage: "" }` |
| 6 | `testResults` | `{ e2e: 0, unit: 0, coverage: "" }` |
| 7 | `reviewFeedback` | `{ status: "APPROVED/CHANGES_REQUIRED", issues: [{ severity: "Critical/Major/Minor/Suggestion", file: "", line: 0, description: "", fix: "" }] }` |

### Beispiel: Summary-Struktur

```json
{
  "context": {
    "backendImpl": {
      "storedAt": "2026-01-01T13:00:00Z",
      "storedByPhase": 3,
      "data": {
        "files": ["UserStatus.java", "AdminUserResponse.java", "UserRepository.java"],
        "tests": 12,
        "coverage": "87%",
        "keyChanges": ["INCOMPLETE status", "null handling"]
      }
    }
  }
}
```

**Recovery:** Bei Context-Overflow → `workflow-state.json` lesen, Summaries nutzen

---

## Test Enforcement

**VOR Phase-Abschluss:**

| Phase | Test-Befehl | Pflicht |
|-------|-------------|---------|
| 4 | `mvn test` | ✅ PASS required |
| 5 | `npm test -- --no-watch --browsers=ChromeHeadless` | ✅ PASS required |
| 6 | `mvn failsafe:integration-test` + `npx playwright test` | ✅ PASS required |

**Coverage:** User zu Beginn fragen (50%/70%/85%/95%)

---

## Hotfix-Loop (Alle Phasen!)

**Bei Fehler/Änderungsbedarf in JEDER Phase (4, 5, 6, 7, 8):**

1. **Fix-Typ bestimmen** → Start-Phase + Agent:

   | Fix-Typ | Agent | Start |
   |---------|-------|-------|
   | Database | `postgresql-architect` | Phase 3 |
   | Backend | `spring-boot-developer` | Phase 4 |
   | Frontend | `angular-frontend-developer` | Phase 5 |
   | Tests/Docs | `test-engineer` | Phase 6 |

2. **Workflow-State:** `currentPhase` + `nextStep` auf Start-Phase setzen
3. **Agent starten** für den Fix
4. **Alle nachfolgenden Phasen durchlaufen** bis zur ursprünglichen Phase
5. **WIP-Commit** nach jeder Phase
6. **Phase 7 muss APPROVED sein** → erst dann weiter zu Phase 8 (Push)

**Beispiele:**
- Phase 6 E2E schlägt fehl wegen Backend → zurück zu Phase 4 → 5 → 6
- Phase 5 braucht neues DB-Feld → zurück zu Phase 3 → 4 → 5
- Phase 8 Bug nach Push → zurück zur passenden Phase → neu pushen

---

## Phase 10: Cleanup (AUTOMATISCH!)

**SOFORT nach PR-Merge ausführen** - Details siehe "Workflow Ablauf".

**Workflow ist NICHT abgeschlossen bis Phase 10 completed ist!**

---

## WIP-Commits (nur bei Datei-Output)

**WIP-Commits NUR nach Phasen mit echten Datei-Outputs:**

| Phase | Output | WIP-Commit? |
|-------|--------|-------------|
| 0 | Technical Spec (nur workflow-state) | ❌ Kein Commit |
| 1 | Wireframes (HTML-Dateien) | ✅ Nach User-Approval |
| 2 | API Design (nur workflow-state) | ❌ Kein Commit |
| 3 | Database Migrations (SQL-Dateien) | ✅ Nach Phase-Abschluss |
| 4 | Backend (Java + Tests) | ✅ Nach Test-Gate PASS |
| 5 | Frontend (Angular + Tests) | ✅ Nach Test-Gate PASS |
| 6 | E2E-Tests (Playwright Tests) | ✅ Nach QA-Approval |
| 7 | Code Review (nur Report) | ❌ Kein Commit |

**Reihenfolge bei Phasen mit User-Approval (1, 6):**
1. Phase abschließen
2. ⛔ AskUserQuestion → "Ist [Phase X Ergebnis] akzeptiert?"
3. Bei "Ja" → WIP-Commit
4. Bei "Nein" → Änderungen durchführen, dann erneut fragen

**Commit-Format:**
```bash
git add -A && git commit -m "wip(#<issue>/phase-<nr> - <name>): <Beschreibung> - <Issue-Titel>"
```

**Beispiele:**
```
wip(#110/phase-1 - Wireframes): Desktop/Mobile Navigation erstellt - Navigation Konzept
wip(#110/phase-5 - Frontend): Shell-Layout implementiert - Navigation Konzept
```

**Phase 8+9:** Kein Commit - nur Push, PR, Merge.
