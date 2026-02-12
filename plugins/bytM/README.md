# bytM Plugin

**Version 1.0.0** | 4-Agent Team mit Cross-Validation

Full-Stack Development fuer Angular 21 + Spring Boot 4 mit nativen Claude Code Agent Teams.

## Voraussetzung

Agent Teams muss aktiviert sein:

```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Architektur

Der Orchestrator ist ein **LLM Team Lead**, kein Shell-Script. 4 feste Agents arbeiten parallel und validieren sich gegenseitig.

| Prinzip | Bedeutung |
|---------|-----------|
| **Fixed Team** | Immer 4 Agents: Architect, Backend, Frontend, Quality |
| **Cross-Validation** | Jeder Agent prueft die Plaene der anderen VOR der Implementation |
| **Plan-First** | Code wird erst geschrieben NACHDEM alle Plaene validiert sind |

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  Team Lead (SKILL.md, Delegate Mode)                         │
│                                                              │
│  ┌────────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐ │
│  │ Architect  │  │ Backend   │  │ Frontend  │  │ Quality   │ │
│  │            │  │ Developer │  │ Developer │  │ Engineer  │ │
│  │ Tech Spec  │  │ Spring    │  │ Angular   │  │ Security  │ │
│  │ API Design │  │ Boot + DB │  │ + UI      │  │ Review    │ │
│  │ Architektur│  │ + Tests   │  │ + Tests   │  │ E2E Tests │ │
│  └────────────┘  └───────────┘  └───────────┘  └───────────┘ │
│                                                              │
│  Alle 4 arbeiten PARALLEL in jeder Runde                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

```
/bytM:feature #42
```

Oder ohne Issue-Nummer (wirst nach Infos gefragt):

```
/bytM:feature
```

## Commands

| Command | Beschreibung |
|---------|-------------|
| `/bytM:feature` | 4-Agent Team Workflow fuer Full-Stack Features |
| `/bytM:prd-generator` | PRD-Generator: Product Requirements Documents + GitHub Issues |

## Workflow: 5 Runden

```
/bytM:feature #42

Round 0:   STARTUP      ─── Issue laden, Branch erstellen
Round 1:   PLAN          ─── Alle 4 Agents planen parallel
Round 1.5: USER APPROVAL ─── Du genehmigst die Plaene       ◄── DEIN INPUT
Round 2:   VALIDATE      ─── Cross-Validation (Agents pruefen sich gegenseitig)
Round 3:   IMPLEMENT     ─── Alle implementieren parallel
Round 4:   VERIFY        ─── Security + Code Review + E2E Tests
Round 4.5: USER APPROVAL ─── Du genehmigst das Ergebnis     ◄── DEIN INPUT
Round 5:   SHIP          ─── Push & PR
```

### Round 0: Startup

Der Team Lead:
1. Fragt dich nach Issue-Nummer, Branch und Coverage-Ziel
2. Laedt das GitHub Issue
3. Erstellt den Feature-Branch
4. Initialisiert `.workflow/workflow-state.json`

### Round 1: PLAN (4 Agents parallel)

Alle 4 Agents planen gleichzeitig in ihrem Fachgebiet:

| Agent | Plant | Output |
|-------|-------|--------|
| Architect | Tech Spec + API Design | `plan-architect.md` |
| Backend | DB Schema + Backend-Strategie | `plan-backend.md` |
| Frontend | Wireframes + Komponenten-Plan | `plan-frontend.md` + Wireframe HTML |
| Quality | Test-Strategie + Quality Gates | `plan-quality.md` |

### Round 1.5: USER APPROVAL

```
PLAENE FERTIG
========================================
Issue: #42 - Add user dashboard

ARCHITECT:
  Architektur: Layered (Entity → Repo → Service → Controller)
  Neue Endpoints: GET /api/dashboard, GET /api/dashboard/stats

BACKEND:
  Migrationen: V42__create_dashboard_tables.sql (2 neue Tabellen)
  Neue Services: DashboardService, StatsService

FRONTEND:
  Komponenten: DashboardComponent, StatsWidgetComponent
  Routing: /dashboard (lazy loaded)

QUALITY:
  Testplan: 12 E2E Szenarien, 85% Coverage Ziel
  Security-Fokus: A01 (Access Control)
========================================
Optionen:
  1. Genehmigen (weiter zur Cross-Validation)
  2. Aenderungen anfordern (spezifisch angeben)
  3. Workflow abbrechen
```

**Deine Optionen:**
- **Genehmigen** → Weiter zu Round 2
- **Aenderungen** → Du sagst was geaendert werden soll, der betroffene Agent ueberarbeitet
- **Abbrechen** → Workflow wird beendet

### Round 2: CROSS-VALIDATE

Die Kern-Innovation von bytM: **Jeder Agent prueft die Plaene der anderen.**

```
              Prueft:
              Architect   Backend   Frontend
Pruefer:
  Architect     --         ✓          ✓
  Backend      ✓           --         ✓
  Frontend     ✓          ✓           --
  Quality      ✓          ✓           ✓    ← prueft ALLE
```

Jeder Plan wird von mindestens 2 Agents geprueft. Ergebnisse:

| Level | Bedeutung | Aktion |
|-------|-----------|--------|
| **PASS** | Alles OK | Weiter |
| **WARN** | Kleine Probleme | Wird bei Implementation beruecksichtigt |
| **BLOCK** | Kritisches Problem | MUSS gefixt werden (max 2 Fix-Zyklen) |

**Du wirst NICHT gefragt** — die Agents loesen BLOCKs untereinander. Nur nach 2 erfolglosen Fix-Zyklen wirst du einbezogen.

### Round 3: IMPLEMENT (3 Agents parallel)

Erst NACHDEM alle Plaene validiert sind, wird Code geschrieben:

| Agent | Implementiert | Datei-Domain |
|-------|--------------|-------------|
| Backend | Spring Boot + DB Migrations + Tests | `backend/` |
| Frontend | Angular Komponenten + Tests | `frontend/` |
| Quality | E2E Test-Scaffolding | `e2e/` |
| Architect | Beobachtet, beantwortet Fragen | nur `.workflow/specs/` |

**File Domain Isolation**: Kein Agent schreibt in den Bereich eines anderen.

**Du wirst NICHT gefragt** — die Agents arbeiten selbststaendig.

### Round 4: VERIFY (4 Agents parallel)

Alle 4 Agents pruefen die Implementierung:

| Agent | Verifiziert | Wie |
|-------|------------|-----|
| Architect | API Contract Konsistenz | Liest Controller + Services |
| Backend | Frontend-Integration | Prueft ob Frontend-Calls matchen |
| Frontend | Backend-Kompatibilitaet | Prueft ob Responses passen |
| Quality | **Voller Audit** (3 Reports) | Security + Code Review + E2E Tests |

Quality Engineer produziert 3 Reports:
1. `verify-test-engineer.md` — E2E Testergebnisse
2. `verify-security-auditor.md` — OWASP Security Audit
3. `verify-code-reviewer.md` — Code Review

### Round 4.5: USER APPROVAL

```
VERIFIKATION ABGESCHLOSSEN
========================================
Security Audit:  PASS (0 kritisch, 2 niedrig)
Code Review:     APPROVED (kleinere Vorschlaege notiert)
E2E Tests:       ALLE BESTANDEN (14/14)
Coverage:        87% (Ziel: 70%)

Cross-Validation:
  Architect:     API Contracts konsistent
  Backend:       Frontend-Integration verifiziert
  Frontend:      Backend-Kompatibilitaet bestaetigt
========================================
Optionen:
  1. Genehmigen (Push & PR erstellen)
  2. Aenderungen anfordern
  3. Zurueck zu Round 3 (Re-Implementation)
```

**Deine Optionen:**
- **Genehmigen** → Push & PR
- **Aenderungen** → Spezifischer Agent bekommt Feedback, fixt, Quality re-verifiziert
- **Zurueck** → Rollback zu Implementation

### Round 5: SHIP

Der Team Lead:
1. Fuehrt Build Gate aus: `mvn verify` + `npm test` + `npm run build`
2. Pusht den Branch
3. Erstellt PR mit umfassender Description
4. Faehrt das Team herunter
5. Zeigt dir die PR-URL

## Wo muss ich als User approven?

| Runde | Was passiert | Musst du approven? | Deine Optionen |
|-------|-------------|-------------------|----------------|
| Round 0: Startup | Issue + Branch Setup | **Ja** (Infos geben) | Issue-Nr, Branch, Coverage |
| Round 1: Plan | 4 Agents planen | Nein (laeuft automatisch) | — |
| **Round 1.5** | **Plaene praesentiert** | **JA** | Genehmigen / Aendern / Abbrechen |
| Round 2: Validate | Cross-Validation | Nein (Agents untereinander) | — |
| Round 3: Implement | Code schreiben | Nein (laeuft automatisch) | — |
| Round 4: Verify | Security + Review + Tests | Nein (laeuft automatisch) | — |
| **Round 4.5** | **Ergebnis praesentiert** | **JA** | Genehmigen / Aendern / Rollback |
| **Round 5: Ship** | **PR erstellen** | **JA** (PR-Confirmation) | Push / Aendern |

**Zusammenfassung: 2 Approvals + 1 PR-Confirmation** (vs. 5 Approvals bei bytA)

## Vergleich mit bytA

| | bytA (Shell-Orchestrierung) | bytM (Agent Teams) |
|---|---|---|
| Orchestrator | Bash-Script (`wf_orchestrator.sh`) | LLM Team Lead (SKILL.md) |
| Agents | 10 verschiedene, 1 zur Zeit | 4 feste, immer parallel |
| Phasen | 10 sequentiell | 5 Runden |
| Shell Scripts | 13 (~2.400 Zeilen) | 6 (~200 Zeilen) |
| Parallelitaet | Keine | 4x in jeder Runde |
| Cross-Validation | Keine | VOR + NACH Implementation |
| Fehler-Erkennung | Spaet (Phase 7-8) | Frueh (Round 2) |
| User Approvals | 5 | 2 + PR |
| Rollback-Kosten | Hoch (5 Phasen wiederholen) | Niedrig (Plan fixen) |
| Determinismus | Hoch (Shell steuert) | Mittel (LLM steuert) |
| Token-Kosten | Niedriger | Hoeher (4 parallele Sessions) |

## Das Team

| Agent | Domain | Liest | Schreibt |
|-------|--------|-------|----------|
| **Architect** | Tech Spec, API Design | Issue, Codebase | `plan-architect.md`, `validation-architect.md` |
| **Backend** | Spring Boot, DB, Tests | Specs, Backend-Code | `plan-backend.md`, Migrations, Controller, Services |
| **Frontend** | Angular, Wireframes, Tests | Specs, Frontend-Code | `plan-frontend.md`, Wireframes, Components |
| **Quality** | Security, Review, E2E | Specs, ALLER Code | `plan-quality.md`, 3 Verify-Reports |

## Hook-Architektur

6 Hooks (vs. 9 bei bytA):

| Hook | Script | Funktion |
|------|--------|----------|
| **PreToolUse/Bash** | `guard_git_push.sh` | Blockiert Push ohne pushApproved |
| **TaskCompleted** | `verify_task.sh` | Prueft ob Output-Dateien existieren |
| **TeammateIdle** | `wip_commit.sh` | WIP-Commits bei Agent-Idle |
| **SessionStart** | `session_recovery.sh` | Compaction Recovery + Session-ID-Tracking |
| **Notification/idle_prompt** | `play_notification.sh` | Sound wenn User-Input noetig |
| **Stop** | `play_completion.sh` | Sound wenn Workflow abgeschlossen |

## Spec-Dateien

Alle Specs liegen unter `.workflow/specs/`:

| Runde | Pattern | Beispiel |
|-------|---------|---------|
| Plan | `issue-{N}-plan-{agent}.md` | `issue-42-plan-backend.md` |
| Validate | `issue-{N}-validation-{agent}.md` | `issue-42-validation-quality.md` |
| Implement | `issue-{N}-impl-{agent}.md` | `issue-42-impl-frontend.md` |
| Verify | `issue-{N}-verify-{agent}.md` | `issue-42-verify-architect.md` |
| Quality Reports | `issue-{N}-verify-*.md` | `issue-42-verify-security-auditor.md` |

## Risiken

| Risiko | Severity | Mitigation |
|--------|----------|------------|
| Agent Teams ist experimentell | HOCH | bytA bleibt als Fallback |
| Keine Session Resumption | MITTEL | SessionStart-Hook stellt Kontext nach Compaction wieder her |
| LLM-Lead kann falsche Entscheidungen treffen | MITTEL | SKILL.md hat strikte Regeln, Hooks als Guardrails |
| Hoehere Token-Kosten | NIEDRIG-MITTEL | Trade-off: weniger Rollbacks sparen Tokens |

## Koexistenz mit bytA

Beide Plugins koennen gleichzeitig installiert sein:
- bytA: `workflow: "bytA-feature"` — `/bytA:feature`
- bytM: `workflow: "bytM-feature"` — `/bytM:feature`
- Alle Hooks pruefen das `workflow` Feld (Ownership Guard)
- Kein Konflikt moeglich
