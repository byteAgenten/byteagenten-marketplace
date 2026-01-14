# byteAgent Plugin

Full-stack development plugin for Angular 21 + Spring Boot 4 applications.

## Team-Sharing (Empfohlen)

Dieses Plugin ist bereits für Team-Sharing konfiguriert. Nach dem Klonen des Repos ist es **automatisch aktiv** - keine manuelle Installation nötig!

### Wie es funktioniert

Das Projekt enthält in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "byteagent": {
      "source": {
        "source": "directory",
        "path": "./.claude-plugins/byteagent"
      }
    }
  },
  "enabledPlugins": {
    "byteagent@byteagent": true
  }
}
```

| Einstellung | Zweck |
|-------------|-------|
| `extraKnownMarketplaces` | Macht das Plugin bekannt (relativer Pfad!) |
| `enabledPlugins` | Aktiviert das Plugin automatisch |

**Team-Workflow:**
```bash
git clone <repo>
cd projectOrbit
claude
# → Plugin ist sofort verfügbar!
```

---

## Architektur: Commands vs Skills

Dieses Plugin verwendet ein **Command → Skill Pattern**:

```
.claude-plugins/byteagent/
├── commands/                 # Einstiegspunkte (user-invoked)
│   └── full-stack-feature.md
└── skills/                   # Workflow-Logik (model-invoked)
    └── full-stack-feature/
        └── SKILL.md          # 800+ Zeilen Workflow
```

### Zusammenspiel

```
┌─────────────────────────────────────────────────────────────┐
│  User: /byteagent:full-stack-feature #123                   │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Command wird geladen (commands/full-stack-feature.md)      │
│  → "Lies den Skill und folge dem Workflow"                  │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Claude liest SKILL.md (kompletter Workflow)                │
│  → "Ich habe den Skill bereits gelesen."                    │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│  Claude führt den Workflow aus                              │
└─────────────────────────────────────────────────────────────┘
```

### Warum dieses Pattern?

| Aspekt | Command | Skill |
|--------|---------|-------|
| **Größe** | Klein (~10 Zeilen) | Groß (100-800 Zeilen) |
| **Aufruf** | Explizit per `/byteagent:...` | Von Claude gelesen |
| **Zweck** | Einstiegspunkt + Argumente | Komplette Workflow-Definition |

### `/skills` zeigt byteagent nicht?

Das ist **erwartetes Verhalten**:

| Plugin-Typ | Hat Commands? | In `/skills` sichtbar? |
|------------|---------------|------------------------|
| claude-code-workflows | ❌ Nein | ✅ Ja (reine Skills) |
| byteagent | ✅ Ja | ❌ Nein (Commands als Einstieg) |

Die byteagent Skills erscheinen nicht in `/skills` weil sie **gleichnamige Commands** haben.
Sie werden als **Commands mit Skill-Backing** behandelt - aufrufbar per `/byteagent:...`.

---

## Verfügbare Commands

| Command | Beschreibung |
|---------|--------------|
| `/byteagent:project-setup` | Einmalige Projekt-Initialisierung (Design System, Theme, Tokens) |
| `/byteagent:full-stack-feature` | Full-Stack Feature Development Workflow mit Approval Gates |
| `/byteagent:theme-factory` | Theme-Auswahl und -Generierung |
| `/byteagent:ui-design-system` | UI Design System Setup |
| `/byteagent:ux-researcher-designer` | UX Research und Design Workflow |

### Beispiel-Aufrufe

```bash
# Mit GitHub Issue:
/byteagent:full-stack-feature #42

# Mit Beschreibung:
/byteagent:full-stack-feature "User Settings implementieren"

# Interaktiv (ohne Argument):
/byteagent:full-stack-feature
# → Claude fragt nach Issue oder Beschreibung
```

---

## Verfügbare Agents

Diese Agents werden vom `full-stack-feature` Workflow orchestriert:

| Agent | Spezialisierung |
|-------|-----------------|
| `byteagent:spring-boot-developer` | Backend mit Spring Boot 4.0, Java 21 |
| `byteagent:angular-frontend-developer` | Frontend mit Angular 21, Signals |
| `byteagent:api-architect` | OpenAPI 3.1, REST API Design |
| `byteagent:postgresql-architect` | Schema Design, Flyway Migrations |
| `byteagent:test-engineer` | JUnit 5, Jasmine, Playwright E2E |
| `byteagent:security-auditor` | OWASP, Security Best Practices |
| `byteagent:code-reviewer` | Code Review mit Context7 Verification |
| `byteagent:architect-reviewer` | Architektur-Entscheidungen |
| `byteagent:ui-ux-designer` | Wireframes, Design Tokens |

---

## Plugin-Struktur

```
.claude-plugins/byteagent/
├── .claude-plugin/
│   ├── plugin.json          # Plugin-Metadaten
│   └── marketplace.json     # Marketplace-Definition
├── commands/                # Slash Commands (/byteagent:xyz)
│   ├── project-setup.md
│   ├── full-stack-feature.md
│   └── ...
├── agents/                  # Spezialisierte Agents
│   ├── spring-boot-developer.md
│   ├── angular-frontend-developer.md
│   └── ...
├── skills/                  # Workflow-Definitionen
│   ├── full-stack-feature/
│   │   └── SKILL.md         # Kompletter 7-Phasen Workflow
│   └── ...
└── README.md                # Diese Datei
```

---

## Troubleshooting

### Plugin nicht aktiv nach Clone?

1. Prüfe ob `.claude/settings.json` existiert
2. Prüfe ob `enabledPlugins` den Eintrag `"byteagent@byteagent": true` enthält
3. Claude Code neu starten

### "Unknown slash command"

1. `/plugin` ausführen und "Errors" Tab prüfen
2. Claude Code neu starten

### Commands funktionieren, aber Agents nicht?

Die Agents werden **intern** vom Workflow genutzt. Du rufst sie nicht direkt auf -
der `full-stack-feature` Skill orchestriert sie automatisch in den verschiedenen Phasen.

---

## Lokale Entwicklung

Falls du das Plugin lokal entwickeln/testen möchtest:

```bash
# Plugin direkt laden (ohne Installation)
claude --plugin-dir ./.claude-plugins/byteagent
```

Änderungen an Commands/Skills/Agents werden nach Neustart von Claude Code wirksam.
