---
description: Pausiert den aktuellen Full-Stack-Feature Workflow. Ermöglicht manuelle Eingriffe oder Pausen.
---

Pausiere den aktuellen Workflow.

1. Lies `.workflow/workflow-state.json`
2. Setze `status` auf `"paused"`
3. Setze `pauseReason` auf `"user_requested"`
4. Speichere die Änderungen

Bestätige die Pausierung und zeige die verfügbaren Optionen:
- `/wf:resume` - Workflow fortsetzen
- `/wf:status` - Status anzeigen
- `/wf:retry-reset` - Retry-Counter zurücksetzen

Falls kein aktiver Workflow existiert, melde dies freundlich.
