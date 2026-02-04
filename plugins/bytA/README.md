# bytA Plugin

**Version 0.2.0** | Agent-based Workflow Orchestration für Angular + Spring Boot

## Philosophy

> "Der Orchestrator delegiert, die Agents implementieren."

Inspiriert von [Roo Code Boomerang](https://docs.roocode.com/features/boomerang-tasks):
- **Fokussierter Orchestrator** - nur Delegation, keine Implementation
- **Isolierte Agents** - jeder Agent hat seinen eigenen Kontext
- **Dynamische Entscheidungen** - der Orchestrator entscheidet nach jedem Schritt
- **Minimale Hooks** - nur das Nötigste (WIP-Commits)

## Unterschied zu byt8

| Aspekt | byt8 (alt) | bytA (neu) |
|--------|------------|------------|
| Steuerung | 260-Zeilen SKILL.md | Fokussierter Orchestrator-Agent |
| Hooks | Komplex (Stop, PreToolUse, etc.) | Minimal (nur WIP-Commit) |
| State | workflow-state.json mit vielen Feldern | Einfaches state.json |
| Phasen-Logic | In Hooks codiert | Orchestrator entscheidet dynamisch |
| Approval Gates | Hook erzwingt via decision:block | Orchestrator fragt User direkt |

## Verwendung

```
/bytA:feature #123
```

Der Orchestrator-Agent wird gestartet und führt dich durch den Workflow.

## Workflow-Phasen

| Phase | Agent | Typ | Beschreibung |
|-------|-------|-----|--------------|
| 0 | bytA-architect | APPROVAL | Technical Specification |
| 1 | bytA-ui-designer | APPROVAL | Wireframes (optional) |
| 2 | bytA-api-architect | AUTO | API Design |
| 3 | bytA-db-architect | AUTO | Database Migrations |
| 4 | bytA-backend-dev | AUTO | Spring Boot Implementation |
| 5 | bytA-frontend-dev | AUTO | Angular Implementation |
| 6 | bytA-test-engineer | AUTO | E2E Tests |
| 7 | bytA-security | APPROVAL | Security Audit |
| 8 | bytA-reviewer | APPROVAL | Code Review |

**APPROVAL** = User muss bestätigen bevor es weitergeht
**AUTO** = Läuft automatisch durch

## Architektur

```
/bytA:feature #123
       │
       ▼
┌──────────────────────────────────────┐
│  bytA-orchestrator                   │
│  - Lädt Issue                        │
│  - Entscheidet nächste Phase         │
│  - Fragt User bei APPROVAL-Phasen    │
└──────────────────────────────────────┘
       │
       ├── Task(bytA-architect, "...")
       │      └── Schreibt phase-0-result.md
       │      └── Orchestrator liest Ergebnis
       │      └── APPROVAL: Fragt User
       │
       ├── Task(bytA-frontend-dev, "...")
       │      └── Schreibt phase-5-result.md
       │      └── Orchestrator liest Ergebnis
       │      └── AUTO: Nächste Phase
       │
       └── ...
```

## State Management

```
.workflow/
├── state.json           # Einfacher State
├── phase-0-result.md    # Architect Output
├── phase-1-result.md    # UI Designer Output
├── phase-2-result.md    # API Architect Output
├── ...
```

**state.json** (minimal):
```json
{
  "issue": 123,
  "title": "Feature Title",
  "phase": 0,
  "completedPhases": [],
  "skippedPhases": []
}
```

## Agents

| Agent | Beschreibung |
|-------|--------------|
| bytA-orchestrator | Workflow-Steuerung und User-Interaktion |
| bytA-architect | Technical Specifications |
| bytA-ui-designer | Wireframes und UI Layouts |
| bytA-api-architect | REST API Design |
| bytA-db-architect | Database Schema und Migrations |
| bytA-backend-dev | Spring Boot Implementation |
| bytA-frontend-dev | Angular Implementation |
| bytA-test-engineer | E2E Tests mit Playwright |
| bytA-security | Security Audit |
| bytA-reviewer | Code Review |

## Hooks

Ein Hook: **SubagentStop** (`agent_done.sh`)

### Approval Gates (via decision:block)

| Agent | Phase | Was passiert |
|-------|-------|--------------|
| bytA-architect | 0 | Hook erzwingt: "Zeige Spec, frage User" |
| bytA-ui-designer | 1 | Hook erzwingt: "Zeige Wireframes, frage User" |
| bytA-security | 7 | Hook erzwingt: "Zeige Findings, frage User" |
| bytA-reviewer | 8 | Hook erzwingt: "Zeige Review, frage User" |

### WIP-Commits (automatisch)

| Agent | Phase | Was passiert |
|-------|-------|--------------|
| bytA-db-architect | 3 | WIP-Commit nach DB-Änderungen |
| bytA-backend-dev | 4 | WIP-Commit nach Backend-Änderungen |
| bytA-frontend-dev | 5 | WIP-Commit nach Frontend-Änderungen |
| bytA-test-engineer | 6 | WIP-Commit nach Test-Änderungen |

### Lektion gelernt

v0.1 hatte keine Hook-Enforcement → Orchestrator ignorierte Approval-Regeln.
v0.2 nutzt `decision:block` um Approvals zu erzwingen - wie byt8, aber fokussierter.

## Entwicklung

### Plugin lokal testen

```bash
# Cache löschen
rm -rf ~/.claude/plugins/cache/byteagenten-marketplace/

# Claude Code neu starten
claude
```

### Debugging

```bash
# State prüfen
cat .workflow/state.json

# Agent-Ergebnisse prüfen
ls -la .workflow/phase-*.md
```

## Roadmap

- [ ] v0.1: Basis-Workflow mit allen Agents
- [ ] v0.2: Rollback-Support bei Review-Änderungen
- [ ] v0.3: Phase-Skipping Logik verbessern
- [ ] v1.0: Stable Release
