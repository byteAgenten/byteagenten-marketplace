# bytA Plugin

**Version 4.7.5** | Deterministic Orchestration: Boomerang + Ralph-Loop + Team Planning

Full-Stack Development Toolkit fuer Angular 21 + Spring Boot 4 mit deterministischem 8-Phasen-Workflow und Team-basiertem Planning.

## Architektur

Der Orchestrator ist ein **Bash-Script**, kein LLM. Claude dient nur als Transport-Layer fuer Agent-Aufrufe.

| Prinzip | Bedeutung |
|---------|-----------|
| **Ralph-Loop** | `while !done; do spawn_agent; verify; done` — Externe Verifikation |
| **Boomerang** | Vollstaendige Kontext-Isolation pro Agent — kein Context Rot |
| **Deterministisch** | Shell-Scripts steuern, LLM fuehrt aus |
| **Hub-and-Spoke** | Phase 0: 3-4 Spezialisten planen parallel → Architect konsolidiert (v4.0) |

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  Stop Hook (wf_orchestrator.sh)                          │
│  ┌────────────────────────┐                              │
│  │  1. verify_done()      │  ← Shell prueft Dateien/    │
│  │     (wf_verify.sh)     │    State (kein LLM!)        │
│  │                        │                              │
│  │  2. done? → advance    │  ← AUTO: naechste Phase     │
│  │           → approval   │  ← APPROVAL: User fragen    │
│  │                        │                              │
│  │  3. !done? → re-spawn  │  ← Ralph-Loop retry         │
│  │     (max 3 attempts)   │    (frischer Agent-Context)  │
│  └────────────────────────┘                              │
│                                                          │
│  Agent-Dispatch via decision:block                       │
│  → Claude MUSS Task(bytA:agent) ausfuehren              │
│  → Agent laeuft isoliert (Boomerang)                     │
│  → Orchestrator prueft extern (Ralph)                    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Commands

| Command | Beschreibung |
|---------|-------------|
| `/bytA:feature` | Deterministischer 8-Phasen-Workflow fuer Full-Stack Features |
| `/bytA:prd-generator` | PRD-Generator: Product Requirements Documents + GitHub Issues |
| `/bytA:wf-status` | Aktuellen Workflow-Status anzeigen (Phase, Hints, Pause, Retries) |
| `/bytA:wf-skip` | Aktuelle Phase ueberspringen (Notfall) |

## Workflow

```
/bytA:feature #391
```

### Phasen

| Phase | Agent | Typ | Done-Kriterium |
|-------|-------|-----|----------------|
| 0 | team-planning (Hub-and-Spoke) | APPROVAL | Consolidated Spec existiert |
| 1 | postgresql-architect | AUTO | Migration SQL existiert |
| 2 | spring-boot-developer | AUTO | Backend-Report MD existiert |
| 3 | angular-frontend-developer | AUTO | Frontend-Report MD existiert |
| 4 | test-engineer | AUTO | allPassed == true + Report-Datei existiert |
| 5 | security-auditor | APPROVAL | Audit-Datei existiert |
| 6 | code-reviewer | APPROVAL | Review-Datei existiert |
| 7 | Push & PR | APPROVAL | PR URL in State |

**APPROVAL** = User muss approven (Workflow pausiert)
**AUTO** = Externe Verifikation, dann naechste Phase automatisch
**CHECKPOINT** = Konfigurierbar beim Startup: AUTO-Phasen koennen als Checkpoint laufen (Enter = weiter, oder Feedback geben)

### Flexibility Features (v4.7.0)

| Feature | Beschreibung | Bedienung |
|---------|-------------|-----------|
| **Pause/Resume** | Workflow nach aktueller Phase pausieren | `wf_advance.sh pause` / `resume` |
| **User Hints** | Persistenter Kontext fuer alle Agents | `wf_advance.sh hint 'TEXT'` / `hint-clear` |
| **Phase Summaries** | Zusammenfassung bei AUTO-Advance | Automatisch (erste 10 Zeilen der Spec) |
| **Checkpoint-Modus** | AUTO-Phasen optional als Checkpoint | Startup-Frage: Keine / Nur Tests / Alle |
| **Rollback-Findings** | Review-Findings im Rollback-Kontext | Automatisch (erste 20 Zeilen der Approval-Spec) |

### Phase 0: Hub-and-Spoke Team Planning (v4.0)

```
Phase 0 — Team Planning (Hub-and-Spoke):

  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ Backend  │  │ Frontend │  │ Quality  │  │UI-Design │
  │ Dev      │  │ Dev      │  │ Engineer │  │(optional)│
  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
       │             │             │             │
       └──── SendMessage ──────────┘─────────────┘
                     │
                     ▼
              ┌─────────────┐
              │  Architect  │  ← Konsolidiert, prueft Konsistenz
              │  (Hub)      │  ← Schreibt plan-consolidated.md
              └─────────────┘
```

Jeder Spezialist schreibt ERST einen Plan auf Disk, DANN sendet er eine Summary an den Architect.
Der Architect wartet auf ALLE Summaries, liest volle Plaene, validiert Konsistenz,
und schreibt die konsolidierte Spec. Der User-Model-Tier bestimmt ob Sonnet oder Opus.

**Recovery bei fehlenden Plan-Dateien (v4.6.0):**
Wenn ein Spezialist die Summary sendet aber die Datei auf Disk fehlt:
1. Architect triggert den Spezialisten per SendMessage → "Schreibe die Datei"
2. Spezialist wacht auf und schreibt die Datei
3. Falls nach 2 Retries keine Datei: Summary-Inhalt als Fallback verwenden

**Fallback:** Wenn Agent Teams nicht aktiviert, laeuft Phase 0 als single architect-planner.

### Ablauf-Diagramm

```
Phase 0 (Team Plan) ──[User Approval]──→ Phase 1 (DB) → Phase 2 (Backend) → Phase 3 (Frontend) → Phase 4 (Tests)
                                           AUTO           AUTO                  AUTO                  AUTO
                                                                                                       │
                                                                                                       ▼
                                        Phase 5 (Security) ──[User Approval]──→ Phase 6 (Review) ──[User Approval]──→ Phase 7 (PR)
```

### Rollback (User-Entscheidung an Approval Gates)

Bei Phase 0/5/6 sieht der User die Ergebnisse und entscheidet:
1. `approve` → weiter zur naechsten Phase
2. `feedback 'MSG'` → gleiche Phase nochmal
3. `rollback ZIEL 'MSG'` → Rollback zu Phase 1-5 mit Feedback-Propagation
4. `rollback ZIEL --fast 'MSG'` → Fast Rollback: ueberspringt intermediäre Phasen

**Fast Rollback (v4.3.0):** Bei CSS/Style-only Aenderungen koennen Tests und Security
uebersprungen werden. Nutzt bestehende Phase-Skip-Infrastruktur (`get_next_active_phase`).
Context und Specs der uebersprungenen Phasen bleiben erhalten (Code Reviewer sieht sie).
Phase 7 PR-Vorschau zeigt "SKIPPED" fuer uebersprungene Phasen.

## Hook-Architektur

Alle Hooks sind **Plugin-Level** (in `hooks.json`). Skill-Level Hooks in Plugins feuern nicht zuverlaessig (GitHub #17688).

| Hook | Script | Funktion |
|------|--------|----------|
| **Stop** | `wf_orchestrator.sh` | Ralph-Loop: Verify → Advance/Retry → Agent-Dispatch |
| **UserPromptSubmit** | `wf_user_prompt.sh` | Approval Gate Context + Rollback-Optionen |
| **PreToolUse/Bash** | `guard_git_push.sh` | Blockiert Push ohne pushApproved |
| **PreToolUse/Edit\|Write** | `block_orchestrator_code_edit.sh` | Blockiert Code-Aenderungen im Orchestrator |
| **PreToolUse/Read** | `block_orchestrator_code_read.sh` | Blockiert Code-Lesen im Orchestrator |
| **PreToolUse/Task** | `block_orchestrator_explore.sh` | Blockiert Explore/general-purpose im Orchestrator |
| **SubagentStart** | `subagent_start.sh` | Setzt `.subagent-active` Marker |
| **SubagentStop** | `subagent_done.sh` | WIP-Commits + Compact-Report + Marker-Cleanup |
| **SessionStart** | `session_recovery.sh` | Recovery nach Session-Start UND Compaction |

### Orchestrator-Blocker (v3.9.0)

Die PreToolUse-Blocker verhindern, dass der Orchestrator Code direkt liest/schreibt. Vier Schichten:

1. **Ownership Guard** — Nur bei aktivem `bytA-feature` Workflow mit Status `active`/`paused`/`awaiting_approval`
2. **Session Isolation (v3.9.2)** — `ownerSessionId` in `workflow-state.json` identifiziert die Workflow-Session. Andere Sessions (z.B. fuer Issue-Erstellung) werden NICHT blockiert. `session_id` ist ein Common Input Field in jedem Hook-Event.
3. **Subagent-Active Marker** — `SubagentStart` setzt `.workflow/.subagent-active`, `SubagentStop` entfernt ihn. Blocker erlauben Tool-Aufrufe wenn der Marker existiert (Subagents DUERFEN Code bearbeiten)
4. **JSON deny Pattern** — `permissionDecision: "deny"` statt `exit 2` (zuverlaessiger, siehe GitHub #13744)

Session-Lifecycle:
- **Workflow-Start**: Stop-Hook setzt `ownerSessionId` beim ersten Fire
- **Resume**: SessionStart-Hook aktualisiert `ownerSessionId` (neue ID bei Resume, GitHub #8069)
- **Compact**: Gleiche Session-ID, kein Update noetig

### Compact Recovery (v3.9.0)

Nach Context-Compaction verliert Claude die SKILL.md-Instruktionen. Der `SessionStart` Hook erkennt `source=compact` und re-injiziert starke Transport-Layer-Instruktionen:

- "Du bist ein TRANSPORT-LAYER — sage nur Done."
- "Der Stop-Hook uebernimmt ALLES"
- PreToolUse-Blocker blockieren Code-Zugriff deterministisch
- Kein `/bytA:feature` Aufruf noetig (wuerde von wf_cleanup.sh blockiert)

## Agents

| Agent | Phase | Aufgabe |
|-------|-------|---------|
| architect-planner | 0 (Hub) | Konsolidierung, Konsistenz-Pruefung, Phase-Skipping, Tech Spec |
| spring-boot-developer | 0 (Spoke), 2 | Backend-Plan (Phase 0), Implementation (Phase 2) |
| angular-frontend-developer | 0 (Spoke), 3 | Frontend-Plan (Phase 0), Implementation (Phase 3) |
| test-engineer | 0 (Spoke), 4 | Test Impact Analysis (Phase 0), E2E Tests (Phase 4) |
| ui-designer | 0 (optional Spoke) | Wireframe-Plan + data-testid (Phase 0) |
| postgresql-architect | 1 | Flyway SQL Migrations, Schema, Indexes |
| security-auditor | 5 | OWASP Top 10 Security Audit |
| code-reviewer | 6 | Code Quality Gate (SOLID, Coverage, Architecture) |
| architect-reviewer | - | Eskalation bei Architektur-Concerns |

## Externe Verifikation (kein LLM!)

Done-Kriterien werden von `wf_verify.sh` extern geprueft:

| Phase | Pruefung | Methode |
|-------|----------|---------|
| 0 | Consolidated Spec | `ls .workflow/specs/*-plan-consolidated.md` |
| 1 | Migration | `ls backend/.../V*.sql` |
| 2 | Backend-Report | `ls .workflow/specs/*-ph02-*.md` |
| 3 | Frontend-Report | `ls .workflow/specs/*-ph03-*.md` |
| 4 | Tests bestanden | `jq .context.testResults.allPassed` + `ls .workflow/specs/*-ph04-*.md` |
| 5 | Audit-Datei | `ls .workflow/specs/*-ph05-*.md` |
| 6 | Review-Datei | `ls .workflow/specs/*-ph06-*.md` |
| 7 | PR URL | `jq .phases["7"].prUrl` |

### Compound-Kriterien (v3.3.0)

Phase 4 nutzt ein Compound-Kriterium (`+` Separator): STATE und GLOB muessen BEIDE bestanden werden.
`wf_verify.sh` unterstuetzt beliebige Kombinationen: `STATE:...+GLOB:...+VERIFY:...`

### Status-Bypass Guard (v3.3.0)

Der Stop-Hook (`wf_orchestrator.sh`) prueft GLOB-Kriterien auch im `awaiting_approval` Status.
Verhindert, dass ein LLM die externe Verifikation umgeht, indem es `status = "awaiting_approval"` setzt,
bevor der Shell-Orchestrator verifizieren kann. Bei fehlgeschlagenem GLOB → Reset auf `active` → Ralph-Loop.

### Hook CWD Fix (v3.5.0)

Alle Hook-Scripts lesen `cwd` aus dem Hook-Input-JSON (stdin) und wechseln ins Projekt-Root
bevor sie auf `.workflow/` zugreifen. Claude Code kann Hooks von einem beliebigen Working Directory
starten — ohne diesen Fix finden die Scripts die Workflow-Dateien nicht und beenden sich lautlos.

Der Stop-Hook (`wf_orchestrator.sh`) loggt zusaetzlich nach `/tmp/bytA-orchestrator-debug.log`
fuer Fehlerdiagnose (CWD vorher/nachher, Workflow-Datei-Existenz, ERR-Trap mit Zeilennummer).

### Workflow Ownership Guard (v3.6.0)

Alle 5 Plugin-Level-Hooks pruefen `workflow == "bytA-feature"` bevor sie aktiv werden.
Plugin-Level Hooks feuern **global** fuer JEDES Event, unabhaengig davon welches Plugin/Skill
den Workflow gestartet hat. Ohne diesen Guard koennen andere Plugins (z.B. byt8) denselben
`workflow-state.json` lesen/schreiben und eine Race Condition + State-Corruption verursachen.

Betroffene Scripts: `wf_orchestrator.sh`, `wf_user_prompt.sh`, `subagent_done.sh`,
`session_recovery.sh`, `guard_git_push.sh`.

### Deterministic Approval-Advance (v3.7.0)

Alle Approval-Phasen (0, 5, 6, 7) nutzen `wf_advance.sh` fuer deterministische State-Manipulation.
Claude fuehrt nur noch **einen einzigen Bash-Befehl** aus statt 3-4 manuelle jq-Befehle:

```bash
wf_advance.sh approve              # User approved → naechste Phase
wf_advance.sh feedback 'MESSAGE'   # User will Aenderungen → gleiche Phase nochmal
wf_advance.sh rollback 4 'MESSAGE'       # Rollback zu Phase 4 mit Feedback
wf_advance.sh rollback 3 --fast 'MESSAGE' # Fast Rollback (ueberspringt Tests+Security)
wf_advance.sh complete             # Workflow abschliessen (nach Push+PR)
```

Das Script uebernimmt: State-Update, Context-Cleanup, Spec-Cleanup, Prompt-Bau via `wf_prompt_builder.sh`,
und gibt eine `EXECUTE: Task(bytA:agent, 'prompt')` Anweisung aus die Claude direkt ausfuehrt.

### Advancing Guard (v4.0)

Waehrend Phase 0 (Team Planning) koennen mehrere SubagentStop-Events gleichzeitig den Stop-Hook
triggern. Die Lock-Datei `.workflow/.advancing` verhindert re-entrant Orchestrator-Aufrufe.

### Phase Skipping (v3.3.0)

Phase 0 (Architect im Team) kann Phasen als `"skipped"` markieren, wenn sie nicht benoetigt werden
(z.B. keine DB-Aenderungen → Phase 1 skippen). Der Orchestrator (`wf_orchestrator.sh`) erkennt
pre-geskippte Phasen und ueberspringt sie automatisch — auch ueber APPROVAL-Gates hinweg.

Skippbare Phasen: 1 (DB), 2 (Backend), 3 (Frontend).
Nicht skippbar: 0 (Spec), 4 (Tests), 5 (Security), 6 (Review), 7 (Push & PR).

### Scope-basiertes Phase Skipping (v4.4.0)

Beim Workflow-Start waehlt der User den Issue-Scope als 5. Startup-Frage:

| Scope | Phases uebersprungen | Specialists uebersprungen | Wann nutzen? |
|-------|---------------------|--------------------------|--------------|
| Full-Stack (default) | Architect entscheidet | Keine | Standard, alle Bereiche betroffen |
| Frontend-only | Phase 1 (DB) + Phase 2 (Backend) | Backend-Specialist | Nur Angular-Aenderungen |
| Backend-only | Phase 3 (Frontend) | Frontend + UI Designer | Nur Spring-Boot-Aenderungen |

Der Scope wird in `workflow-state.json` als `"scope"` Feld gespeichert. Die Phase Pre-Skips
werden deterministisch in SKILL.md VOR Phase 0 ausgefuehrt (jq-Befehle). `wf_prompt_builder.sh`
liest den Scope und spawnt nur die benoetigten Specialist-Agents in Phase 0.

Die Rollback-Reset-Logik (`wf_advance.sh`) unterscheidet zwischen Scope-Skips
(`reason: "Frontend-only scope"`) und Fast-Rollback-Skips (`reason: "fast-rollback"`).
Nur Fast-Rollback-Skips werden bei einem vollen Rollback zurueckgesetzt.

### Phase-Entry + Control Escape Fix (v4.5.0)

Behebt einen kritischen Bug bei dem der LLM nach Auto-Advance die Kontrolle uebernehmen konnte:

**Problem (Orbit #428):** Bei Auto-Advance wurde `currentPhase` gesetzt, aber `phases[$NEXT_PHASE]`
nicht initialisiert. Der Guard bei `wf_orchestrator.sh:542` fand keinen Eintrag → `exit 0` →
Ralph-Loop wurde komplett umgangen → LLM uebernahm Kontrolle → Endlos-Zyklen (6x Phase 3/4 Loop, 51 Min).

**3 Fixes:**
1. **Phase-Entry bei Auto-Advance:** Alle 3 Stellen die `currentPhase` setzen (Auto-Advance,
   Skip-Advance, Phase-Skip-Corrected) initialisieren jetzt auch `phases[$NEXT_PHASE]`.
2. **Guard-Fix:** Statt `exit 0` (LLM bekommt Kontrolle) wird die Phase initialisiert und
   die Ralph-Loop laeuft weiter.
3. **Re-Completion Guard:** `mark_phase_completed()` wird uebersprungen wenn die Phase
   bereits `completed` ist. Verhindert Endlos-Zyklen bei LLM-induzierter Phase-Reversion.

### Agent-Reports (MD-Dateien)

Jeder Agent schreibt eine MD-Datei in `.workflow/specs/` mit seinem vollstaendigen Report.
Downstream-Agents lesen diese Dateien selbst via Read-Tool (Boomerang: isolierter Context).
Der Orchestrator sieht nur den **Dateipfad** (wenige Bytes) — kein Context-Wachstum.

```
.workflow/specs/
├── issue-42-plan-consolidated.md          ← Consolidated Spec (v4.0 Team Planning)
├── issue-42-plan-backend.md               ← Backend Plan (Phase 0 Spoke)
├── issue-42-plan-frontend.md              ← Frontend Plan (Phase 0 Spoke)
├── issue-42-plan-quality.md               ← Quality Plan (Phase 0 Spoke)
├── issue-42-ph02-spring-boot-developer.md  ← Backend Report
├── issue-42-ph03-angular-frontend-developer.md ← Frontend Report
├── issue-42-ph04-test-engineer.md         ← Test Report
├── issue-42-ph05-security-auditor.md      ← Security Audit
└── issue-42-ph06-code-reviewer.md         ← Code Review
```

## Struktur

```
bytA/
├── .claude-plugin/plugin.json
├── .mcp.json                          # MCP Server (context7, angular-cli)
├── agents/                            # 10 spezialisierte Agents
│   ├── architect-planner.md
│   ├── ui-designer.md
│   ├── api-architect.md
│   ├── postgresql-architect.md
│   ├── spring-boot-developer.md
│   ├── angular-frontend-developer.md
│   ├── test-engineer.md
│   ├── security-auditor.md
│   ├── code-reviewer.md
│   └── architect-reviewer.md
├── commands/
│   ├── feature.md                     # /bytA:feature Entry Point
│   └── prd-generator.md               # /bytA:prd-generator Entry Point
├── config/
│   └── phases.conf                    # Deklarative Phase-Definition
├── docs/
│   └── REFACTORING-PROPOSAL-BOOMERANG-RALPH.md
├── hooks/
│   └── hooks.json                     # 9 Plugin-Level Hooks
├── scripts/
│   ├── wf_orchestrator.sh             # Stop Hook: Ralph-Loop Orchestrator
│   ├── wf_verify.sh                   # Externe Done-Verifikation
│   ├── wf_advance.sh                  # Deterministic Approval-Advance (v3.7.0)
│   ├── wf_prompt_builder.sh           # Deterministische Agent-Prompts
│   ├── wf_user_prompt.sh              # UserPromptSubmit: Approval Gates
│   ├── wf_cleanup.sh                  # Startup: Workflow aufraumen
│   ├── guard_git_push.sh              # PreToolUse: Push Guard
│   ├── block_orchestrator_code_edit.sh # PreToolUse: Code-Edit Blocker (v3.9.0)
│   ├── block_orchestrator_code_read.sh # PreToolUse: Code-Read Blocker (v3.9.0)
│   ├── block_orchestrator_explore.sh  # PreToolUse: Explore Blocker (v3.9.0)
│   ├── session_recovery.sh           # SessionStart: Recovery + Compact (v3.9.0)
│   ├── subagent_start.sh             # SubagentStart: Marker setzen (v3.9.0)
│   └── subagent_done.sh              # SubagentStop: WIP Commits + Marker Cleanup
├── skills/
│   ├── feature/
│   │   └── SKILL.md                   # Radikal vereinfacht (~170 Zeilen)
│   └── prd-generator/
│       └── SKILL.md                   # PRD Generator
└── README.md
```

## Unterschied zu byt8

| Aspekt | byt8 | bytA |
|--------|------|------|
| Orchestrator | Claude (LLM) mit SKILL.md | Bash-Script (wf_orchestrator.sh) |
| Done-Pruefung | LLM interpretiert Agent-Output | Shell prueft Dateien/Exit-Codes |
| Context-Wachstum | Monoton steigend | Konstant (~2.5 KB) |
| Retry-Logik | Stop Hook + Block Counter | Ralph-Loop (explicit retry) |
| Rollback | LLM fuehrt jq-Befehle aus | wf_advance.sh (deterministisch) |
| SKILL.md | ~270 Zeilen Orchestrator-Logik | ~170 Zeilen (Transport-Layer) |

## Troubleshooting

### Plugin pruefen

```bash
# 1. Cache leeren
rm -rf ~/.claude/plugins/cache/byteagenten-marketplace/

# 2. Claude starten, Hooks pruefen
claude
/hooks   # bytA-Hooks muessen sichtbar sein!
```

### Workflow laeuft nicht (Claude ignoriert SKILL.md)

Moegliche Ursachen:
1. **Plugin nicht installiert** → `/hooks` zeigt keine bytA-Hooks → Plugin neu installieren
2. **Plugin-Cache veraltet** → Cache leeren (siehe oben)
3. **Session nach Cache-Refresh nicht neu gestartet** → Hooks zeigen auf alten Pfad → Session komplett neu starten

### Hooks pruefen

Alle Hooks sind Plugin-Level (in `hooks.json`). Nach `/hooks` muessen diese sichtbar sein:
- Stop: `wf_orchestrator.sh`
- UserPromptSubmit: `wf_user_prompt.sh`
- PreToolUse/Bash: `guard_git_push.sh`
- PreToolUse/Edit|Write: `block_orchestrator_code_edit.sh`
- PreToolUse/Read: `block_orchestrator_code_read.sh`
- PreToolUse/Task: `block_orchestrator_explore.sh`
- SubagentStart: `subagent_start.sh`
- SubagentStop: `subagent_done.sh`
- SessionStart: `session_recovery.sh`

Verbose-Modus: `Ctrl+O` in Claude Code zeigt Hook-Ausgaben.
Debug-Modus: `claude --debug` zeigt detaillierte Hook-Ausfuehrung.

## Quellen

- [Boomerang Tasks — Roo Code](https://docs.roocode.com/features/boomerang-tasks)
- [Ralph Loop — Geoffrey Huntley](https://ghuntley.com/loop/)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
