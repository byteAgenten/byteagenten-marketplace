---
description: Setzt den Retry-Counter für die aktuelle Phase zurück. Nützlich nach manuellen Fixes.
---

Setze den Retry-Counter für die aktuelle Phase zurück.

1. Lies `.workflow/workflow-state.json` um die aktuelle Phase zu ermitteln
2. Lies `.workflow/recovery/retry-tracker.json`
3. Setze den Counter für die aktuelle Phase auf 0
4. Falls der Workflow wegen `max_retries` pausiert ist:
   - Setze `status` auf `"active"`
   - Lösche `pauseReason`
5. Speichere alle Änderungen

Bestätige das Zurücksetzen und zeige:
- Aktuelle Phase
- Vorheriger Retry-Count
- Neuer Retry-Count (0)

Optional: $ARGUMENTS kann eine Phase-Nummer sein um den Counter einer spezifischen Phase zurückzusetzen.
