# byteAgenten Plugin Marketplace

Private Claude Code Plugins for byteAgenten team members.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [byt8](./plugins/byt8) | Full-stack development toolkit for Angular 21 + Spring Boot 4 | 4.1.0 |

## Prerequisites

### 1. GitHub-Zugang zur byteAgenten Organisation

Du brauchst Zugriff auf das private Repository `byteAgenten/byteagenten-marketplace`.

### 2. GitHub Token konfigurieren

**Option A: GitHub CLI (empfohlen)**

```bash
brew install gh      # macOS
gh auth login        # Browser-Auth
```

**Option B: Personal Access Token (PAT)**

1. [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Scope: `repo`
3. Token exportieren:

```bash
export GITHUB_TOKEN=ghp_dein_token_hier
```

## Installation

### Via Claude Code (empfohlen)

```bash
/plugin marketplace add byteAgenten/byteagenten-marketplace
/plugin install byt8@byteagenten-marketplace
```

### Manuelle Konfiguration

In `.claude/settings.json`:

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

## Plugin-Dokumentation

Siehe [byt8 README](./plugins/byt8/README.md) für:

- Commands (`/byt8:full-stack-feature`, `/wf:status`, etc.)
- 9-Phasen Workflow mit Approval Gates
- Hook-basierte Workflow Engine
- MCP Server (context7, angular-cli)

## Marketplace-Struktur

```
byteagenten-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # Plugin Registry
├── plugins/
│   └── byt8/                # Full-Stack Development Plugin
│       ├── agents/          # 10 spezialisierte Agents
│       ├── commands/        # Slash Commands
│       ├── hooks/           # Hook-Definitionen
│       ├── scripts/         # Workflow Scripts
│       └── skills/          # Workflow Implementations
└── README.md
```

## Adding New Plugins

1. Folder erstellen: `plugins/[name]/`
2. `.claude-plugin/plugin.json` hinzufügen
3. Commands, Agents, Skills, Hooks hinzufügen
4. `.claude-plugin/marketplace.json` aktualisieren
5. PR erstellen

## License

Proprietary - byteAgenten internal use only.
