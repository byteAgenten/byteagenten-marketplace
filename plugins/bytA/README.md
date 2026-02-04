# bytA Plugin

**Version 1.1.0** | Boomerang-Style mit permissionMode

## Philosophie

Inspiriert von [Roo Code Boomerang](https://docs.roocode.com/features/boomerang-tasks) + Claude Code's `permissionMode`:

- **APPROVAL-Phasen**: Nutzen byt8: Agents → User wird gefragt
- **AUTO-Phasen**: Nutzen bytA-auto-* Agents mit `permissionMode: bypassPermissions` → Laufen durch

## Wie es funktioniert

```
/bytA:feature #123
         │
         ▼
┌─────────────────────────────────────────────────┐
│ Orchestrator                                    │
├─────────────────────────────────────────────────┤
│                                                 │
│ APPROVAL: Task(byt8:architect-planner)          │
│           → "Allow?" → User: Ja                 │
│           → Spec erstellt                       │
│                                                 │
│ APPROVAL: Task(byt8:ui-designer)                │
│           → "Allow?" → User: Ja                 │
│           → Wireframes erstellt                 │
│                                                 │
│ AUTO:     Task(bytA-auto-api-architect)         │
│           → bypassPermissions → läuft durch!    │
│                                                 │
│ AUTO:     Task(bytA-auto-db-architect)          │
│           → bypassPermissions → läuft durch!    │
│                                                 │
│ AUTO:     Task(bytA-auto-backend-dev)           │
│           → bypassPermissions → läuft durch!    │
│                                                 │
│ AUTO:     Task(bytA-auto-frontend-dev)          │
│           → bypassPermissions → läuft durch!    │
│                                                 │
│ AUTO:     Task(bytA-auto-test-engineer)         │
│           → bypassPermissions → läuft durch!    │
│                                                 │
│ APPROVAL: Task(byt8:security-auditor)           │
│           → "Allow?" → User: Ja                 │
│                                                 │
│ APPROVAL: Task(byt8:code-reviewer)              │
│           → "Allow?" → User: Ja                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Agents

### APPROVAL-Agents (byt8:, User wird gefragt)
| Agent | Phase | Beschreibung |
|-------|-------|--------------|
| byt8:architect-planner | Spec | Technical Specification |
| byt8:ui-designer | UI | Wireframes |
| byt8:security-auditor | Security | Security Audit |
| byt8:code-reviewer | Review | Code Review |

### AUTO-Agents (bytA-auto-*, bypassPermissions)
| Agent | Phase | Beschreibung |
|-------|-------|--------------|
| bytA-auto-api-architect | API | REST API Design |
| bytA-auto-db-architect | DB | Flyway Migrations |
| bytA-auto-backend-dev | Backend | Spring Boot |
| bytA-auto-frontend-dev | Frontend | Angular |
| bytA-auto-test-engineer | Tests | Playwright E2E |

## Struktur

```
bytA/
├── .claude-plugin/plugin.json
├── agents/
│   ├── orchestrator.md           # Koordiniert alles
│   ├── auto-api-architect.md     # AUTO (bypassPermissions)
│   ├── auto-db-architect.md      # AUTO (bypassPermissions)
│   ├── auto-backend-dev.md       # AUTO (bypassPermissions)
│   ├── auto-frontend-dev.md      # AUTO (bypassPermissions)
│   └── auto-test-engineer.md     # AUTO (bypassPermissions)
├── commands/feature.md
├── hooks/hooks.json              # LEER
├── skills/feature/SKILL.md
└── README.md
```

## Der Trick: permissionMode

Claude Code Agents unterstützen `permissionMode` im Frontmatter:

```yaml
---
name: bytA-auto-backend-dev
permissionMode: bypassPermissions  # ← Läuft ohne User-Frage!
---
```

- `default` → User wird gefragt (APPROVAL)
- `bypassPermissions` → Läuft durch (AUTO)

Das ist **deterministisch** - Claude Code erzwingt es technisch.

## Verwendung

```
/bytA:feature #123
```

## Warum das funktioniert

| Problem bei byt8 | Lösung bei bytA |
|------------------|-----------------|
| Hooks waren komplex | Keine Hooks |
| State-Management fragil | Kein State-File |
| Prompts wurden ignoriert | permissionMode ist technisch |
| APPROVAL-Gates übersprungen | byt8: Agents = default permission |
| AUTO sollte durchlaufen | bypassPermissions = deterministisch |

## Quellen

- [Claude Code Subagents - permissionMode](https://code.claude.com/docs/en/sub-agents)
- [Roo Code Auto-Approving Actions](https://docs.roocode.com/features/auto-approving-actions)
