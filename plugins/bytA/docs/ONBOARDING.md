# bytA Plugin — Onboarding-Dokumentation

**Zielgruppe:** Neue Entwickler, die verstehen wollen, wie bytA funktioniert.

---

## Inhaltsverzeichnis

1. [Was ist bytA?](#1-was-ist-byta)
2. [Die drei Architekturprinzipien](#2-die-drei-architekturprinzipien)
3. [Verzeichnisstruktur](#3-verzeichnisstruktur)
4. [Die Akteure und ihre Dateien](#4-die-akteure-und-ihre-dateien)
5. [Die 10 Phasen im Detail](#5-die-10-phasen-im-detail)
6. [Die Hooks im Detail](#6-die-hooks-im-detail)
7. [Die Scripts im Detail](#7-die-scripts-im-detail)
8. [Der Datenfluss: Wie Kontext in die Agenten kommt](#8-der-datenfluss-wie-kontext-in-die-agenten-kommt)
9. [Der Workflow-State (`workflow-state.json`)](#9-der-workflow-state-workflow-statejson)
10. [Lebenszyklus eines Workflow-Durchlaufs](#10-lebenszyklus-eines-workflow-durchlaufs)
11. [Approval Gates und User-Interaktion](#11-approval-gates-und-user-interaktion)
12. [Rollback-Mechanismus](#12-rollback-mechanismus)
13. [Fehlerbehandlung und Ralph-Loop-Retries](#13-fehlerbehandlung-und-ralph-loop-retries)
14. [Session Recovery nach Context Overflow](#14-session-recovery-nach-context-overflow)
15. [Escape Commands](#15-escape-commands)
16. [Unterschied zu byt8](#16-unterschied-zu-byt8)
17. [Quellen](#17-quellen)

---

## 1. Was ist bytA?

bytA ist ein Claude Code Plugin, das einen **deterministischen 10-Phasen-Workflow** fuer Full-Stack Feature-Entwicklung bereitstellt. Es orchestriert 10 spezialisierte KI-Agenten (Architect, UI-Designer, API-Architect, etc.), um aus einem GitHub-Issue ein komplettes Feature zu bauen: Von der technischen Spezifikation ueber Backend/Frontend-Code bis hin zum Pull Request.

**Der entscheidende Unterschied:** Der Orchestrator ist kein LLM, sondern ein **Bash-Script**. Claude dient nur als Transport-Layer — es fuehrt die Befehle aus, die die Shell-Scripts ihm geben. Alle Workflow-Entscheidungen sind deterministisch.

---

## 2. Die drei Architekturprinzipien

### 2.1 Boomerang (aus Roo Code)

**Kernidee:** Jeder Agent laeuft in **totaler Kontext-Isolation**.

```
┌──────────────────────────────┐    ┌──────────────────────────────┐
│      ORCHESTRATOR            │    │         AGENT                │
│                              │    │                              │
│  Sieht: Dateipfade (2 KB)   │───>│  Startet: Frischer Context   │
│  Sieht NICHT: Spec-Inhalte  │    │  Liest: Specs selbst (Read)  │
│  Sieht NICHT: Code           │    │  Schreibt: Code + Reports    │
│  Sieht NICHT: Test-Output   │    │  Returned: "Done."           │
│                              │<───│                              │
│  Ignoriert Rueckgabewert    │    │  Context wird verworfen      │
└──────────────────────────────┘    └──────────────────────────────┘
```

**Warum?** Wenn der Orchestrator Agent-Outputs lesen wuerde, wuerde sein Context monoton wachsen. Nach 5 Phasen haette er ~300 KB gesehen und wuerde Regeln vergessen ("Context Rot"). Durch Boomerang bleibt der Orchestrator-Context konstant bei ~2.5 KB.

### 2.2 Ralph-Loop (aus Geoffrey Huntley)

**Kernidee:** `while !done; do spawn_agent; verify; done` — mit **externer Verifikation**.

```
┌─────────────────────────────────────────┐
│  RALPH LOOP (pro Phase)                 │
│                                         │
│  1. Agent starten (Boomerang)           │
│  2. Agent arbeitet... fertig.           │
│  3. EXTERN verifizieren:                │
│     → Datei existiert? (ls)             │
│     → JSON-Key gesetzt? (jq)           │
│     → Befehl erfolgreich? (exit code)  │
│  4a. DONE → Naechste Phase             │
│  4b. NOT DONE → Retry (max 3x)        │
│  4c. 3x NOT DONE → Pause (User hilft) │
└─────────────────────────────────────────┘
```

**Warum?** Ein Agent sagt "Ich bin fertig" — aber das LLM kann luegen oder sich irren. Die externe Shell-Pruefung ist vertrauenswuerdig: Entweder die Datei existiert, oder nicht.

### 2.3 Determinismus

**Kernidee:** Alle Workflow-Entscheidungen werden von Shell-Scripts getroffen, nicht vom LLM.

| Entscheidung | Wer trifft sie? | Wie? |
|---|---|---|
| Ist die Phase fertig? | `wf_verify.sh` (Shell) | ls, jq, exit code |
| Welche Phase kommt als naechstes? | `wf_orchestrator.sh` (Shell) | `currentPhase + 1` |
| Welchen Prompt bekommt der Agent? | `wf_prompt_builder.sh` (Shell) | Templates + State |
| Wohin geht ein Rollback? | `wf_orchestrator.sh` (Shell) | Dateipfad-Heuristik |
| Darf gepusht werden? | `guard_git_push.sh` (Shell) | `pushApproved` Flag |

Claude's einzige Aufgabe: `Task(bytA:agent, 'prompt')` ausfuehren, wenn ein Hook es sagt.

---

## 3. Verzeichnisstruktur

```
plugins/bytA/
├── .claude-plugin/
│   └── plugin.json                    # Plugin-Metadaten (Name, Version)
├── .mcp.json                          # MCP Server (Context7, Angular CLI)
├── agents/                            # 10 spezialisierte Agents
│   ├── architect-planner.md           # Phase 0: Technical Specification
│   ├── ui-designer.md                 # Phase 1: Wireframes
│   ├── api-architect.md               # Phase 2: API Design
│   ├── postgresql-architect.md        # Phase 3: Migrations
│   ├── spring-boot-developer.md       # Phase 4: Backend
│   ├── angular-frontend-developer.md  # Phase 5: Frontend
│   ├── test-engineer.md               # Phase 6: Tests
│   ├── security-auditor.md            # Phase 7: Security Audit
│   ├── code-reviewer.md               # Phase 8: Code Review
│   └── architect-reviewer.md          # Eskalation bei Architektur-Concerns
├── commands/
│   └── feature.md                     # /bytA:feature → Einstiegspunkt
├── config/
│   └── phases.conf                    # Deklarative Phase-Definitionen (Single Source of Truth)
├── docs/
│   ├── ONBOARDING.md                  # ← Dieses Dokument
│   └── REFACTORING-PROPOSAL-BOOMERANG-RALPH.md
├── hooks/
│   └── hooks.json                     # Plugin-Level Hooks (4 Stueck)
├── scripts/
│   ├── wf_orchestrator.sh             # Stop Hook: Ralph-Loop Orchestrator
│   ├── wf_verify.sh                   # Externe Done-Verifikation
│   ├── wf_prompt_builder.sh           # Deterministische Agent-Prompts
│   ├── wf_user_prompt.sh              # UserPromptSubmit: Approval Gates
│   ├── wf_cleanup.sh                  # Startup: Workflow aufraeumen
│   ├── guard_git_push.sh              # PreToolUse/Bash: Push Guard
│   ├── block_orchestrator_code_edit.sh # PreToolUse/Edit|Write: Code-Edit-Blocker
│   ├── block_orchestrator_explore.sh  # PreToolUse/Task: Explore-Blocker
│   ├── subagent_done.sh               # SubagentStop: WIP-Commits
│   └── session_recovery.sh            # SessionStart: Context Recovery
├── skills/
│   └── feature/
│       └── SKILL.md                   # Instruktionen an Claude (~170 Zeilen)
└── README.md                          # Plugin-Dokumentation
```

### Laufzeit-Verzeichnis (`.workflow/`)

Wird waehrend eines Workflows im **Projekt-Root** erstellt (nicht im Plugin-Verzeichnis):

```
.workflow/                             # In .gitignore — temporaere Workflow-Daten
├── bytA-session                       # Session-Marker (Skill aktiv?)
├── workflow-state.json                # Zentraler State
├── specs/                             # Agent-Reports als MD-Dateien
│   ├── issue-42-ph00-architect-planner.md
│   ├── issue-42-ph02-api-architect.md
│   ├── issue-42-ph04-spring-boot-developer.md
│   └── ...
├── logs/
│   ├── hooks.log                      # Hook-Aktivitaeten
│   └── transitions.jsonl              # Phase-Transitions (JSON Lines)
└── recovery/                          # (reserviert)
```

---

## 4. Die Akteure und ihre Dateien

### 4.1 Konfigurationsdateien

| Datei | Aufgabe |
|---|---|
| `config/phases.conf` | Definiert alle 10 Phasen: Agent, Typ (APPROVAL/AUTO), Done-Kriterium |
| `hooks/hooks.json` | Registriert welches Script bei welchem Claude-Event feuert |
| `skills/feature/SKILL.md` | Minimale Instruktionen an Claude: "Du bist Transport-Layer" |

### 4.2 Shell-Scripts

| Script | Hook-Typ | Aufgabe |
|---|---|---|
| `wf_orchestrator.sh` | **Stop** | Herzstuck: Verify → Advance/Retry → Agent-Dispatch |
| `wf_verify.sh` | (wird von Orchestrator aufgerufen) | Externe Done-Pruefung (kein LLM!) |
| `wf_prompt_builder.sh` | (wird von Orchestrator aufgerufen) | Baut Agent-Prompts aus State + Templates |
| `wf_user_prompt.sh` | **UserPromptSubmit** | Injiziert Approval-Gate-Kontext in Claudes Sichtfeld |
| `wf_cleanup.sh` | (wird von SKILL.md aufgerufen) | Startup: Alten Workflow aufraeumen |
| `guard_git_push.sh` | **PreToolUse/Bash** | Blockiert Push ohne `pushApproved` Flag |
| `block_orchestrator_code_edit.sh` | **PreToolUse/Edit\|Write** (Skill-Level) | Orchestrator darf keinen Code aendern |
| `block_orchestrator_explore.sh` | **PreToolUse/Task** (Skill-Level) | Orchestrator darf nicht explorieren |
| `subagent_done.sh` | **SubagentStop** | Deterministische WIP-Commits |
| `session_recovery.sh` | **SessionStart** | Context Recovery nach Overflow |

### 4.3 Agenten

Jeder Agent ist in einer `.md`-Datei unter `agents/` definiert. Die Agent-Datei enthaelt:

- **Frontmatter** (YAML): `name`, `tools`, `model`, `color`, `description`
- **Markdown-Body**: Detaillierte Instruktionen, Checklisten, Code-Beispiele

| Agent | Phase | Spezialisierung | Model |
|---|---|---|---|
| `architect-planner` | 0 | Technical Spec, 5x Warum, Architektur | inherit |
| `ui-designer` | 1 | HTML Wireframes, Angular Material | sonnet |
| `api-architect` | 2 | REST API Design (Markdown, kein YAML) | inherit |
| `postgresql-architect` | 3 | Flyway SQL Migrations, Schema | inherit |
| `spring-boot-developer` | 4 | Spring Boot 4 Backend | inherit |
| `angular-frontend-developer` | 5 | Angular 21 Frontend (Signals, Standalone) | inherit |
| `test-engineer` | 6 | E2E + Integration Tests | inherit |
| `security-auditor` | 7 | OWASP Top 10 Audit | inherit |
| `code-reviewer` | 8 | Code Quality Gate | inherit |
| `architect-reviewer` | - | Eskalation bei Architektur-Concerns | inherit |

**Wichtig:** Alle Agenten haben das gleiche **Input Protocol**:

```
1. Du erhaeltst DATEIPFADE zu Spec-Dateien im Prompt
2. LIES alle Spec-Dateien ZUERST mit dem Read-Tool
3. Erst NACH dem Lesen: Beginne mit deiner Aufgabe
```

---

## 5. Die 10 Phasen im Detail

Die Phasen sind in `config/phases.conf` deklarativ definiert. Format:

```
PHASE_NUMMER|AGENT_NAME|PHASE_TYP|DONE_KRITERIUM
```

### Phase 0: Technical Specification (architect-planner)

| Eigenschaft | Wert |
|---|---|
| **Typ** | APPROVAL (User muss approven) |
| **Done-Kriterium** | `GLOB:.workflow/specs/issue-*-ph00-architect-planner.md` |
| **Input** | Issue-Nummer, Issue-Titel, Coverage-Ziel |
| **Output** | Spec-MD-Datei + Pfad in `context.technicalSpec.specFile` |

**Was passiert:**
1. Agent liest das Issue, analysiert die Codebase
2. Fuehrt "5x Warum" Root-Cause-Analyse durch
3. Nutzt MCP-Tools (Context7, Angular CLI) fuer aktuelle Doku
4. Schreibt Technical Specification als `.workflow/specs/issue-42-ph00-architect-planner.md`
5. Speichert den Pfad in `workflow-state.json` unter `context.technicalSpec.specFile`
6. Zeigt Approval Gate: "Spec OK? Soll ich fortfahren?"

**Danach:** User reviewed, gibt Approval oder Feedback. Bei Approval → Phase 1.

### Phase 1: Wireframes (ui-designer)

| Eigenschaft | Wert |
|---|---|
| **Typ** | APPROVAL (User muss approven) |
| **Done-Kriterium** | `GLOB:wireframes/*.html` |
| **Input** | Technical Spec (Dateipfad) |
| **Output** | HTML-Wireframe-Dateien in `wireframes/` |

**Was passiert:**
1. Agent liest die Technical Spec ueber den Dateipfad
2. Erstellt HTML-Wireframes mit Angular Material CSS
3. Alle interaktiven Elemente bekommen `data-testid` (fuer Playwright E2E Tests)
4. Speichert Wireframe-Pfade in `context.wireframes.paths`

**Danach:** User oeffnet HTML im Browser, reviewed, gibt Approval oder Feedback.

### Phase 2: API Design (api-architect)

| Eigenschaft | Wert |
|---|---|
| **Typ** | AUTO (kein User-Approval noetig) |
| **Done-Kriterium** | `GLOB:.workflow/specs/issue-*-ph02-api-architect.md` |
| **Input** | Technical Spec (Dateipfad) |
| **Output** | API-Design-MD-Datei + Pfad in `context.apiDesign.apiDesignFile` |

**Was passiert:**
1. Agent liest Technical Spec
2. Designt REST API Endpoints (Markdown-Sketch, kein vollstaendiges OpenAPI YAML)
3. Speichert in `.workflow/specs/issue-42-ph02-api-architect.md`

**Danach:** Auto-Advance zu Phase 3 (wf_orchestrator.sh prueft Datei, findet sie, weiter).

### Phase 3: Database Migrations (postgresql-architect)

| Eigenschaft | Wert |
|---|---|
| **Typ** | AUTO |
| **Done-Kriterium** | `GLOB:backend/src/main/resources/db/migration/V*.sql` |
| **Input** | Technical Spec + API Design (Dateipfade) |
| **Output** | Flyway SQL-Migrationsdateien |

**Was passiert:**
1. Agent liest Technical Spec und API Design
2. Erstellt Flyway-kompatible SQL-Migrations (`V001__create_xyz.sql`)
3. Schema-Normalisierung (3NF), Indexes, Constraints

**Danach:** Auto-Advance zu Phase 4.

### Phase 4: Backend Implementation (spring-boot-developer)

| Eigenschaft | Wert |
|---|---|
| **Typ** | AUTO |
| **Done-Kriterium** | `GLOB:.workflow/specs/issue-*-ph04-spring-boot-developer.md` |
| **Input** | Technical Spec + API Design + Database Design (Dateipfade) |
| **Output** | Java-Code (Controller, Service, Repository) + Report-MD |

**Was passiert:**
1. Agent liest alle drei vorherigen Specs
2. Implementiert Spring Boot 4 REST Controller, Services, Repositories
3. Fuegt Swagger/OpenAPI-Annotationen hinzu
4. Fuehrt `mvn verify` aus
5. Nutzt Context7 MCP fuer aktuelle Spring Boot Doku
6. Schreibt Report-MD und speichert Pfad in `context.backendImpl.specFile`

**Danach:** SubagentStop Hook macht WIP-Commit. Auto-Advance zu Phase 5.

### Phase 5: Frontend Implementation (angular-frontend-developer)

| Eigenschaft | Wert |
|---|---|
| **Typ** | AUTO |
| **Done-Kriterium** | `GLOB:.workflow/specs/issue-*-ph05-angular-frontend-developer.md` |
| **Input** | Technical Spec + API Design + Wireframes (Dateipfade) |
| **Output** | TypeScript/HTML/SCSS-Code + Report-MD |

**Was passiert:**
1. Agent liest Specs und Wireframes
2. Implementiert Angular 21+ Components (Signals, Standalone, inject())
3. Alle interaktiven Elemente bekommen `data-testid`
4. Fuehrt `npm test` aus
5. Nutzt Context7 + Angular CLI MCP fuer aktuelle Doku
6. Schreibt Report-MD und speichert Pfad in `context.frontendImpl.specFile`

**Danach:** WIP-Commit. Auto-Advance zu Phase 6.

### Phase 6: E2E und Integration Tests (test-engineer)

| Eigenschaft | Wert |
|---|---|
| **Typ** | AUTO |
| **Done-Kriterium** | `STATE:context.testResults.allPassed==true` |
| **Input** | Technical Spec + optionale Backend/Frontend Reports (Dateipfade) |
| **Output** | Tests + `context.testResults.allPassed = true` in State |

**Was passiert:**
1. Agent liest Specs
2. Schreibt JUnit 5 + Mockito (Backend), Jasmine + TestBed (Frontend), Playwright E2E
3. Fuehrt `mvn verify` + `npm test` + `npx playwright test` aus
4. Setzt `context.testResults.allPassed = true` NUR wenn ALLE Tests gruen sind

**Wichtig:** Das Done-Kriterium ist KEIN Datei-Check, sondern ein **Wert-Check**: `allPassed == true`. Der Agent kann den Key nicht einfach setzen ohne Tests auszufuehren — `wf_verify.sh` prueft den **Wert**, nicht nur die Existenz.

**Danach:** WIP-Commit. Auto-Advance zu Phase 7.

### Phase 7: Security Audit (security-auditor)

| Eigenschaft | Wert |
|---|---|
| **Typ** | APPROVAL |
| **Done-Kriterium** | `GLOB:.workflow/specs/issue-*-ph07-security-auditor.md` |
| **Input** | Technical Spec + optionale Backend/Frontend Reports (Dateipfade) |
| **Output** | Security-Audit-Report-MD |

**Was passiert:**
1. Agent prueft OWASP Top 10 (A01-A10)
2. Scannt Backend (SQL Injection, Auth, CSRF, etc.)
3. Scannt Frontend (XSS, unsichere Storage, etc.)
4. Schreibt Audit-Report mit Severity-Levels

**Danach:** User reviewed Security-Findings. Bei Problemen: Rollback zu Phase 4/5/6.

### Phase 8: Code Review (code-reviewer)

| Eigenschaft | Wert |
|---|---|
| **Typ** | APPROVAL |
| **Done-Kriterium** | `STATE:context.reviewFeedback.userApproved==true` |
| **Input** | Alle verfuegbaren Spec-Pfade + Coverage-Ziel |
| **Output** | Review-Report-MD + `context.reviewFeedback` in State |

**Was passiert:**
1. Agent liest alle Specs
2. Prueft: SOLID, DRY, KISS, Coverage, Security, Performance
3. Fuehrt `mvn verify` + `npm test` + `npm run build` aus (Build Gate)
4. Setzt `context.reviewFeedback.status` auf APPROVED oder CHANGES_REQUESTED
5. Bei CHANGES_REQUESTED: `fixes[]` Array mit betroffenen Dateien + Typ

**Danach:** User approved oder gibt Feedback. Bei CHANGES_REQUESTED → Rollback.

### Phase 9: Push & PR (Orchestrator direkt)

| Eigenschaft | Wert |
|---|---|
| **Typ** | APPROVAL |
| **Done-Kriterium** | `STATE:phases["9"].prUrl` |
| **Input** | (kein Agent — Orchestrator/Claude fuehrt direkt aus) |
| **Output** | Git Push + PR URL in State |

**Was passiert:**
1. Pre-Push Build Gate: `mvn verify` + `npm test` + `npm run build`
2. User bestaetigt: "PR erstellen? Ziel-Branch?"
3. `pushApproved = true` in State setzen (Guard-Script gibt frei)
4. `git push -u origin branch`
5. `gh pr create --base target --title "feat(#N): Title"`
6. `status = "completed"` in State

---

## 6. Die Hooks im Detail

Hooks sind Event-Handler in Claude Code. Wenn ein bestimmtes Event eintritt, fuehrt Claude automatisch ein Shell-Script aus. bytA definiert Hooks auf zwei Ebenen:

### 6.1 Plugin-Level Hooks (`hooks/hooks.json`)

Diese feuern **immer**, egal ob der Skill aktiv ist oder nicht.

| Hook-Event | Script | Wann feuert es? |
|---|---|---|
| **Stop** | `wf_orchestrator.sh` | Wenn Claude "fertig" sein will (aufhoeren moechte) |
| **UserPromptSubmit** | `wf_user_prompt.sh` | Wenn der User eine Nachricht sendet |
| **PreToolUse/Bash** | `guard_git_push.sh` | Bevor Claude einen Bash-Befehl ausfuehrt |
| **SubagentStop** | `subagent_done.sh` | Wenn ein Subagent fertig ist |
| **SessionStart** | `session_recovery.sh` | Wenn eine neue Claude-Session startet |

### 6.2 Skill-Level Hooks (SKILL.md Frontmatter)

Diese feuern **nur**, wenn der Skill aktiv ist (d.h. `/bytA:feature` wurde aufgerufen).

| Hook-Event | Script | Wann feuert es? |
|---|---|---|
| **PreToolUse/Edit\|Write** | `block_orchestrator_code_edit.sh` | Bevor Claude eine Datei editiert/schreibt |
| **PreToolUse/Task** | `block_orchestrator_explore.sh` | Bevor Claude einen Subagent startet |

### 6.3 Hook-Output-Kanaele

Hooks kommunizieren ueber drei Kanaele:

| Kanal | Mechanismus | Wer sieht es? |
|---|---|---|
| **stdout (JSON)** | `{"decision":"block","reason":"..."}` | Claude sieht `reason` und MUSS weitermachen |
| **stdout (Text)** | Freitext (kein JSON) | Claude sieht den Text als Kontext |
| **stderr** | Fehlermeldungen | Claude sieht die Fehlermeldung |
| **exit code** | 0 = OK, 2 = blockiert | Claude reagiert auf den Exit Code |

**`decision:block` ist der Schluessel:** Wenn der Stop Hook `{"decision":"block","reason":"Starte Task(...)"}` ausgibt, kann Claude NICHT stoppen. Es MUSS die Aktion in `reason` ausfuehren. So erzwingt der Shell-Orchestrator das LLM-Verhalten.

---

## 7. Die Scripts im Detail

### 7.1 `wf_orchestrator.sh` — Das Herzstuck (Stop Hook)

**Datei:** `scripts/wf_orchestrator.sh` (~457 Zeilen)
**Feuert:** Bei jedem Stop-Event (Claude moechte aufhoeren)

**Ablauf:**

```
1. Session-Marker pruefen (.workflow/bytA-session)
   └── Existiert, aber kein State? → BLOCK: "Startup unvollstaendig"
   └── Beides fehlt? → exit 0 (nichts zu tun)

2. Loop-Prevention pruefen (stopHookBlockCount >= 15?)
   └── Ja → Workflow pausieren, exit 0

3. Status pruefen
   └── completed → exit 0 (Session-Marker entfernen, Sound)
   └── paused/idle → exit 0
   └── awaiting_approval → exit 0
   └── active → weiter zu Schritt 4

4. Phase-Skip-Guard (detect_skipped_phase)
   └── Fehlende Vorgaenger-Phase? → currentPhase korrigieren, Agent starten

5. VERIFY: wf_verify.sh aufrufen
   └── DONE + APPROVAL → status = "awaiting_approval", exit 0 (Sound)
   └── DONE + AUTO → currentPhase++, wf_prompt_builder.sh, output_block()
   └── NOT DONE → weiter zu Schritt 6

6. Phase 8 Spezial: CHANGES_REQUESTED?
   └── Ja → Rollback-Ziel bestimmen, Context aufraeumen, Agent starten

7. RALPH LOOP: Retry-Counter pruefen
   └── >= MAX_RETRIES → Workflow pausieren
   └── < MAX_RETRIES → increment_retry, wf_prompt_builder.sh, output_block()
```

**Wichtige Funktionen im Script:**

| Funktion | Was sie tut |
|---|---|
| `output_block(reason)` | Gibt JSON `{"decision":"block","reason":"..."}` aus. Inkrementiert Block-Counter. |
| `mark_phase_completed(phase)` | Setzt `phases[N].status = "completed"` mit Timestamp |
| `create_wip_commit(phase)` | `git add -A && git commit -m "wip(#N/phase-X): ..."` |
| `get_retry_count(phase)` | Liest `recovery.phase_N_attempts` aus State |
| `increment_retry(phase)` | Zaehlt hoch, gibt neuen Wert zurueck |
| `reset_retry(phase)` | Loescht den Retry-Counter |
| `detect_skipped_phase(current)` | Prueft ob alle Vorgaenger-Phasen Context haben |
| `play_notification()` | Spielt Sound bei Approval Gates / Pausen |
| `play_completion()` | Spielt Sound bei Workflow-Abschluss |

### 7.2 `wf_verify.sh` — Externe Done-Verifikation

**Datei:** `scripts/wf_verify.sh` (~87 Zeilen)
**Aufgerufen von:** `wf_orchestrator.sh`

**Aufgabe:** Prueft ob eine Phase "fertig" ist. **Kein LLM beteiligt.**

**Ablauf:**

```
1. Phase-Status in State pruefen (bereits completed/skipped?)
   └── Ja → exit 0 (done)

2. Done-Criterion aus phases.conf lesen
   └── Leer? → exit 1 (not done)

3. Criterion-Typ erkennen und ausfuehren:

   STATE:context.testResults.allPassed==true
   └── jq -e ".context.testResults.allPassed == true" workflow-state.json
   └── exit 0 bei Treffer, exit 1 sonst

   GLOB:.workflow/specs/issue-*-ph04-*.md
   └── ls .workflow/specs/issue-*-ph04-*.md
   └── exit 0 wenn Datei existiert, exit 1 sonst

   VERIFY:mvn verify
   └── eval "mvn verify"
   └── exit 0 bei exit code 0, exit 1 sonst

   PHASE_STATUS
   └── Nur phases[N].status (bereits oben geprueft)
```

**Done-Kriterien pro Phase (aus `phases.conf`):**

| Phase | Criterion | Typ | Was wird geprueft |
|---|---|---|---|
| 0 | `GLOB:.workflow/specs/issue-*-ph00-architect-planner.md` | Datei | Spec existiert? |
| 1 | `GLOB:wireframes/*.html` | Datei | Wireframe existiert? |
| 2 | `GLOB:.workflow/specs/issue-*-ph02-api-architect.md` | Datei | API-Spec existiert? |
| 3 | `GLOB:backend/src/main/resources/db/migration/V*.sql` | Datei | Migration existiert? |
| 4 | `GLOB:.workflow/specs/issue-*-ph04-spring-boot-developer.md` | Datei | Backend-Report existiert? |
| 5 | `GLOB:.workflow/specs/issue-*-ph05-angular-frontend-developer.md` | Datei | Frontend-Report existiert? |
| 6 | `STATE:context.testResults.allPassed==true` | JSON-Wert | Tests alle gruen? |
| 7 | `GLOB:.workflow/specs/issue-*-ph07-security-auditor.md` | Datei | Audit-Report existiert? |
| 8 | `STATE:context.reviewFeedback.userApproved==true` | JSON-Wert | User hat approved? |
| 9 | `STATE:phases["9"].prUrl` | JSON-Key | PR URL vorhanden? |

### 7.3 `wf_prompt_builder.sh` — Deterministische Agent-Prompts

**Datei:** `scripts/wf_prompt_builder.sh` (~281 Zeilen)
**Aufgerufen von:** `wf_orchestrator.sh`
**Aufruf:** `wf_prompt_builder.sh <phase_number> [hotfix_feedback]`

**Aufgabe:** Baut den Prompt-Text, den ein Agent bekommt, deterministisch aus dem Workflow-State zusammen. **Kein LLM beteiligt.**

**Ablauf:**

```
1. phases.conf laden (fuer Phase-Namen, Kriterien)

2. State lesen:
   - Issue-Nr, Titel, Coverage-Ziel (Metadaten direkt im Prompt)
   - Spec-Pfade: technicalSpec, apiDesign, migrations, wireframes,
     backendImpl, frontendImpl, testReport, securityReport
     (NUR PFADE — nie den Datei-Inhalt!)

3. Optionale Sektionen:
   - HOTFIX_SECTION (wenn 2. Argument uebergeben)
   - RETRY_SECTION (wenn retry_count > 0 und kein Hotfix)

4. Phase-spezifisches Template (case $PHASE):
   - Aufgabenbeschreibung
   - Liste der SPEC FILES mit Pfaden
   - Workflow-Metadaten (Issue, Coverage)

5. ACCEPTANCE CRITERIA + RETURN PROTOCOL (automatisch angehaengt):
   - Menschenlesbare Version des Done-Kriteriums aus phases.conf
   - "Your last message MUST be exactly: Done."
```

**Welche Specs bekommt welcher Agent? (Dependency Map)**

| Phase | Bekommt diese Spec-Pfade |
|---|---|
| 0 (Tech Spec) | Keine (erste Phase) |
| 1 (Wireframes) | `technicalSpec.specFile` |
| 2 (API Design) | `technicalSpec.specFile` |
| 3 (Migrations) | `technicalSpec.specFile` + `apiDesign.apiDesignFile` |
| 4 (Backend) | `technicalSpec.specFile` + `apiDesign.apiDesignFile` + `migrations.databaseFile` |
| 5 (Frontend) | `technicalSpec.specFile` + `apiDesign.apiDesignFile` + `wireframes.paths` |
| 6 (Tests) | `technicalSpec.specFile` + optionale Backend/Frontend-Reports |
| 7 (Security) | `technicalSpec.specFile` + optionale Backend/Frontend-Reports |
| 8 (Review) | Alle verfuegbaren Spec-Pfade + Test/Security-Reports |

**Beispiel-Output fuer Phase 4:**

```
Phase 4: Implement Backend for Issue #42: User Dashboard

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: .workflow/specs/issue-42-ph00-architect-planner.md
- API Design: .workflow/specs/issue-42-ph02-api-architect.md
- Database Design: .workflow/specs/issue-42-ph03-postgresql-architect.md

## WORKFLOW CONTEXT
- Issue: #42 - User Dashboard
- Target Coverage: 70%

## YOUR TASK
Implement Spring Boot 4 REST controllers, services, repositories. Add Swagger annotations.
Run mvn verify before completing. MANDATORY: Load current docs via Context7 BEFORE coding.

## ACCEPTANCE CRITERIA (auto-generated from phases.conf)
Your work is verified EXTERNALLY. You are done when:
  File must exist: .workflow/specs/issue-*-ph04-spring-boot-developer.md
This is checked automatically. If this criterion is not met, you will be re-spawned.

## RETURN PROTOCOL
Your last message MUST be exactly: Done.
The orchestrator does NOT read your summary — it verifies externally.
```

### 7.4 `wf_user_prompt.sh` — Approval Gate Context Injection

**Datei:** `scripts/wf_user_prompt.sh` (~219 Zeilen)
**Feuert:** Bei jedem User-Prompt (UserPromptSubmit Event)

**Aufgabe:** Wenn der User auf eine Approval-Frage antwortet, injiziert dieses Script die passenden Anweisungen in Claudes Sichtfeld.

**Ablauf:**

```
1. Kein Workflow? → exit 0 (nichts tun)
2. Status completed/idle? → exit 0

3. stopHookBlockCount zuruecksetzen (Loop-Prevention Reset)

4. Status-basierte Injection:

   paused → "WORKFLOW PAUSIERT | Optionen: resume/retry-reset/skip"

   awaiting_approval → Phase-spezifische Anweisungen:
     Phase 0: "BEI APPROVAL: Phase 1 starten. BEI FEEDBACK: architect-planner erneut."
     Phase 1: "BEI APPROVAL: Phase 2 starten (Auto-Advance bis Phase 7). BEI FEEDBACK: ui-designer erneut."
     Phase 7: "BEI APPROVAL: Phase 8 starten. BEI SECURITY-FIXES: Rollback."
     Phase 8: "BEI APPROVAL: Phase 9. BEI FEEDBACK: Rollback mit Option C Heuristik."
     Phase 9: "BEI APPROVAL: Push + PR. Pre-Push Build Gate PFLICHT!"

   active → "Workflow laeuft. Bei Phase-Aktionen: lies workflow-state.json."
```

**Wichtig:** Die Anweisungen enthalten exakte `jq`-Befehle und `Task()`-Aufrufe. Claude muss sie **woertlich** befolgen — es interpretiert nichts selbst.

### 7.5 `wf_cleanup.sh` — Startup-Check

**Datei:** `scripts/wf_cleanup.sh` (~43 Zeilen)

| Exit Code | Bedeutung | Aktion |
|---|---|---|
| 0 | Kein Workflow oder completed → aufgeraeumt | Weiter mit Initialisierung |
| 1 | Aktiver Workflow gefunden | STOPP! User entscheidet (resume oder verwerfen) |

### 7.6 `guard_git_push.sh` — Push Guard

**Datei:** `scripts/guard_git_push.sh` (~48 Zeilen)

Prueft bei jedem `Bash`-Aufruf ob der Befehl `git push` oder `gh pr create` enthaelt.
Blockiert (exit 2) wenn:
- Aktiver Workflow existiert UND
- `pushApproved != true` in State

Erlaubt wenn:
- Kein Workflow vorhanden
- Status completed/idle
- `pushApproved = true` (Phase 9)

### 7.7 `block_orchestrator_code_edit.sh` — Code-Edit-Blocker

**Datei:** `scripts/block_orchestrator_code_edit.sh` (~34 Zeilen)

**Skill-scoped:** Feuert NUR fuer den Orchestrator (Claude im Skill-Kontext), NICHT fuer Subagents.

Erlaubt: `.json`, `.md`, `.yml`, `.yaml`, `.sh`, `.gitignore`, `.txt`
Blockiert: Alles andere (`.java`, `.ts`, `.html`, `.scss`, `.sql`, `.xml`, etc.)

**Warum?** Der Orchestrator soll keinen Code schreiben — das ist Aufgabe der Agenten.

### 7.8 `block_orchestrator_explore.sh` — Explore-Blocker

**Datei:** `scripts/block_orchestrator_explore.sh` (~41 Zeilen)

**Skill-scoped:** Feuert NUR fuer den Orchestrator.

Erlaubt: `bytA:*` Agents (spezialisierte Phase-Agents)
Blockiert: `Explore`, `general-purpose`

**Warum?** Der Orchestrator soll nicht herumforschen — er soll Agents dispatchen.

### 7.9 `subagent_done.sh` — WIP-Commits

**Datei:** `scripts/subagent_done.sh` (~58 Zeilen)
**Feuert:** Wenn ein Subagent fertig ist (SubagentStop Event)

Erstellt automatische WIP-Commits fuer Code-produzierende Phasen (1, 3, 4, 5, 6):

```
wip(#42/phase-4): Backend - User Dashboard
```

**Warum nur bestimmte Phasen?** Phase 0 und 2 schreiben nur Specs in `.workflow/` (gitignored). Phase 7 und 8 schreiben keinen Code.

### 7.10 `session_recovery.sh` — Context Recovery

**Datei:** `scripts/session_recovery.sh` (~76 Zeilen)
**Feuert:** Bei Session-Start (z.B. nach Context Overflow)

Gibt einen minimalen Recovery-Prompt aus:

```
WORKFLOW RECOVERY nach Context Overflow
  Issue:  #42 - User Dashboard
  Phase:  4 (Backend)
  Status: active
  PFLICHT-AKTION: Rufe /bytA:feature auf!
```

**Warum so minimal?** Der Ralph-Loop hat den State auf Disk. Sobald der Skill neu geladen wird, uebernehmen die Hooks die Steuerung automatisch.

---

## 8. Der Datenfluss: Wie Kontext in die Agenten kommt

### 8.1 Das Gesamtbild

```
                         phases.conf
                            │
                            │ (Phase-Definitionen)
                            ▼
User ──> /bytA:feature ──> SKILL.md ──> Claude (Transport-Layer)
                                            │
                            ┌───────────────┤
                            │               │
                            ▼               ▼
                    wf_orchestrator.sh   wf_user_prompt.sh
                    (Stop Hook)          (UserPromptSubmit)
                            │
                            ├── wf_verify.sh (DONE?)
                            │
                            └── wf_prompt_builder.sh
                                    │
                                    │ (Prompt-Text auf stdout)
                                    ▼
                            output_block(reason)
                                    │
                                    │ {"decision":"block","reason":"...Task(bytA:agent, 'PROMPT')..."}
                                    ▼
                            Claude fuehrt Task() aus
                                    │
                    ┌───────────────┤
                    │               │
                    ▼               ▼
              Agent liest        Agent schreibt
              Specs (Read)       Code + Reports
                    │               │
                    │               ▼
                    │         .workflow/specs/issue-42-phXX-agent.md
                    │         workflow-state.json (Pfade updaten)
                    │               │
                    ▼               ▼
              Agent: "Done."   subagent_done.sh (WIP-Commit)
                                    │
                                    ▼
                            wf_orchestrator.sh (Stop Hook feuert erneut)
                                    │
                                    └── wf_verify.sh → DONE? → naechste Phase...
```

### 8.2 Der Kontext-Fluss in 6 Schritten

**Schritt 1: Workflow-State existiert auf Disk**

```json
{
  "currentPhase": 4,
  "issue": { "number": 42, "title": "User Dashboard" },
  "targetCoverage": 70,
  "context": {
    "technicalSpec": { "specFile": ".workflow/specs/issue-42-ph00-architect-planner.md" },
    "apiDesign": { "apiDesignFile": ".workflow/specs/issue-42-ph02-api-architect.md" },
    "migrations": { "databaseFile": ".workflow/specs/issue-42-ph03-postgresql-architect.md" }
  }
}
```

**Schritt 2: Stop Hook feuert, ruft `wf_prompt_builder.sh 4` auf**

Das Script liest NUR die Pfade aus dem State (nicht den Inhalt der Spec-Dateien!).

**Schritt 3: Prompt-Text wird gebaut**

```
Phase 4: Implement Backend for Issue #42: User Dashboard

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: .workflow/specs/issue-42-ph00-architect-planner.md
- API Design: .workflow/specs/issue-42-ph02-api-architect.md
- Database Design: .workflow/specs/issue-42-ph03-postgresql-architect.md
...
```

**Schritt 4: Orchestrator gibt `decision:block` aus**

```json
{"decision":"block","reason":"Phase 3 DONE. Auto-Advance zu Phase 4. Starte sofort: Task(bytA:spring-boot-developer, 'Phase 4: Implement Backend...')"}
```

**Schritt 5: Claude fuehrt `Task(bytA:spring-boot-developer, '...')` aus**

Der Agent startet mit **frischem Context** (Boomerang). Er:
1. Liest die genannten Spec-Dateien selbst mit dem Read-Tool
2. Schreibt Java-Code
3. Schreibt seinen Report als `.workflow/specs/issue-42-ph04-spring-boot-developer.md`
4. Updatet `workflow-state.json`: `context.backendImpl.specFile = "..."`
5. Gibt "Done." zurueck

**Schritt 6: Stop Hook verifiziert extern**

```bash
wf_verify.sh 4
# → ls .workflow/specs/issue-*-ph04-spring-boot-developer.md
# → Datei existiert → exit 0 → DONE
```

Weiter mit Phase 5 (Auto-Advance).

### 8.3 Warum NUR Pfade und nicht Inhalte?

| Ansatz | Orchestrator-Context | Nach 8 Phasen |
|---|---|---|
| Inhalte uebergeben | Waechst pro Phase (~30-50 KB) | ~300 KB → Context Rot |
| Nur Pfade uebergeben | Konstant (~2.5 KB) | ~2.5 KB → kein Context Rot |

Der Orchestrator sieht nie den Inhalt einer Spec-Datei. Er kennt nur den **Pfad**. Der Agent liest den Inhalt selbst, in seinem eigenen isolierten Context.

---

## 9. Der Workflow-State (`workflow-state.json`)

### 9.1 Struktur

```json
{
  "workflow": "bytA-feature",
  "status": "active",
  "issue": {
    "number": 42,
    "title": "User Dashboard",
    "url": "https://github.com/org/repo/issues/42"
  },
  "branch": "feature/issue-42-user-dashboard",
  "fromBranch": "develop",
  "targetCoverage": 70,
  "currentPhase": 4,
  "startedAt": "2026-02-07T10:00:00Z",
  "phases": {
    "0": { "name": "Tech Spec", "status": "completed", "completedAt": "..." },
    "1": { "name": "Wireframes", "status": "completed", "completedAt": "..." },
    "2": { "name": "API Design", "status": "completed", "completedAt": "..." },
    "3": { "name": "Migrations", "status": "completed", "completedAt": "..." }
  },
  "context": {
    "technicalSpec": { "specFile": ".workflow/specs/issue-42-ph00-architect-planner.md" },
    "wireframes": { "paths": ["wireframes/dashboard.html"] },
    "apiDesign": { "apiDesignFile": ".workflow/specs/issue-42-ph02-api-architect.md" },
    "migrations": { "databaseFile": ".workflow/specs/issue-42-ph03-postgresql-architect.md" }
  },
  "recovery": {
    "phase_4_attempts": 1
  },
  "stopHookBlockCount": 0,
  "pushApproved": false
}
```

### 9.2 Status-Werte

| Status | Bedeutung | Wer setzt ihn? |
|---|---|---|
| `active` | Workflow laeuft | Scripts (Orchestrator, User-Prompt) |
| `awaiting_approval` | User muss approven | `wf_orchestrator.sh` (bei APPROVAL-Phasen) |
| `paused` | Workflow pausiert (Problem) | `wf_orchestrator.sh` (bei Max Retries / Loop) |
| `completed` | Workflow fertig | SKILL.md / `wf_orchestrator.sh` |
| `idle` | Workflow initialisiert aber noch nicht gestartet | - |

### 9.3 Wer schreibt was?

| Feld | Geschrieben von | Gelesen von |
|---|---|---|
| `status` | Scripts (Orchestrator, User-Prompt) | Alle Scripts |
| `currentPhase` | `wf_orchestrator.sh` | Alle Scripts |
| `phases[N]` | `wf_orchestrator.sh` (mark_phase_completed) | `wf_verify.sh`, `wf_orchestrator.sh` |
| `context.*` | Agents (jq-Befehle am Ende ihres Runs) | `wf_prompt_builder.sh` |
| `recovery.*` | `wf_orchestrator.sh` (increment/reset_retry) | `wf_orchestrator.sh`, `wf_prompt_builder.sh` |
| `stopHookBlockCount` | `wf_orchestrator.sh` (output_block) | `wf_orchestrator.sh` (Loop-Prevention) |
| `pushApproved` | Claude (laut UserPromptSubmit-Anweisung) | `guard_git_push.sh` |

---

## 10. Lebenszyklus eines Workflow-Durchlaufs

### Schritt-fuer-Schritt: Von Issue zu Pull Request

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. USER: /bytA:feature #42                                              │
│    → SKILL.md wird geladen                                              │
│    → Claude ist jetzt "Transport-Layer"                                 │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 2. STARTUP (SKILL.md Anweisungen)                                       │
│    a) mkdir -p .workflow && echo "$(date)" > .workflow/bytA-session      │
│    b) wf_cleanup.sh → OK oder BLOCKED                                   │
│    c) User fragen: Branch? Coverage-Ziel?                               │
│    d) workflow-state.json erstellen                                     │
│    e) git checkout -b feature/issue-42-...                              │
│    f) Task(bytA:architect-planner, 'Phase 0...')                        │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 3. PHASE 0 (architect-planner)                                          │
│    Agent arbeitet... schreibt Spec + updatet State                      │
│    SubagentStop → (kein WIP-Commit fuer Phase 0)                        │
│    Stop Hook → wf_verify.sh → Spec existiert? → JA                     │
│    → APPROVAL-Phase → status = "awaiting_approval"                      │
│    → Claude stoppt, Sound spielt                                        │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 4. USER REVIEWED SPEC → "OK, weiter"                                    │
│    UserPromptSubmit Hook → wf_user_prompt.sh                            │
│    → Injiziert: "BEI APPROVAL: Phase 1 starten"                        │
│    → Claude setzt status=active, currentPhase=1                         │
│    → Task(bytA:ui-designer, 'Phase 1...')                               │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 5. PHASE 1 (ui-designer) → APPROVAL                                    │
│    (gleicher Ablauf wie Phase 0, mit Wireframe-Files als Kriterium)     │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 6. USER APPROVED WIREFRAMES → Auto-Advance Kette startet               │
│                                                                          │
│    Phase 2 (api-architect) ──AUTO──> Phase 3 (postgresql-architect)     │
│       ──AUTO──> Phase 4 (spring-boot-developer) ──AUTO──>              │
│    Phase 5 (angular-frontend-developer) ──AUTO──>                       │
│    Phase 6 (test-engineer)                                              │
│                                                                          │
│    Jede Phase: Agent → SubagentStop (WIP-Commit) → Stop Hook           │
│                → wf_verify.sh → DONE → Auto-Advance → naechster Agent   │
│                                                                          │
│    Der User sieht: Phasen rauschen automatisch durch (5 Phasen).       │
│    Pro Phase: ~2-15 Minuten (je nach Komplexitaet).                    │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 7. PHASE 7 (security-auditor) → APPROVAL                               │
│    User reviewed Security-Findings                                      │
│    → OK → Phase 8                                                       │
│    → Security Fixes → Rollback zu Phase 4/5, dann Tests, Re-Audit      │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 8. PHASE 8 (code-reviewer) → APPROVAL                                  │
│    User reviewed Code Review                                            │
│    → APPROVED → Phase 9                                                 │
│    → CHANGES_REQUESTED → Rollback (deterministisch)                     │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│ 9. PHASE 9 (Push & PR) → APPROVAL                                      │
│    Pre-Push Build Gate (mvn verify + npm test + npm run build)          │
│    User: "Ja, pushen!"                                                  │
│    → pushApproved = true                                                │
│    → git push -u origin branch                                         │
│    → gh pr create                                                       │
│    → status = "completed"                                               │
│    → Stop Hook spielt Completion-Sound                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Approval Gates und User-Interaktion

### Was sind Approval Gates?

An bestimmten Phasen stoppt der Workflow und wartet auf den User. Der User kann:
- **Approven** (Weiter zur naechsten Phase)
- **Feedback geben** (Agent revidiert seine Arbeit)
- **Rollback anfordern** (Zurueck zu einer frueheren Phase)

### Welche Phasen haben Approval Gates?

| Phase | Warum Approval? |
|---|---|
| 0 (Tech Spec) | User muss Architektur-Entscheidungen validieren |
| 1 (Wireframes) | User muss UI-Design freigeben |
| 7 (Security) | User muss Security-Findings bewerten |
| 8 (Code Review) | User muss Code-Qualitaet bestaetigen |
| 9 (Push & PR) | User muss Push explizit erlauben |

### Wie funktioniert ein Approval Gate?

```
1. Agent beendet Phase 7 (Security Audit)
2. Stop Hook: wf_verify.sh → Audit-Datei existiert → DONE
3. Stop Hook: Phase 7 ist APPROVAL → status = "awaiting_approval"
4. Stop Hook: exit 0 → Claude stoppt, Sound spielt
5. User liest Security-Findings
6. User tippt: "Sieht gut aus, weiter"
7. UserPromptSubmit Hook feuert: wf_user_prompt.sh
8. Script erkennt: status=awaiting_approval, Phase=7
9. Script injiziert Anweisungen:
   "BEI APPROVAL: status=active, currentPhase=8, Task(bytA:code-reviewer, '...')"
10. Claude befolgt die Anweisung woertlich
```

---

## 12. Rollback-Mechanismus

### Wann passiert ein Rollback?

Nur an Approval Gates Phase 7 und 8:
- Phase 7: Security-Findings erfordern Fixes
- Phase 8: Code Review mit CHANGES_REQUESTED

### Wie funktioniert der Rollback?

**Deterministisch in `wf_orchestrator.sh` (Phase 8 Spezial):**

```
1. Code-Reviewer setzt: reviewFeedback.status = "CHANGES_REQUESTED"
   mit fixes[]: [{type: "backend", file: "path/File.java", issue: "..."}]

2. Stop Hook erkennt: Phase 8 + NOT DONE + CHANGES_REQUESTED

3. Rollback-Ziel bestimmen (Dateipfad-Heuristik):
   .sql → Phase 3 (Database)
   .java → Phase 4 (Backend)
   .ts/.html/.scss → Phase 5 (Frontend)
   Sonst → Phase 6 (Tests)

4. Context ab Rollback-Ziel loeschen:
   Ziel <= 5 → del(frontendImpl)
   Ziel <= 4 → del(backendImpl)
   Ziel <= 3 → del(migrations)
   Immer: del(reviewFeedback, securityAudit, testResults)

5. Spec-Dateien ab Rollback-Ziel loeschen (verhindert stale GLOB-Matches)

6. currentPhase = Rollback-Ziel, status = "active"

7. Agent starten mit Hotfix-Kontext:
   wf_prompt_builder.sh $ROLLBACK_TARGET "$FIXES_TEXT"
   → Agent bekommt: "Fix the following issues: [backend] Add authorization check"

8. Auto-Advance laeuft automatisch von Rollback-Ziel bis Phase 7 (naechstes Gate)
```

### Option C: Heuristik + User-Wahl (Phase 8)

Bei Phase 8 bietet `wf_user_prompt.sh` zusaetzlich an:

```
OPTION C - VORGESCHLAGENES ROLLBACK-ZIEL:
→ Phase 4 (Backend) basierend auf betroffenen Dateien:
  path/to/File.java
User kann bestaetigen oder anderes Ziel waehlen.
```

---

## 13. Fehlerbehandlung und Ralph-Loop-Retries

### 13.1 Agent liefert nicht

Wenn ein Agent seine Phase nicht erfuellt (Datei fehlt, State nicht gesetzt):

```
1. Stop Hook → wf_verify.sh → NOT DONE
2. increment_retry(phase) → attempt 1/3
3. wf_prompt_builder.sh baut Prompt mit RETRY NOTICE:
   "Previous attempt (1) did not complete successfully.
    Check existing work and complete the missing parts."
4. output_block() → Agent wird neu gestartet (frischer Context!)
5. Wiederholen bis DONE oder MAX_RETRIES (3)
6. Bei 3x Fehlschlag → status = "paused", User muss eingreifen
```

### 13.2 Loop-Prevention

Wenn der Stop Hook zu oft hintereinander `decision:block` ausgibt (Claude dreht sich im Kreis):

```
stopHookBlockCount >= MAX_STOP_HOOK_BLOCKS (15)
→ status = "paused"
→ pauseReason = "stop_hook_loop_detected"
→ User wird benachrichtigt (Sound)
```

Der Counter wird bei jedem UserPromptSubmit zurueckgesetzt (`wf_user_prompt.sh`).

### 13.3 Phase-Skip-Guard

Wenn die aktuelle Phase Vorgaenger-Phasen ohne Context hat:

```
detect_skipped_phase(4)
→ Prueft: Hat Phase 0 Context? Ja (technicalSpec existiert)
→ Prueft: Hat Phase 1 Context? Ja (wireframes existiert)
→ Prueft: Hat Phase 2 Context? Ja (apiDesign existiert)
→ Prueft: Hat Phase 3 Context? NEIN! → Rueckgabe: 3
→ Orchestrator korrigiert: currentPhase = 3, startet postgresql-architect
```

---

## 14. Session Recovery nach Context Overflow

Wenn Claudes Context-Fenster voll wird, startet eine neue Session. Der `SessionStart` Hook erkennt das:

```
1. session_recovery.sh feuert
2. Prueft: workflow-state.json vorhanden? Status active/paused/awaiting_approval?
3. Ja → Minimaler Output:

   WORKFLOW RECOVERY nach Context Overflow
   Issue:  #42 - User Dashboard
   Phase:  4 (Backend)
   Status: active
   PFLICHT-AKTION: Rufe /bytA:feature auf!

4. Claude ruft /bytA:feature auf → SKILL.md wird geladen
5. Stop Hook springt an → Ralph-Loop setzt automatisch fort
```

**Warum so einfach?** Der gesamte State liegt auf Disk. Der Orchestrator braucht keinen Context — nur den Skill und die Hooks.

---

## 15. Escape Commands

| Command | Funktion |
|---|---|
| `/bytA:wf-status` | Aktuellen Workflow-Status anzeigen |
| `/bytA:wf-pause` | Workflow pausieren |
| `/bytA:wf-resume` | Pausierten Workflow fortsetzen |
| `/bytA:wf-retry-reset` | Retry-Counter zuruecksetzen |
| `/bytA:wf-skip` | Aktuelle Phase ueberspringen (Notfall) |

---

## 16. Unterschied zu byt8

bytA ist das Nachfolge-Plugin von byt8. Der Kernunterschied:

| Aspekt | byt8 | bytA |
|---|---|---|
| **Orchestrator** | Claude (LLM) mit SKILL.md Regeln (~270 Zeilen) | Bash-Script (`wf_orchestrator.sh`) |
| **Done-Pruefung** | LLM interpretiert Agent-Output | Shell prueft Dateien/Exit-Codes |
| **Context-Wachstum** | Monoton steigend (Context Rot) | Konstant (~2.5 KB) |
| **Retry-Logik** | Stop Hook + Block Counter | Ralph-Loop (expliziter Retry-Counter) |
| **Rollback** | LLM fuehrt jq-Befehle aus | Shell-Script (deterministisch) |
| **Session Recovery** | Komplexer Recovery-Prompt | Trivial (State auf Disk) |
| **SKILL.md** | ~270 Zeilen Orchestrator-Logik | ~170 Zeilen ("Befolge Hooks") |
| **Fehlerklasse** | LLM vergisst Regeln nach 30 Min | Shell hat keine Regeln zu vergessen |
| **Hooks** | 6 (reagierend auf LLM-Fehler) | 5 (steuernd — LLM wird gesteuert) |
| **Agent-Isolation** | File Reference Protocol | Vollstaendige Boomerang-Isolation |
| **Agents** | Identisch (10 spezialisierte) | Identisch (unveraendert) |

---

## 17. Quellen

- [Boomerang Tasks — Roo Code](https://docs.roocode.com/features/boomerang-tasks)
- [Ralph Loop — Geoffrey Huntley](https://ghuntley.com/loop/)
- [Claude Code Hooks Dokumentation](https://code.claude.com/docs/en/hooks)
- [Claude Code Sub-Agents Dokumentation](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Plugins Dokumentation](https://code.claude.com/docs/en/plugins)
- [Ralph Orchestrator Research](https://mikeyobrien.github.io/ralph-orchestrator/research/)
