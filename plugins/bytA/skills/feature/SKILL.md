---
description: Start a full-stack feature workflow with agent-based orchestration.
author: byteAgenten
---

# Feature Workflow

Starte den Orchestrator-Agent für das angegebene GitHub Issue.

## Verwendung

```
/bytA:feature #123
/bytA:feature 123
```

## Was passiert

1. Der `bytA-orchestrator` Agent wird gestartet
2. Er lädt das Issue von GitHub
3. Er führt dich durch den Workflow mit Approval Gates

## Starten

```
Task(bytA-orchestrator, "Start feature workflow for Issue #{ISSUE_NUMBER}")
```

Ersetze `{ISSUE_NUMBER}` mit der Issue-Nummer aus dem User-Input.
