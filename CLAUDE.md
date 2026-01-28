# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⛔⛔⛔ REGEL #1: DOKUMENTATION LESEN - KEINE AUSNAHMEN! ⛔⛔⛔

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   DEIN TRAININGS-WISSEN IST VERALTET UND UNZUVERLÄSSIG!                   │
│                                                                             │
│   Du MUSST die offizielle Claude Code Dokumentation via WebFetch lesen,    │
│   BEVOR du Änderungen an diesem Repository vorschlägst oder durchführst.   │
│                                                                             │
│   Das gilt für JEDE Änderung an:                                           │
│   - Hooks (hooks.json, Frontmatter-Hooks, Scripts)                        │
│   - Skills (SKILL.md, Frontmatter-Format)                                 │
│   - Agents (agents/*.md, Frontmatter-Format)                              │
│   - Plugin-Struktur (plugin.json, marketplace.json)                       │
│   - Settings (settings.json, Konfiguration)                               │
│                                                                             │
│   ABLAUF:                                                                  │
│   1. Thema identifizieren (z.B. "Hooks ändern")                           │
│   2. Passende Doku-URL aus der Tabelle unten auswählen                    │
│   3. WebFetch aufrufen und Doku LESEN                                     │
│   4. ERST DANN planen und implementieren                                  │
│                                                                             │
│   WENN DU DAS IGNORIERST:                                                 │
│   - Du wirst falsche Annahmen treffen (ist bereits passiert!)             │
│   - Du wirst nicht-existierende Features nutzen                           │
│   - Du wirst Bugs einbauen die schwer zu finden sind                      │
│   - Der User muss dich korrigieren und Zeit verschwenden                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Thema | Doku-URL |
|-------|----------|
| Hooks (PreToolUse, Stop, etc.) | https://code.claude.com/docs/en/hooks |
| Hooks Guide (Beispiele) | https://code.claude.com/docs/en/hooks-guide |
| Plugins (Struktur, Manifest) | https://code.claude.com/docs/en/plugins |
| Plugin-Referenz (Details) | https://code.claude.com/docs/en/plugins-reference |
| Skills (SKILL.md, Frontmatter) | https://code.claude.com/docs/en/skills |
| Subagents (Task, Agents) | https://code.claude.com/docs/en/sub-agents |
| Settings (settings.json) | https://code.claude.com/docs/en/settings |

---

## Project Overview

This is the **byteAgenten Plugin Marketplace** - a private Claude Code plugin repository. The main plugin is **byt8**, a full-stack development toolkit for Angular 21 + Spring Boot 4 applications with a 10-phase workflow.

## Architecture

### Marketplace Structure

```
byteagenten-marketplace/
├── .claude-plugin/
│   └── marketplace.json      # Registry: lists all plugins with their commands, agents, skills
├── plugins/
│   └── byt8/                 # Main plugin
│       ├── .claude-plugin/
│       │   └── plugin.json   # Plugin metadata (name, version, description)
│       ├── agents/           # 10 specialized AI agents
│       ├── commands/         # Slash command definitions (map to skills)
│       ├── hooks/            # Plugin hooks (event-driven scripts)
│       ├── scripts/          # Helper scripts for hooks
│       └── skills/           # Workflow implementations (SKILL.md files)
```

### Key Relationships

- **Commands** (`commands/*.md`) = Entry points, invoke skills
- **Skills** (`skills/*/SKILL.md`) = Workflow logic with detailed instructions
- **Agents** (`agents/*.md`) = Specialized AI personas for specific tasks

### The Workflow (full-stack-feature)

The main workflow orchestrates these agents in a 10-phase sequence:

| Phase | Agent | Purpose |
|-------|-------|---------|
| 0 | architect-planner | Technical specification |
| 1 | ui-designer | Wireframes |
| 2 | api-architect | API design (OpenAPI 3.1) |
| 3 | postgresql-architect | Database migrations (Flyway) |
| 4 | spring-boot-developer | Backend implementation |
| 5 | angular-frontend-developer | Frontend implementation |
| 6 | test-engineer | E2E tests |
| 7 | security-auditor | Security audit |
| 8 | code-reviewer | Code review |
| 9 | (orchestrator) | Push & PR erstellen |

### Workflow State Management

State is persisted in `.workflow/workflow-state.json` with:
- `currentPhase`: Current workflow phase
- `nextStep`: Allowed next action (for validation)
- `context`: Phase outputs for downstream agents

## Available Commands

| Command | Description |
|---------|-------------|
| `/byt8:full-stack-feature` | 10-phase workflow for full-stack feature development |
| `/byt8:ui-theming` | Design system initialization (theme, tokens, typography) |
| `/byt8:python-expert` | Python development support |

## Release-Checkliste (bei Version-Bump)

Bei JEDEM Version-Bump von `plugin.json` MÜSSEN diese Dateien synchron aktualisiert werden:

1. `plugins/byt8/.claude-plugin/plugin.json` → `"version": "X.Y.Z"`
2. `plugins/byt8/README.md` → `**Version X.Y.Z**` (Zeile 3)
3. `README.md` → Versions-Spalte in der Plugin-Tabelle (Zeile 9)

**Niemals nur plugin.json bumpen und die READMEs vergessen!**

## Development

### Testing Plugins Locally

Clear the plugin cache after changes:
```bash
rm -rf ~/.claude/plugins/cache/byteagenten-marketplace/
```

### Plugin Hooks

Hooks werden in `plugins/byt8/hooks/hooks.json` definiert. Verfügbare Events:
- `SessionStart` - Bei Session-Start/Resume (für Workflow-Recovery)
- `PreCompact` - Vor Context-Komprimierung

Scripts in `plugins/byt8/scripts/` können via `${CLAUDE_PLUGIN_ROOT}` referenziert werden.

### Adding a New Agent

1. Create `plugins/byt8/agents/[name].md` with frontmatter (name, description, version)
2. Add to `.claude-plugin/marketplace.json` under `agents` array

### Adding a New Skill

1. Create folder `plugins/byt8/skills/[name]/`
2. Add `SKILL.md` with frontmatter (name, description, version)
3. Create matching command in `plugins/byt8/commands/[name].md`
4. Update `.claude-plugin/marketplace.json`

## Installation (for Users)

Add to project's `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "byteagenten-marketplace": {
      "source": {
        "source": "github",
        "repo": "byteAgenten/byteagenten-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "byt8@byteagenten-marketplace": true
  }
}
```
