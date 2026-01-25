# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⛔⛔⛔ WORKFLOW RECOVERY - LIES DAS ZUERST! ⛔⛔⛔

**Kommst du aus einem Context Overflow / Session Resume?**

Dein Summary ist UNVOLLSTÄNDIG! Es fehlen die Workflow-Regeln.

**DU MUSST JETZT:**

1. ⛔ SOFORT `/byt8:full-stack-feature` aufrufen!
2. Der Skill prüft den State und lädt ALLE Regeln
3. NICHT selbst den State lesen oder interpretieren!

**WENN DU DAS IGNORIERST:**
- Du wirst falsche Entscheidungen treffen
- Du wirst Phasen überspringen
- Du wirst Approval Gates vergessen
- Der User wird frustriert sein

**KEIN WEITERMACHEN AUS DEM SUMMARY!**

---

## Project Overview

This is the **byteAgenten Plugin Marketplace** - a private Claude Code plugin repository. The main plugin is **byt8**, a full-stack development toolkit for Angular 21 + Spring Boot 4 applications with a 9-phase workflow.

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
│       └── skills/           # Workflow implementations (SKILL.md files)
```

### Key Relationships

- **Commands** (`commands/*.md`) = Entry points, invoke skills
- **Skills** (`skills/*/SKILL.md`) = Workflow logic with detailed instructions
- **Agents** (`agents/*.md`) = Specialized AI personas for specific tasks

### The 10-Phase Workflow (full-stack-feature)

The main workflow orchestrates these agents in sequence:

| Phase | Agent | Purpose |
|-------|-------|---------|
| 0 | architect-planner | Technical specification |
| 1 | ui-designer | Wireframes |
| 2 | api-architect | API design (OpenAPI 3.1) |
| 3 | postgresql-architect | Database migrations (Flyway) |
| 4 | spring-boot-developer | Backend implementation |
| 5 | angular-frontend-developer | Frontend implementation |
| 6 | test-engineer + security-auditor | E2E tests + security audit |
| 7 | code-reviewer | Code review |
| 8 | (orchestrator) | Push & PR erstellen |

### Workflow State Management

State is persisted in `.workflow/workflow-state.json` with:
- `currentPhase`: Current workflow phase
- `nextStep`: Allowed next action (for validation)
- `context`: Phase outputs for downstream agents

## Available Commands

| Command | Description |
|---------|-------------|
| `/byt8:full-stack-feature` | 9-phase workflow for full-stack feature development |
| `/byt8:ui-theming` | Design system initialization (theme, tokens, typography) |
| `/byt8:python-expert` | Python development support |

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
