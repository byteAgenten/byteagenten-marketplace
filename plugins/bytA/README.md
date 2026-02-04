# bytA Plugin

**Version 1.0.0** | Boomerang-Style Workflow Orchestration

## Philosophie

Inspiriert von [Roo Code Boomerang](https://docs.roocode.com/features/boomerang-tasks):

- **Ein Orchestrator** - delegiert, implementiert nichts
- **Keine Hooks** - Claude Code's Task-Permission ist der Approval Gate
- **Keine Scripts** - rein prompt-basiert
- **User kontrolliert jeden Task** - "Allow?" bei jedem Agent-Start

## Unterschied zu byt8

| Aspekt | byt8 | bytA |
|--------|------|------|
| Dateien | ~20 Dateien (agents, hooks, scripts) | 6 Dateien total |
| Hooks | Komplex (Stop, PreToolUse, etc.) | Keine |
| Scripts | wf_engine.sh, agent_done.sh, etc. | Keine |
| Approval | Hook erzwingt via decision:block | Claude Code built-in |
| Agents | Eigene Agent-Definitionen | Nutzt byt8: Agents |

## Verwendung

```
/bytA:feature #123
```

## Wie es funktioniert

```
User: /bytA:feature #123
         │
         ▼
Claude Code: "Allow bytA-orchestrator?" ← User sagt Ja
         │
         ▼
Orchestrator: Analysiert Issue, delegiert
         │
         ▼
Claude Code: "Allow byt8:architect-planner?" ← User sagt Ja
         │
         ▼
Architect: Erstellt Spec → .workflow/spec.md
         │
         ▼
Orchestrator: Liest Spec, delegiert weiter
         │
         ▼
Claude Code: "Allow byt8:spring-boot-developer?" ← User sagt Ja
         │
         ... usw.
```

**Der User approved jeden Task** - das IST der Approval Gate.

## Struktur

```
bytA/
├── .claude-plugin/plugin.json   # Metadata
├── agents/orchestrator.md       # Der einzige Agent
├── commands/feature.md          # Command → Skill
├── hooks/hooks.json             # LEER
├── skills/feature/SKILL.md      # Startet nur Orchestrator
└── README.md
```

## Der Orchestrator

Der Orchestrator:
1. Lädt das GitHub Issue
2. Entscheidet welche Agents nötig sind
3. Delegiert via `Task(byt8:agent-name, ...)`
4. Liest Ergebnisse, entscheidet nächsten Schritt

Er nutzt die **byt8: Agents**:
- `byt8:architect-planner`
- `byt8:ui-designer`
- `byt8:api-architect`
- `byt8:postgresql-architect`
- `byt8:spring-boot-developer`
- `byt8:angular-frontend-developer`
- `byt8:test-engineer`
- `byt8:security-auditor`
- `byt8:code-reviewer`

## Warum so minimal?

Wir haben gelernt dass komplexe Hook-Logik fragil ist. Das Boomerang-Muster ist einfacher:

1. **Keine Hooks** = Keine Hook-Bugs
2. **Ein Orchestrator** = Klare Verantwortung
3. **Built-in Approval** = Deterministisch (Claude Code erzwingt es)
4. **byt8 Agents wiederverwenden** = Keine Duplikation
