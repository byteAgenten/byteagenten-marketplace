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

### Key Files

| Datei | Zweck |
|-------|-------|
| `plugins/byt8/skills/full-stack-feature/SKILL.md` | Workflow-Logik (Orchestrator-Anweisungen) |
| `plugins/byt8/agents/*.md` | Agent-Definitionen (10 Agents) |
| `plugins/byt8/hooks/hooks.json` | Hook-Konfiguration (Source of Truth für Hooks) |
| `plugins/byt8/scripts/*.sh` | Hook-Scripts |
| `plugins/byt8/commands/*.md` | Slash-Command-Definitionen |
| `plugins/byt8/README.md` | Plugin-Dokumentation für Nutzer |

## ⛔ Änderungs-Checkliste (PFLICHT bei JEDER Änderung!)

### Bei JEDEM Version-Bump:

1. `plugins/byt8/.claude-plugin/plugin.json` → `"version": "X.Y.Z"`
2. `plugins/byt8/README.md` → `**Version X.Y.Z**` (Zeile 3)
3. `README.md` → Versions-Spalte in der Plugin-Tabelle (Zeile 9)

### Bei JEDER funktionalen Änderung (Hooks, Agents, Skills, Workflow):

**NACH der Implementierung MUSST du prüfen und aktualisieren:**

`plugins/byt8/README.md` — Beschreibt das Plugin für Nutzer. Jede Änderung an Hooks, Agents, Workflow-Ablauf oder Architektur MUSS dort reflektiert werden.

| Was geändert? | Was aktualisieren? |
|---------------|-------------------|
| Hook hinzugefügt/entfernt | Plugin-README (Hook-Tabelle + Beschreibungen) |
| Script hinzugefügt/entfernt | Plugin-README (Hook-Beschreibungen) |
| Agent hinzugefügt/geändert | Plugin-README (Agents-Tabelle) |
| Workflow-Ablauf geändert | Plugin-README (Workflow-Beschreibung, Diagramme) + SKILL.md |
| Neue Architektur-Konzepte | Plugin-README (neuer Abschnitt) |

**Niemals Implementierung abschließen ohne README-Prüfung!**

### Bei JEDER Script-Änderung (Hooks, Scripts):

**Datenfluss-Verifikation (PFLICHT!):**

| Prüfung | Wie |
|---------|-----|
| 1. Welche Dateien liest das Script? | `grep -E '\$\{?[A-Z_]+\}?/' script.sh` |
| 2. Wer schreibt diese Dateien? | `grep -r "PFAD" plugins/byt8/` |
| 3. Existiert ein Schreiber? | Wenn NEIN → toter Code! |
| 4. Was prüft der Consumer? | Nur Key-Existenz oder auch Werte? |
| 5. Kann der Schreiber den Check umgehen? | Agent setzt `allPassed: true` ohne Tests → Bug! |

**Beispiel für session_recovery.sh:**
- Liest: `${CONTEXT_DIR}/phase-X-*.json`
- Schreiber: NIEMAND! → Bug gefunden

**Beispiel für wf_engine.sh check_done:**
- Prüfte: `context.testResults | keys | length > 0` (nur Existenz!)
- Problem: Agent konnte Key setzen ohne Tests auszuführen
- Fix: `context.testResults.allPassed == true` (Wert prüfen!)

**Nach Workflow-Durchlauf prüfen:**
- `ls -la .workflow/` → Alle erwarteten Dateien vorhanden?
- Spec-Dateien in `specs/`?
- Context in `workflow-state.json`?

## Development

### Testing Plugins Locally

Clear the plugin cache after changes:
```bash
rm -rf ~/.claude/plugins/cache/byteagenten-marketplace/
```

### Plugin Hooks

Hooks werden auf zwei Ebenen definiert:

- **Plugin-Level:** `plugins/byt8/hooks/hooks.json` (Source of Truth)
- **Skill-Level:** Frontmatter in `SKILL.md`-Dateien

Scripts liegen in `plugins/byt8/scripts/` und werden via `${CLAUDE_PLUGIN_ROOT}` referenziert.

