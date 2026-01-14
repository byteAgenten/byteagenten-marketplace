# byteAgenten Plugin Marketplace

Private Claude Code Plugins for byteAgenten team members.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [bytagnt-fullstack](./bytagnt-fullstack) | Full-stack development toolkit for Angular 21 + Spring Boot 4 | 1.0.0 |

## Prerequisites

1. GitHub access to byteAgenten organization
2. GitHub token set: `export GITHUB_TOKEN=ghp_xxx` (or use `gh auth login`)

## Installation

### Option 1: Manual Configuration (Recommended)

Add this to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "bytagnt-fullstack": {
      "source": {
        "source": "github",
        "repo": "byteAgenten/byteagenten-marketplace",
        "path": "bytagnt-fullstack"
      }
    }
  },
  "enabledPlugins": {
    "bytagnt-fullstack@bytagnt-fullstack": true
  }
}
```

### Option 2: Pin to Specific Version

```json
{
  "extraKnownMarketplaces": {
    "bytagnt-fullstack": {
      "source": {
        "source": "github",
        "repo": "byteAgenten/byteagenten-marketplace",
        "ref": "v1.0.0",
        "path": "bytagnt-fullstack"
      }
    }
  },
  "enabledPlugins": {
    "bytagnt-fullstack@bytagnt-fullstack": true
  }
}
```

## Available Commands

After installation, the following commands are available:

| Command | Description |
|---------|-------------|
| `/bytagnt-fullstack:full-stack-feature` | 10-phase workflow for full-stack feature development |
| `/bytagnt-fullstack:project-setup` | One-time design system initialization |
| `/bytagnt-fullstack:theme-factory` | Apply themes to artifacts (slides, docs, etc.) |
| `/bytagnt-fullstack:ui-design-system` | UI design system toolkit |
| `/bytagnt-fullstack:ux-researcher-designer` | UX research and design methodology |
| `/bytagnt-fullstack:python-expert` | Python development support |

## Plugin Architecture

Each plugin is independently installable and versioned:

```
byteagenten-marketplace/
├── marketplace.json           # Plugin registry
├── bytagnt-fullstack/         # Full-stack development
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/                # 10 specialized agents
│   ├── commands/              # 6 slash commands
│   └── skills/                # Workflow implementations
├── bytagnt-docs/              # (planned)
└── bytagnt-design/            # (planned)
```

## Adding New Plugins

1. Create a new folder: `bytagnt-[name]/`
2. Add `.claude-plugin/plugin.json` with unique name
3. Add commands, agents, and skills
4. Update root `marketplace.json`
5. Create PR for review

## License

Proprietary - byteAgenten internal use only.
