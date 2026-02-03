---
name: wf-cleanup
description: Löscht den .workflow/ Folder nach einem abgeschlossenen Workflow
user-invocable: true
---

# Workflow Cleanup

Räumt den `.workflow/` Folder auf.

## Anweisung

Führe das Cleanup-Script aus:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/wf_cleanup.sh
```

**Bei Erfolg (exit 0):** Bestätige dem User dass der Workflow aufgeräumt wurde.

**Bei Fehler (exit 1):** Ein aktiver Workflow wurde gefunden. Frage den User:
- "Workflow fortsetzen?" → `/byt8:wf-resume`
- "Workflow abbrechen und löschen?" → `rm -rf .workflow`

**Hinweis:** Dieses Command wird auch automatisch bei `/byt8:full-stack-feature` aufgerufen.
