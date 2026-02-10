# bytA Plugin

**Version 3.7.3** | Deterministic Orchestration: Boomerang + Ralph-Loop

Full-Stack Development Toolkit fuer Angular 21 + Spring Boot 4 mit deterministischem 10-Phasen-Workflow.

## Architektur

Der Orchestrator ist ein **Bash-Script**, kein LLM. Claude dient nur als Transport-Layer fuer Agent-Aufrufe.

| Prinzip | Bedeutung |
|---------|-----------|
| **Ralph-Loop** | `while !done; do spawn_agent; verify; done` — Externe Verifikation |
| **Boomerang** | Vollstaendige Kontext-Isolation pro Agent — kein Context Rot |
| **Deterministisch** | Shell-Scripts steuern, LLM fuehrt aus |

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

## Workflow

```
/bytA:feature #391
```

### Phasen

| Phase | Agent | Typ | Done-Kriterium |
|-------|-------|-----|----------------|
| 0 | architect-planner | APPROVAL | Spec-Datei existiert |
| 1 | ui-designer | APPROVAL | Issue-prefixed Wireframe HTML existiert |
| 2 | api-architect | AUTO | API-Spec existiert |
| 3 | postgresql-architect | AUTO | Migration SQL existiert |
| 4 | spring-boot-developer | AUTO | Backend-Report MD existiert |
| 5 | angular-frontend-developer | AUTO | Frontend-Report MD existiert |
| 6 | test-engineer | AUTO | allPassed == true + Report-Datei existiert |
| 7 | security-auditor | APPROVAL | Audit-Datei existiert |
| 8 | code-reviewer | APPROVAL | Review-Datei existiert |
| 9 | Push & PR | APPROVAL | PR URL in State |

**APPROVAL** = User muss approven (Workflow pausiert)
**AUTO** = Externe Verifikation, dann naechste Phase automatisch

### Ablauf-Diagramm

```
Phase 0 (Tech Spec) ──[User Approval]──→ Phase 1 (Wireframes)
                                              │
                                        [User Approval]
                                              │
                                              ▼
Phase 2 (API) → Phase 3 (DB) → Phase 4 (Backend) → Phase 5 (Frontend) → Phase 6 (Tests)
   AUTO           AUTO           AUTO                  AUTO                  AUTO
                                              │
                                              ▼
Phase 7 (Security) ──[User Approval]──→ Phase 8 (Review) ──[User Approval]──→ Phase 9 (PR)
```

### Rollback (Option C: Heuristik + User-Wahl)

Bei Phase 7/8 kann der User aendern lassen:
1. Shell-Script schlaegt Rollback-Ziel vor (basierend auf betroffenen Dateipfaden)
2. User bestaetigt oder waehlt anderes Ziel
3. State wird deterministisch bereinigt (alle downstream Phasen geloescht)
4. Auto-Advance laeuft automatisch bis zum naechsten Approval Gate

## Hook-Architektur

| Hook | Script | Funktion |
|------|--------|----------|
| **Stop** | `wf_orchestrator.sh` | Ralph-Loop: Verify → Advance/Retry → Agent-Dispatch |
| **UserPromptSubmit** | `wf_user_prompt.sh` | Approval Gate Context + Rollback-Optionen |
| **PreToolUse/Bash** | `guard_git_push.sh` | Blockiert Push ohne pushApproved |
| **SubagentStop** | `subagent_done.sh` | Deterministische WIP-Commits |
| **SessionStart** | `session_recovery.sh` | Context Overflow Recovery |

**Skill-Level Hooks (in SKILL.md Frontmatter):**

| Hook | Script | Funktion |
|------|--------|----------|
| **PreToolUse/Bash** | `once: true` (inline) | Session-Marker automatisch setzen |
| **PreToolUse/Edit\|Write** | `block_orchestrator_code_edit.sh` | Orchestrator darf keinen Code aendern |
| **PreToolUse/Read** | `block_orchestrator_code_read.sh` | Orchestrator darf keinen Code lesen |
| **PreToolUse/Task** | `block_orchestrator_explore.sh` | Orchestrator darf nicht explorieren |

## Agents

| Agent | Phase | Aufgabe |
|-------|-------|---------|
| architect-planner | 0 | Technical Specification, 5x Warum, Architektur |
| ui-designer | 1 | HTML Wireframes mit Angular Material + data-testid |
| api-architect | 2 | REST API Design (Markdown-Sketch, kein YAML) |
| postgresql-architect | 3 | Flyway SQL Migrations, Schema, Indexes |
| spring-boot-developer | 4 | Spring Boot 4 Backend (Controller, Service, Tests) |
| angular-frontend-developer | 5 | Angular 21 Frontend (Signals, Standalone Components) |
| test-engineer | 6 | E2E + Integration Tests (Playwright, JUnit, Jasmine) |
| security-auditor | 7 | OWASP Top 10 Security Audit |
| code-reviewer | 8 | Code Quality Gate (SOLID, Coverage, Architecture) |
| architect-reviewer | - | Eskalation bei Architektur-Concerns |

## Externe Verifikation (kein LLM!)

Done-Kriterien werden von `wf_verify.sh` extern geprueft:

| Phase | Pruefung | Methode |
|-------|----------|---------|
| 0 | Spec-Datei | `ls .workflow/specs/*-ph00-*.md` |
| 1 | Wireframe | `ls wireframes/issue-*.html` |
| 2 | API-Spec | `ls .workflow/specs/*-ph02-*.md` |
| 3 | Migration | `ls backend/.../V*.sql` |
| 4 | Backend-Report | `ls .workflow/specs/*-ph04-*.md` |
| 5 | Frontend-Report | `ls .workflow/specs/*-ph05-*.md` |
| 6 | Tests bestanden | `jq .context.testResults.allPassed` + `ls .workflow/specs/*-ph06-*.md` |
| 7 | Audit-Datei | `ls .workflow/specs/*-ph07-*.md` |
| 8 | Review-Datei | `ls .workflow/specs/*-ph08-*.md` |
| 9 | PR URL | `jq .phases["9"].prUrl` |

### Compound-Kriterien (v3.3.0)

Phase 6 nutzt ein Compound-Kriterium (`+` Separator): STATE und GLOB muessen BEIDE bestanden werden.
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

Alle Approval-Phasen (0, 1, 7, 8, 9) nutzen `wf_advance.sh` fuer deterministische State-Manipulation.
Claude fuehrt nur noch **einen einzigen Bash-Befehl** aus statt 3-4 manuelle jq-Befehle:

```bash
wf_advance.sh approve              # User approved → naechste Phase
wf_advance.sh feedback 'MESSAGE'   # User will Aenderungen → gleiche Phase nochmal
wf_advance.sh rollback 4 'MESSAGE' # Rollback zu Phase 4 mit Feedback
wf_advance.sh complete             # Workflow abschliessen (nach Push+PR)
```

Das Script uebernimmt: State-Update, Context-Cleanup, Spec-Cleanup, Prompt-Bau via `wf_prompt_builder.sh`,
und gibt eine `EXECUTE: Task(bytA:agent, 'prompt')` Anweisung aus die Claude direkt ausfuehrt.

### Phase Skipping (v3.3.0)

Phase 0 (architect-planner) kann Phasen als `"skipped"` markieren, wenn sie nicht benoetigt werden
(z.B. keine DB-Aenderungen → Phase 3 skippen). Der Orchestrator (`wf_orchestrator.sh`) erkennt
pre-geskippte Phasen und ueberspringt sie automatisch — auch ueber APPROVAL-Gates hinweg.

Skippbare Phasen: 1 (Wireframes), 2 (API), 3 (DB), 4 (Backend), 5 (Frontend).
Nicht skippbar: 0 (Spec), 6 (Tests), 7 (Security), 8 (Review), 9 (Push & PR).

### Agent-Reports (MD-Dateien)

Jeder Agent schreibt eine MD-Datei in `.workflow/specs/` mit seinem vollstaendigen Report.
Downstream-Agents lesen diese Dateien selbst via Read-Tool (Boomerang: isolierter Context).
Der Orchestrator sieht nur den **Dateipfad** (wenige Bytes) — kein Context-Wachstum.

```
.workflow/specs/
├── issue-42-ph00-architect-planner.md     ← Technical Spec
├── issue-42-ph02-api-architect.md         ← API Design
├── issue-42-ph03-postgresql-architect.md   ← Database Design
├── issue-42-ph04-spring-boot-developer.md  ← Backend Report
├── issue-42-ph05-angular-frontend-developer.md ← Frontend Report
├── issue-42-ph06-test-engineer.md         ← Test Report
├── issue-42-ph07-security-auditor.md      ← Security Audit
└── issue-42-ph08-code-reviewer.md         ← Code Review
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
│   └── feature.md                     # /bytA:feature Entry Point
├── config/
│   └── phases.conf                    # Deklarative Phase-Definition
├── docs/
│   └── REFACTORING-PROPOSAL-BOOMERANG-RALPH.md
├── hooks/
│   └── hooks.json                     # 5 Plugin-Level Hooks
├── scripts/
│   ├── wf_orchestrator.sh             # Stop Hook: Ralph-Loop Orchestrator
│   ├── wf_verify.sh                   # Externe Done-Verifikation
│   ├── wf_advance.sh                  # Deterministic Approval-Advance (v3.7.0)
│   ├── wf_prompt_builder.sh           # Deterministische Agent-Prompts
│   ├── wf_user_prompt.sh              # UserPromptSubmit: Approval Gates
│   ├── wf_cleanup.sh                  # Startup: Workflow aufraumen
│   ├── guard_git_push.sh              # PreToolUse: Push Guard
│   ├── block_orchestrator_code_edit.sh # PreToolUse: Code-Edit Blocker
│   ├── block_orchestrator_code_read.sh # PreToolUse: Code-Read Blocker
│   ├── block_orchestrator_explore.sh  # PreToolUse: Explore Blocker
│   └── subagent_done.sh              # SubagentStop: WIP Commits
├── skills/
│   └── feature/
│       └── SKILL.md                   # Radikal vereinfacht (~170 Zeilen)
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
3. **Skill-Hooks laden nicht** → PreToolUse auf Edit muss `.html` blockieren

### Hooks pruefen

Wenn `/bytA:feature` ausgefuehrt wird, muessen diese Hooks aktiv sein:
- Stop Hook: `wf_orchestrator.sh` (plugin-level)
- PreToolUse/Bash: Session-Marker `once:true` (skill-level)
- PreToolUse/Edit|Write: `block_orchestrator_code_edit.sh` (skill-level)
- PreToolUse/Read: `block_orchestrator_code_read.sh` (skill-level)
- PreToolUse/Task: `block_orchestrator_explore.sh` (skill-level)

Verbose-Modus: `Ctrl+O` in Claude Code zeigt Hook-Ausgaben.
Debug-Modus: `claude --debug` zeigt detaillierte Hook-Ausfuehrung.

## Quellen

- [Boomerang Tasks — Roo Code](https://docs.roocode.com/features/boomerang-tasks)
- [Ralph Loop — Geoffrey Huntley](https://ghuntley.com/loop/)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
