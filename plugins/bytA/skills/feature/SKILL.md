---
description: Starte den Orchestrator für Full-Stack Feature Development
author: byteAgenten
---

# bytA Feature

## SCHRITT 1: Session markieren (PFLICHT!)

```bash
mkdir -p .workflow && echo "$(date)" > .workflow/bytA-session
```

## SCHRITT 2: Orchestrator starten (PFLICHT!)

```
Task(bytA-orchestrator, "Feature für Issue #{ISSUE_NUMBER} implementieren")
```

**KEINE AUSNAHMEN!** Auch nicht für "kleine Fixes". Der Hook wird dich blockieren wenn du den Orchestrator nicht startest.
