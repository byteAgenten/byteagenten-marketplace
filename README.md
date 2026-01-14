# byteAgenten Plugin Marketplace

Private Claude Code Plugins for byteAgenten team members.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [byt8](./plugins/byt8) | Full-stack development toolkit for Angular 21 + Spring Boot 4 | 1.0.0 |

## Prerequisites

1. GitHub access to byteAgenten organization
2. GitHub token set: `export GITHUB_TOKEN=ghp_xxx` (or use `gh auth login`)

## Installation

### Option 1: Manual Configuration (Recommended)

Add this to your project's `.claude/settings.json`:

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

### Option 2: Pin to Specific Version

```json
{
  "extraKnownMarketplaces": {
    "byteagenten-marketplace": {
      "source": {
        "source": "github",
        "repo": "byteAgenten/byteagenten-marketplace",
        "ref": "v1.0.0"
      }
    }
  },
  "enabledPlugins": {
    "byt8@byteagenten-marketplace": true
  }
}
```

## Available Commands

After installation, the following commands are available:

| Command | Description |
|---------|-------------|
| `/byt8:full-stack-feature` | 10-phase workflow for full-stack feature development |
| `/byt8:project-setup` | One-time design system initialization |
| `/byt8:theme-factory` | Apply themes to artifacts (slides, docs, etc.) |
| `/byt8:ui-design-system` | UI design system toolkit |
| `/byt8:ux-researcher-designer` | UX research and design methodology |
| `/byt8:python-expert` | Python development support |

## Plugin Architecture

Each plugin is independently installable and versioned:

```
byteagenten-marketplace/
├── .claude-plugin/
│   └── marketplace.json       # Plugin registry
├── plugins/
│   ├── byt8/                  # Full-stack development
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── agents/            # 10 specialized agents
│   │   ├── commands/          # 6 slash commands
│   │   └── skills/            # Workflow implementations
│   ├── byt8-docs/             # (planned)
│   └── byt8-design/           # (planned)
└── README.md
```

## Adding New Plugins

1. Create a new folder: `plugins/byt8-[name]/`
2. Add `.claude-plugin/plugin.json` with unique name
3. Add commands, agents, and skills
4. Update `.claude-plugin/marketplace.json`
5. Create PR for review

## License

Proprietary - byteAgenten internal use only.
