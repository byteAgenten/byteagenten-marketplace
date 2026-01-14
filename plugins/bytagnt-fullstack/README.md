# bytagnt-fullstack Plugin

Full-Stack Development Toolkit für Angular 21 + Spring Boot 4 Anwendungen mit 10-Phasen Workflow und Approval Gates.

## Philosophy

> "Qualität durch Struktur: Jede Phase wird abgeschlossen, bevor die nächste beginnt."

Dieses Plugin orchestriert spezialisierte Agents durch einen strukturierten Entwicklungs-Workflow mit Quality Gates und User Approvals.

---

## Installation

### Via Marketplace

```bash
# In Claude Code
/plugins install bytagnt-fullstack
```

### Via GitHub

Füge in deinem Projekt `.claude/settings.json` hinzu:

```json
{
  "plugins": {
    "bytagnt-fullstack@byteagenten-marketplace": true
  }
}
```

---

## Commands

| Command | Beschreibung |
|---------|--------------|
| `/bytagnt-fullstack:full-stack-feature` | 10-Phasen Feature Development Workflow |
| `/bytagnt-fullstack:project-setup` | Einmalige Design System Initialisierung |
| `/bytagnt-fullstack:theme-factory` | Theme-Auswahl und -Generierung |
| `/bytagnt-fullstack:ui-design-system` | UI Design System Toolkit |
| `/bytagnt-fullstack:ux-researcher-designer` | UX Research und Design Workflow |
| `/bytagnt-fullstack:python-expert` | Python Development Support |

### Beispiel

```bash
/bytagnt-fullstack:full-stack-feature #42
```

---

## Der 10-Phasen Workflow

Der `full-stack-feature` Command orchestriert diese Phasen:

| Phase | Agent | Aufgabe |
|-------|-------|---------|
| 0 | architect-planner | Technical Specification erstellen |
| 1 | ui-ux-designer | Wireframes erstellen |
| 2 | api-architect | API Design (OpenAPI 3.1) |
| 3 | postgresql-architect | Database Migrations (Flyway) |
| 4 | spring-boot-developer | Backend Implementation + Tests |
| 5 | angular-frontend-developer | Frontend Implementation + Tests |
| 6 | test-engineer | E2E Tests (Playwright) |
| 6b | security-auditor | Security Audit |
| 7 | code-reviewer | Code Review |
| 8-10 | - | PR erstellen, Merge, Cleanup |

### Approval Gates

Der Workflow pausiert an kritischen Punkten für User-Approval:
- Nach Phase 0 (Technical Spec)
- Nach Phase 1 (Wireframes)
- Nach Phase 6 (Tests + Security)
- Nach Phase 7 (Code Review)
- Nach Phase 8 (PR erstellt)

---

## Agents

| Agent | Spezialisierung |
|-------|-----------------|
| `architect-planner` | Technical Specifications, 5x Warum Analyse |
| `api-architect` | OpenAPI 3.1, REST API Design |
| `angular-frontend-developer` | Angular 21, Signals, TypeScript |
| `spring-boot-developer` | Spring Boot 4, Java 21, JPA |
| `postgresql-architect` | Schema Design, Flyway Migrations |
| `test-engineer` | JUnit 5, Jasmine, Playwright |
| `ui-ux-designer` | Wireframes, Design Tokens |
| `security-auditor` | OWASP Top 10, Security Best Practices |
| `code-reviewer` | Code Quality, Architecture Review |
| `architect-reviewer` | Architecture Decisions |

---

## Skills

| Skill | Beschreibung |
|-------|--------------|
| `full-stack-feature` | 10-Phasen Workflow mit State Management |
| `project-setup` | Design System Initialisierung |
| `theme-factory` | 10 vordefinierte Themes + Custom Generation |
| `ui-design-system` | Design Tokens, Typography, Spacing |
| `ux-researcher-designer` | Personas, Journey Maps, Usability |
| `python-expert` | Async, Typing, Testing Patterns |

---

## Plugin-Struktur

```
bytagnt-fullstack/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── architect-planner.md
│   ├── angular-frontend-developer.md
│   ├── spring-boot-developer.md
│   └── ...
├── commands/
│   ├── full-stack-feature.md
│   ├── project-setup.md
│   └── ...
├── skills/
│   ├── full-stack-feature/
│   │   └── SKILL.md
│   ├── theme-factory/
│   │   ├── SKILL.md
│   │   └── themes/
│   └── ...
└── README.md
```

---

## Technologie-Stack

- **Backend:** Spring Boot 4.0+, Java 21+, PostgreSQL
- **Frontend:** Angular 21+, TypeScript, SCSS
- **Testing:** JUnit 5, Jasmine, Playwright
- **API:** OpenAPI 3.1, REST
- **Database:** PostgreSQL, Flyway Migrations

---

## License

MIT
