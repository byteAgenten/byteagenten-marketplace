# bytM Plugin

**Version 1.1.2** | TeamCreate + Hub-and-Spoke Planning mit Cross-Validation

Full-Stack Development fuer Angular 21 + Spring Boot 4 mit TeamCreate, SendMessage-Kommunikation und runden-frischen Agents.

## Architektur

Der Orchestrator ist ein **LLM Team Lead**. Pro Runde werden frische Agents gespawnt, die innerhalb der Runde via `SendMessage` kommunizieren. Zwischen Runden fliessen Informationen ueber `.workflow/specs/` Dateien.

| Prinzip | Bedeutung |
|---------|-----------|
| **TeamCreate + SendMessage** | Agents kommunizieren direkt miteinander innerhalb einer Runde |
| **Runden-frische Agents** | Jede Runde spawnt frische Agents — kein Context-Overflow |
| **Hub-and-Spoke Planning** | 4 Spezialisten planen → Architect konsolidiert |
| **Spezialisierte Verify-Agents** | Test Engineer, Security Auditor, Code Reviewer als separate Spezialisten |

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  Team Lead (SKILL.md, Delegate Mode)                         │
│  TeamCreate → spawnt frische Agents pro Runde                │
│                                                              │
│  ROUND 1 — PLAN (Hub-and-Spoke):                             │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ Backend  │  │ Frontend │  │ UI-Design│  │ Quality  │     │
│  │ Dev      │  │ Dev      │  │ er       │  │ Engineer │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │             │             │             │
│       └──── SendMessage ──────────┘─────────────┘             │
│                     │                                        │
│                     ▼                                        │
│              ┌─────────────┐                                 │
│              │  Architect  │                                 │
│              │ Konsolidiert│                                 │
│              └─────────────┘                                 │
│                                                              │
│  ROUND 2 — IMPLEMENT:                                        │
│  ┌───────────┐  ←SendMessage→  ┌───────────┐                │
│  │ Backend   │                 │ Frontend  │                │
│  │ Developer │                 │ Developer │                │
│  └───────────┘                 └───────────┘                │
│                                                              │
│  ROUND 3 — VERIFY:                                           │
│  ┌────────────┐  ┌───────────┐  ┌───────────┐               │
│  │   Test     │  │ Security  │  │   Code    │               │
│  │ Engineer   │  │ Auditor   │  │ Reviewer  │               │
│  └────────────┘  └───────────┘  └───────────┘               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

```
/bytM:feature #42
```

## Commands

| Command | Beschreibung |
|---------|-------------|
| `/bytM:feature` | Full-Stack Feature Workflow mit Hub-and-Spoke Planning |
| `/bytM:prd-generator` | PRD-Generator: Product Requirements Documents + GitHub Issues |

## Workflow: 4 Runden

```
/bytM:feature #42

Round 0:   STARTUP      --- Issue laden, Model-Tier wählen, Branch, TeamCreate
Round 1:   PLAN          --- 5 Agents: 4 Spezialisten → Architect konsolidiert
Round 1.5: USER APPROVAL --- Du genehmigst die konsolidierte Spec    <-- DEIN INPUT
Round 2:   IMPLEMENT     --- 2 Agents (Backend + Frontend) implementieren
Round 3:   VERIFY        --- 3 Spezialisten (Test + Security + Code Review)
Round 3.5: USER APPROVAL --- Du genehmigst das Ergebnis              <-- DEIN INPUT
Round 4:   SHIP          --- Push & PR
```

### Round 1: PLAN — Hub-and-Spoke (5 Agents)

4 Spezialisten planen parallel, senden Zusammenfassungen an den Architect:

| Agent | Plant | SendMessage an Architect |
|-------|-------|--------------------------|
| Backend Dev | DB-Schema, Services, Endpoints | *"2 Entities, 3 Endpoints, Flyway V15"* |
| Frontend Dev | Components, Routing, State | *"ReportListComponent, Route /reports, ReportService"* |
| UI-Designer | Wireframe HTML mit data-testid | *"Wireframe fertig, 14 data-testid, Material Table"* |
| Test Engineer | E2E-Szenarien, Coverage | *"8 Szenarien, 80% Coverage-Ziel"* |

Der **Architect** empfaengt alle 4, prueft Konsistenz:

```
Backend: "POST /api/reports erwartet {title, configId}"
Frontend: "ReportService.create() sendet {title, config}"
                                              ^^^^^^^^
Architect erkennt: "config" vs "configId" → Konflikt!
Architect → Frontend: "Bitte Feld zu 'configId' (UUID) anpassen"
Frontend → Architect: "Angepasst"
Architect: Konsolidierte Spec schreiben → Konflikt geloest
```

**Output:** Konsolidierte Tech Spec (`plan-consolidated.md`) + Einzel-Plaene + Wireframe

### Round 1.5: USER APPROVAL

Du siehst die konsolidierte Spec und genehmigst, aenderst oder brichst ab.

### Round 2: IMPLEMENT (Scope-basiert: 1-2 Agents)

Der Architect bestimmt den **Implementation Scope** in der konsolidierten Spec:

| Scope | Agents | Beispiel |
|-------|--------|----------|
| `full-stack` | Backend + Frontend (2) | Neues Feature mit UI + API |
| `backend-only` | Backend (1) | PDF-Export, neue API ohne UI |
| `frontend-only` | Frontend (1) | UI-Redesign ohne API-Aenderung |

**Nur betroffene Agents werden gespawnt** — kein Frontend-Agent bei reinem Backend-Feature.

| Agent | Implementiert | Kommunikation |
|-------|--------------|---------------|
| Backend Dev | Entities, Services, Controller, Migrations, Tests | Kann Frontend fragen |
| Frontend Dev | Components, Services, Routing, Tests, data-testid | Kann Backend fragen |

Agents lesen die **konsolidierte Spec** von Disk. Koennen sich bei Unklarheiten per `SendMessage` abstimmen.

### Round 3: VERIFY (3 Spezialisten)

| Agent | Aufgabe | Ergebnis |
|-------|---------|----------|
| Test Engineer | E2E-Tests schreiben + ausfuehren, Coverage messen | `verify-test-engineer.md` |
| Security Auditor | OWASP-Audit aller Aenderungen | `verify-security-auditor.md` |
| Code Reviewer | Code Review + Build Gate (mvn verify, npm test, npm build) | `verify-code-reviewer.md` |

### Round 3.5: USER APPROVAL

Du siehst alle 3 Verify-Reports und genehmigst oder forderst Aenderungen an.

### Round 4: SHIP

Team Lead: Build Gate → Push → PR erstellen → TeamDelete → PR-URL anzeigen.

## Agent-Kommunikation

| Runde | Kommunikations-Modell | Ueber |
|-------|-----------------------|-------|
| Plan | Hub-and-Spoke (Spezialisten → Architect) | SendMessage |
| Implement | Peer-to-Peer (Backend ↔ Frontend) | SendMessage |
| Verify | Unabhaengig (jeder prueft separat) | Nur → Team Lead |
| Zwischen Runden | Disk-basiert (Specs) | `.workflow/specs/` |

## Wo muss ich als User approven?

| Runde | Musst du approven? | Deine Optionen |
|-------|-------------------|----------------|
| Round 0: Startup | **Ja** (Infos geben) | Issue-Nr, Branch, Coverage, Model-Tier (fast/quality) |
| Round 1: Plan | Nein (automatisch) | — |
| **Round 1.5** | **JA** | Genehmigen / Aendern / Abbrechen |
| Round 2: Implement | Nein (automatisch) | — |
| Round 3: Verify | Nein (automatisch) | — |
| **Round 3.5** | **JA** | Genehmigen / Aendern / Rollback |
| **Round 4: Ship** | **JA** (PR-Confirmation) | Push / Aendern |

## Das Team

Beim Start waehlt der User den **Model-Tier**:

| Tier | Model | Fuer |
|------|-------|------|
| **fast** (default) | Sonnet | Standard-Features, CRUD, einfache UI |
| **quality** | Opus | Komplexe Business-Logik, verschachtelte State-Patterns |

| Agent | Domain | Runden |
|-------|--------|--------|
| **Architect** | Konsolidierung, API-Design, Konflikt-Resolution | Plan |
| **Backend Dev** | Spring Boot, DB, Migrations, Tests | Plan, Implement |
| **Frontend Dev** | Angular, Routing, State, Tests | Plan, Implement |
| **UI-Designer** | Wireframes (HTML), Material Design, data-testid | Plan |
| **Test Engineer** | Test-Strategie, E2E-Tests, Coverage | Plan, Verify |
| **Security Auditor** | OWASP-Audit | Verify |
| **Code Reviewer** | Code Quality, Build Gate | Verify |

**Total: 10 Agent-Spawns** ueber 3 Runden (5 + 2 + 3), jeder mit frischem Context.

## Hook-Architektur

| Hook | Script | Funktion |
|------|--------|----------|
| **PreToolUse/Bash** | `guard_git_push.sh` | Blockiert Push ohne pushApproved |
| **TaskCompleted** | `verify_task.sh` | Prueft ob Output-Dateien existieren |
| **TeammateIdle** | `wip_commit.sh` | WIP-Commits bei Agent-Idle |
| **SessionStart** | `session_recovery.sh` | Compaction Recovery + Session-ID-Tracking |
| **Notification/idle_prompt** | `play_notification.sh` | Sound wenn User-Input noetig |
| **Stop** | `play_completion.sh` | Sound wenn Workflow abgeschlossen |

## Spec-Dateien

| Runde | Pattern | Beispiel |
|-------|---------|---------|
| Plan (Spezialisten) | `issue-{N}-plan-{role}.md` | `issue-42-plan-backend.md` |
| Plan (UI) | `issue-{N}-plan-ui.md` | `issue-42-plan-ui.md` |
| Plan (konsolidiert) | `issue-{N}-plan-consolidated.md` | `issue-42-plan-consolidated.md` |
| Implement | `issue-{N}-impl-{role}.md` | `issue-42-impl-frontend.md` |
| Verify | `issue-{N}-verify-{role}.md` | `issue-42-verify-security-auditor.md` |
| Wireframes | `wireframes/issue-{N}-{slug}.html` | `wireframes/issue-42-reports.html` |

## Koexistenz mit bytA

- bytA: `workflow: "bytA-feature"` — `/bytA:feature`
- bytM: `workflow: "bytM-feature"` — `/bytM:feature`
- Alle Hooks pruefen das `workflow` Feld (Ownership Guard)
- Kein Konflikt moeglich
