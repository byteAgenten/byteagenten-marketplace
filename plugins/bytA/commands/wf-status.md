---
description: Show current bytA workflow status (phase, hints, retries, pause state)
---

# Workflow Status

Lies `.workflow/workflow-state.json` und zeige dem User eine kompakte Uebersicht:

```bash
cat .workflow/workflow-state.json
```

Formatiere die Ausgabe als Tabelle:

| Feld | Quelle |
|------|--------|
| Issue | `.issue.number` + `.issue.title` |
| Phase | `.currentPhase` + Phase-Name |
| Status | `.status` |
| Scope | `.scope` |
| Branch | `.branch` |
| Gestartet | `.startedAt` |
| Retries | `.recovery` (alle Eintraege) |
| Hints | `.hints` (alle aktiven Hints auflisten) |
| Pause-Grund | `.pauseReason` (falls vorhanden) |
| Checkpoint-Modus | `.checkpointMode` (falls vorhanden) |

Zeige zusaetzlich den Phasen-Status:

| Phase | Name | Status |
|-------|------|--------|
| 0 | Planning | `.phases["0"].status` |
| 1 | Migrations | `.phases["1"].status` |
| ... | ... | ... |

Verfuegbare Aktionen je nach Status:
- `active` → `wf_advance.sh pause` | `wf_advance.sh hint 'TEXT'`
- `paused` → `wf_advance.sh resume`
- `awaiting_approval` → `wf_advance.sh approve` | `wf_advance.sh feedback 'TEXT'` | `wf_advance.sh rollback ZIEL 'TEXT'`
