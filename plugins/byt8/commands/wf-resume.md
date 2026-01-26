---
description: Setzt einen pausierten Full-Stack-Feature Workflow fort.
---

Setze den pausierten Workflow fort.

1. Lies `.workflow/workflow-state.json`
2. Prüfe ob `status` == `"paused"` ist
3. Wenn ja:
   - Setze `status` auf `"active"`
   - Lösche `pauseReason`
   - Speichere die Änderungen
4. Zeige den aktuellen Stand und was als nächstes zu tun ist

Falls der Workflow nicht pausiert ist, erkläre den aktuellen Status.

Nach dem Fortsetzen: Frage ob der Workflow mit `/byt8:full-stack-feature` fortgesetzt werden soll.
