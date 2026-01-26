---
description: Zeigt den detaillierten Status des aktuellen Full-Stack-Feature Workflows an.
---

Zeige den aktuellen Workflow-Status an.

Lies die Datei `.workflow/workflow-state.json` und gib eine übersichtliche Zusammenfassung aus:

1. **Grundinfo**: Issue-Nummer, Titel, aktueller Status (active/paused/completed)
2. **Aktuelle Phase**: Nummer und Name der Phase
3. **Retry-Status**: Anzahl der Versuche für die aktuelle Phase (aus `.workflow/recovery/retry-tracker.json`)
4. **Nächster Schritt**: Was als nächstes zu tun ist
5. **Abgeschlossene Phasen**: Liste der fertigen Phasen mit Timestamp

Falls kein aktiver Workflow existiert, melde dies freundlich.

Format die Ausgabe übersichtlich mit Emojis und klaren Abschnitten.
