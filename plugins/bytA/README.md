# bytA Plugin

**Version 3.0.0** | Deterministic Orchestration: Boomerang + Ralph-Loop

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
| 1 | ui-designer | APPROVAL | Wireframe HTML existiert |
| 2 | api-architect | AUTO | API-Spec existiert |
| 3 | postgresql-architect | AUTO | Migration SQL existiert |
| 4 | spring-boot-developer | AUTO | backendImpl in State |
| 5 | angular-frontend-developer | AUTO | frontendImpl in State |
| 6 | test-engineer | AUTO | allPassed == true |
| 7 | security-auditor | APPROVAL | Audit-Datei existiert |
| 8 | code-reviewer | APPROVAL | userApproved == true |
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

**Skill-Level Hooks (in SKILL.md Frontmatter):**

| Hook | Script | Funktion |
|------|--------|----------|
| **PreToolUse/Edit\|Write** | `block_orchestrator_code_edit.sh` | Orchestrator darf keinen Code aendern |
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
| 1 | Wireframe | `ls wireframes/*.html` |
| 2 | API-Spec | `ls .workflow/specs/*-ph02-*.md` |
| 3 | Migration | `ls backend/.../V*.sql` |
| 4 | Backend State | `jq .context.backendImpl` |
| 5 | Frontend State | `jq .context.frontendImpl` |
| 6 | Tests bestanden | `jq .context.testResults.allPassed` |
| 7 | Audit-Datei | `ls .workflow/specs/*-ph07-*.md` |
| 8 | User approved | `jq .context.reviewFeedback.userApproved` |
| 9 | PR URL | `jq .phases["9"].prUrl` |

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
│   └── hooks.json                     # 4 Plugin-Level Hooks
├── scripts/
│   ├── wf_orchestrator.sh             # Stop Hook: Ralph-Loop Orchestrator
│   ├── wf_verify.sh                   # Externe Done-Verifikation
│   ├── wf_prompt_builder.sh           # Deterministische Agent-Prompts
│   ├── wf_user_prompt.sh              # UserPromptSubmit: Approval Gates
│   ├── wf_cleanup.sh                  # Startup: Workflow aufraumen
│   ├── guard_git_push.sh              # PreToolUse: Push Guard
│   ├── block_orchestrator_code_edit.sh # PreToolUse: Code-Edit Blocker
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
| Rollback | LLM fuehrt jq-Befehle aus | Shell-Script (deterministisch) |
| SKILL.md | ~270 Zeilen Orchestrator-Logik | ~170 Zeilen (Transport-Layer) |

## Quellen

- [Boomerang Tasks — Roo Code](https://docs.roocode.com/features/boomerang-tasks)
- [Ralph Loop — Geoffrey Huntley](https://ghuntley.com/loop/)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
