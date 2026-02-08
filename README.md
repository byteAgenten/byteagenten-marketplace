# byteAgenten Plugin Marketplace

Private Claude Code Plugins for byteAgenten team members.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [byt8](./plugins/byt8) | Full-stack development toolkit for Angular 21 + Spring Boot 4 | 7.5.7 |
| [bytA](./plugins/bytA) | Deterministic full-stack workflow (Boomerang + Ralph-Loop) | 3.6.1 |

## Prerequisites

### 1. GitHub-Zugang zur byteAgenten Organisation

Du brauchst Zugriff auf das private Repository `byteAgenten/byteagenten-marketplace`.

### 2. GitHub Token konfigurieren

**Option A: GitHub CLI (empfohlen)**

Die [GitHub CLI](https://cli.github.com/) (`gh`) ist ein Kommandozeilen-Tool für GitHub.

```bash
# Installation (macOS)
brew install gh

# Installation (Windows)
winget install GitHub.cli

# Einmalig anmelden - öffnet Browser zur Authentifizierung
gh auth login
```

**Option B: Personal Access Token (PAT)**

1. Gehe zu [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Klicke "Generate new token (classic)"
3. Wähle Scope: `repo` (Full control of private repositories)
4. Token kopieren (beginnt mit `ghp_`)
5. In Shell exportieren:

```bash
# In ~/.bashrc oder ~/.zshrc einfügen:
export GITHUB_TOKEN=ghp_dein_token_hier
```

## Installation

### Option 1: Via Claude Code (empfohlen)

In Claude Code eingeben:

```bash
# Marketplace registrieren
/plugin marketplace add byteAgenten/byteagenten-marketplace

# Plugin installieren
/plugin install byt8@byteagenten-marketplace
```

**Erklärung:**
- `byteAgenten` = GitHub Organisation (Owner des Repositories)
- `byteagenten-marketplace` = Name des Repositories auf GitHub
- `byt8` = Name des Plugins
- `@byteagenten-marketplace` = aus welchem Marketplace das Plugin kommt

### Option 2: Manuelle Konfiguration

Füge in deinem Projekt `.claude/settings.json` hinzu:

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

### Option 3: Bestimmte Version pinnen

Falls du eine feste Version verwenden möchtest:

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

| Command | Description |
|---------|-------------|
| `/byt8:full-stack-feature` | 10-phase workflow for full-stack feature development |
| `/byt8:ui-theming` | One-time design system initialization (theme, tokens, typography) |
| `/byt8:python-expert` | Python development support |
| `/byt8:prd-generator` | Generate PRDs (user stories, requirements) and create GitHub Issues |

→ Details und Beispiele siehe [byt8 README](./plugins/byt8/README.md)

## Plugin Architecture

Each plugin is independently installable and versioned:

```
byteagenten-marketplace/
├── .claude-plugin/
│   └── marketplace.json       # Plugin registry
├── plugins/
│   └── byt8/                  # Full-stack development toolkit
│       ├── .claude-plugin/
│       │   └── plugin.json    # Plugin metadata & version
│       ├── .mcp.json          # MCP server configuration
│       ├── agents/            # 10 specialized agents
│       ├── commands/          # 10 slash commands
│       ├── hooks/             # Workflow hooks (hooks.json)
│       ├── scripts/           # Hook scripts (bash)
│       ├── skills/            # Workflow implementations (SKILL.md)
│       └── README.md
├── CLAUDE.md                  # Project instructions for Claude Code
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
