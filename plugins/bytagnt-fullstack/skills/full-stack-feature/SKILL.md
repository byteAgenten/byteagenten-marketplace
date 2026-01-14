---
name: full-stack-feature
description: Orchestrates full-stack feature development with approval gates and agent delegation.
version: 2.4.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**When to use:** GitHub Issues, neue Features, Bugfixes die mehrere Layer betreffen (DB → Backend → Frontend).

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

## ⛔ CRITICAL: Befolge CLAUDE.md Constraints 1-8!

| # | Constraint | Kurzfassung |
|---|------------|-------------|
| 1 | Kein main commit | Feature-Branch Pflicht |
| 2 | Commit Approval | Vor Push/PR/Merge User fragen (WIP-Commits siehe #4) |
| 3 | Merge-Strategie | `--merge` (kein squash/rebase) |
| 4 | WIP-Commits | Phase 3,4,5: Automatisch nach Gate. Phase 1,6: Nach User-Approval |
| 5 | Hotfix-Loop | Änderungen → zurück zur passenden Phase |
| 6 | Agent Delegation | Code NUR über Agents ändern! |
| 7 | Context7 | IMMER für Library/Framework-Syntax nutzen |
| 8 | E2E-Tests | Testcontainers: Backend :8081, Frontend :4201 |

**Phasen-Commits:** Siehe GATES-Tabelle oben (WIP-Commit Spalte). Phase 8+9 nur Push + PR + Merge.

---

## Agent Mapping (Constraint #6)

| Phase | Agent | Aufgabe | Reihenfolge |
|-------|-------|---------|-------------|
| 0 | `byteagent:architect-planner` | Technical Spec erstellen | |
| 1 | `byteagent:ui-ux-designer` | Wireframes (mit Tech Spec Input) | |
| 2 | `byteagent:api-architect` | API-Skizze (workflow-state) | |
| 3 | `byteagent:postgresql-architect` | Migrations | |
| 4 | `byteagent:spring-boot-developer` | Java + Tests | |
| 5 | `byteagent:angular-frontend-developer` | Angular + Tests | |
| 6.1 | `byteagent:test-engineer` | E2E-Tests | 1️⃣ ZUERST |
| 6.2 | `byteagent:security-auditor` | Security-Audit | 2️⃣ DANACH |
| 7 | `byteagent:code-reviewer` | Review + Hotfix | |
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

## Startup-Logik (Kein Argument)

**Ohne Argument:**
1. `workflow-state.json` aktiv? → Resume anbieten
2. Kein aktiver Workflow? → Fragen: "Was möchtest du implementieren?"

**WICHTIG:** Keine AskUserQuestion! Einfach auf Eingabe warten (`#42` oder Beschreibung).

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
    "agent": "byteagent:postgresql-architect"
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

**Bei Skill-Start:** State prüfen → Resume anbieten falls vorhanden

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
