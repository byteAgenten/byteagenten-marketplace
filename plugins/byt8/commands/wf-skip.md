---
description: ⚠️ NOTFALL - Überspringt die aktuelle Phase ohne Done-Check. Nur verwenden wenn unbedingt nötig!
---

⚠️ **WARNUNG**: Dieses Command überspringt die aktuelle Phase ohne die Done-Kriterien zu prüfen.

Dies kann zu Problemen in späteren Phasen führen! Nur verwenden wenn:
- Die Phase manuell bereits erledigt wurde
- Ein technisches Problem den Done-Check blockiert
- Es keinen anderen Ausweg gibt

**Bestätigung erforderlich**: Der User muss explizit "Ja, Phase überspringen" sagen.

Wenn bestätigt:
1. Lies `.workflow/workflow-state.json`
2. Markiere aktuelle Phase als `"skipped"`
3. Erhöhe `currentPhase` um 1
4. Setze `status` auf `"active"` falls pausiert
5. Logge die Aktion in `.workflow/logs/transitions.jsonl` mit Grund `"user_skip"`
6. Speichere alle Änderungen

Zeige eine Warnung über mögliche Konsequenzen und den neuen Status.
