#!/bin/bash
# enforce_orchestrator.sh - Erzwingt dass der Orchestrator gestartet wird

# Prüfe ob wir in einer bytA-Session sind (Marker-Datei existiert)
if [ -f ".workflow/bytA-session" ]; then
    # Prüfe ob der Orchestrator bereits gestartet wurde
    if [ ! -f ".workflow/orchestrator-started" ]; then
        # Orchestrator wurde NICHT gestartet - erzwinge es!
        jq -n '{
            "decision": "block",
            "reason": "STOPP! Du hast das bytA:feature Skill geladen aber den Orchestrator nicht gestartet. Du MUSST jetzt Task(bytA-orchestrator, \"...\") aufrufen. Keine Ausnahmen - auch nicht für kleine Fixes!"
        }'
        exit 0
    fi
fi

# Kein bytA-Kontext oder Orchestrator bereits gestartet - normal weitermachen
exit 0
