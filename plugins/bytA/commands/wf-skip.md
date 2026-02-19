---
description: Skip the current workflow phase (emergency use only)
---

# Phase ueberspringen (Notfall)

WARNUNG: Dies ueberspringt die aktuelle Phase ohne Ergebnis. Nur im Notfall verwenden!

1. Lies den aktuellen State:

```bash
cat .workflow/workflow-state.json
```

2. Frage den User zur Bestaetigung:
   "Phase X (NAME) wirklich ueberspringen? Das kann zu fehlenden Specs fuehren."

3. Nur bei Bestaetigung — Phase als skipped markieren und zur naechsten weiter:

```bash
PHASE=$(jq -r '.currentPhase' .workflow/workflow-state.json)
NEXT=$((PHASE + 1))
jq --argjson p "$PHASE" --argjson np "$NEXT" \
  '.phases[($p | tostring)].status = "skipped" | .phases[($p | tostring)].reason = "user-skip" | .currentPhase = $np | .status = "active"' \
  .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
```

4. Sage "Done." damit der Stop-Hook weitermacht.
