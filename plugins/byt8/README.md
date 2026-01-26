# byt8 Plugin

Full-Stack Development Toolkit für Angular 21 + Spring Boot 4 Anwendungen.

> **Version 4.1.0** - Hook-basierte Workflow Engine mit automatischer Context Recovery

## Philosophy

> "Qualität durch Struktur: Jede Phase wird abgeschlossen, bevor die nächste beginnt."

Dieses Plugin orchestriert spezialisierte Agents durch einen strukturierten Entwicklungs-Workflow mit Quality Gates, automatischen Tests und User Approvals.

---

## Installation

```bash
# In Claude Code
/plugins install byt8@byteagenten-marketplace
```

Oder manuell in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "byteagenten-marketplace": {
      "source": { "source": "github", "repo": "byteAgenten/byteagenten-marketplace" }
    }
  },
  "enabledPlugins": { "byt8@byteagenten-marketplace": true }
}
```

**Nach Installation:** Claude Code neu starten (MCP Server werden geladen).

---

## Commands

### Feature Development

| Command | Beschreibung |
|---------|--------------|
| `/byt8:full-stack-feature` | 9-Phasen Workflow für Full-Stack Features |
| `/byt8:ui-theming` | Einmalige Design System Initialisierung |
| `/byt8:python-expert` | Python Development Support |

**Beispiele:**

```bash
/byt8:full-stack-feature #42                    # Mit GitHub Issue
/byt8:full-stack-feature #42 --from=develop     # Branch explizit
/byt8:full-stack-feature "Logout Button"        # Ohne Issue
```

### Workflow Control

| Command | Beschreibung |
|---------|--------------|
| `/wf:status` | Detaillierten Workflow-Status anzeigen |
| `/wf:pause` | Workflow pausieren |
| `/wf:resume` | Pausierten Workflow fortsetzen |
| `/wf:retry-reset` | Retry-Counter zurücksetzen |
| `/wf:skip` | Phase überspringen (nicht empfohlen) |

---

## Der 9-Phasen Workflow

| Phase | Agent | Aufgabe | Gate |
|-------|-------|---------|------|
| 0 | architect-planner | Technical Specification | ✋ Approval |
| 1 | ui-designer | Wireframes (HTML) | ✋ Approval |
| 2 | api-architect | API Design (OpenAPI 3.1) | |
| 3 | postgresql-architect | Database Migrations (Flyway) | |
| 4 | spring-boot-developer | Backend + Tests | 🔄 Auto-Retry |
| 5 | angular-frontend-developer | Frontend + Tests | 🔄 Auto-Retry |
| 6 | test-engineer + security-auditor | E2E Tests + Security | ✋ Approval |
| 7 | code-reviewer | Code Review | ✋ Approval |
| 8 | (Orchestrator) | Push & PR erstellen | ✋ Final |

**Legende:**
- ✋ Approval = Workflow pausiert für User-Feedback
- 🔄 Auto-Retry = Bei Test-Fehlern max. 3 Versuche, dann Pause

---

## Hook-basierte Workflow Engine

Das Plugin verwendet **Hooks** für automatische Workflow-Orchestrierung. Hooks sind Shell-Scripts, die bei bestimmten Events ausgeführt werden.

### Registrierte Hooks

| Event | Script | Funktion |
|-------|--------|----------|
| `SessionStart` | `session_recovery.sh` | Context Recovery nach Overflow |
| `Stop` (TodoWrite) | `wf_engine.sh` | Phase Validation, Auto-Commits |
| `SubagentStop` | `subagent_done.sh` | Subagent Output Validation |

### Workflow Engine (`wf_engine.sh`)

Feuert nach jedem Tool-Call und bietet:

- **Phase Validation** - Automatische Done-Checks:
  - Phase 0: Tech Spec im Context?
  - Phase 1: Wireframes in `wireframes/`?
  - Phase 4: `mvn test` PASS?
  - Phase 5: `npm test` PASS?
  - Phase 6: Playwright PASS?

- **Auto-Commits** - WIP-Commits nach erfolgreichen Phasen:
  ```
  wip(#42/phase-4): Backend done - User Authentication
  ```

- **Retry-Management** - Max 3 Versuche für Test-Phasen (4, 5, 6)

- **Approval Gates** - Automatische Pausen nach Phase 0, 1, 6, 7

### Context Recovery (`session_recovery.sh`)

Bei **Context Overflow** wird automatisch:

1. Aktiver Workflow erkannt
2. Alle Phasen-Kontexte aus `.workflow/context/` geladen
3. Nächster Schritt + Phase-Regeln angezeigt
4. `/byt8:full-stack-feature` zum Fortsetzen empfohlen

### Subagent Validation (`subagent_done.sh`)

Validiert Outputs wenn ein Subagent fertig ist:

| Agent | Validation |
|-------|------------|
| architect-planner | Tech Spec im Context? |
| ui-designer | Wireframes + data-testid? |
| spring-boot-developer | `mvn compile` OK? |
| angular-frontend-developer | `npm run build` OK? |
| test-engineer | E2E Test-Dateien vorhanden? |

---

## State Management

Der Workflow-State wird in `.workflow/` persistiert:

```
.workflow/
├── workflow-state.json      # Hauptstatus (Phase, Issue, nextStep)
├── context/
│   ├── phase-0-spec.json    # Tech Spec Summary
│   ├── phase-1-wireframes.json
│   ├── phase-2-api.json
│   └── ...
├── recovery/
│   ├── retry-tracker.json   # Retry-Counter pro Phase
│   └── last-checkpoint.json
└── logs/
    └── transitions.jsonl    # Phase-Transitions Log
```

---

## MCP Server

Das Plugin installiert automatisch:

| Server | Beschreibung |
|--------|--------------|
| `context7` | Aktuelle Library-Dokumentation ([Upstash](https://github.com/upstash/context7)) |
| `angular-cli` | Angular CLI Integration |

### Context7 API-Key (optional)

Für höhere Rate Limits:

```bash
# In ~/.bashrc oder ~/.zshrc:
export CONTEXT7_API_KEY=ctx7sk-dein-key-hier
```

---

## Agents

| Agent | Spezialisierung |
|-------|-----------------|
| `architect-planner` | Technical Specs, 5x Warum Analyse |
| `api-architect` | OpenAPI 3.1, REST API Design |
| `angular-frontend-developer` | Angular 21, Signals, TypeScript |
| `spring-boot-developer` | Spring Boot 4, Java 21, JPA |
| `postgresql-architect` | Schema Design, Flyway Migrations |
| `test-engineer` | JUnit 5, Jasmine, Playwright |
| `ui-designer` | Wireframes, Design Tokens |
| `security-auditor` | OWASP Top 10 |
| `code-reviewer` | Code Quality |
| `architect-reviewer` | Architecture Decisions |

---

## Plugin-Struktur

```
byt8/
├── .claude-plugin/
│   └── plugin.json          # Metadata (v4.1.0)
├── agents/                  # 10 spezialisierte Agents
├── commands/                # Slash Commands
│   ├── full-stack-feature.md
│   ├── ui-theming.md
│   └── wf-*.md              # Workflow Control
├── hooks/
│   └── hooks.json           # Hook-Definitionen
├── scripts/
│   ├── session_recovery.sh
│   ├── wf_engine.sh
│   └── subagent_done.sh
├── skills/
│   ├── full-stack-feature/
│   ├── ui-theming/
│   └── ui-design/
└── README.md
```

---

## Technologie-Stack

- **Backend:** Spring Boot 4.0+, Java 21+, PostgreSQL
- **Frontend:** Angular 21+, TypeScript, SCSS
- **Testing:** JUnit 5, Jasmine, Playwright
- **API:** OpenAPI 3.1, REST
- **Database:** PostgreSQL, Flyway Migrations

---

## License

MIT
