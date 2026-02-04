#!/bin/bash
# enforce_orchestrator.sh - Erzwingt dass PLAN.md erstellt wird

# Prüfe ob wir in einer bytA-Session sind
if [ -f ".workflow/bytA-session" ]; then
    # Prüfe ob PLAN.md existiert
    if [ ! -f ".workflow/PLAN.md" ]; then
        # Plan wurde nicht erstellt - erzwinge Planning Phase!
        jq -n '{
            "decision": "block",
            "reason": "STOPP! Du hast das bytA:feature Skill geladen aber keinen PLAN.md erstellt. Du MUSST zuerst Task(byt8:architect-planner, ...) aufrufen um einen Implementation Plan zu erstellen. Der Plan kommt nach .workflow/PLAN.md"
        }'
        exit 0
    fi

    # Prüfe ob noch offene Tasks existieren und ob wir gerade implementieren
    if [ -f ".workflow/PLAN.md" ]; then
        OPEN_TASKS=$(grep -c "^\- \[ \]" .workflow/PLAN.md 2>/dev/null || echo "0")

        if [ "$OPEN_TASKS" -gt 0 ]; then
            # Es gibt noch offene Tasks - erinnere an den Loop
            jq -n --arg tasks "$OPEN_TASKS" '{
                "decision": "block",
                "reason": ("Es gibt noch " + $tasks + " offene Tasks in PLAN.md. Lies PLAN.md, finde den nächsten offenen Task (- [ ]), und rufe den passenden Agent auf. Arbeite Task für Task ab.")
            }'
            exit 0
        fi
    fi
fi

# Kein bytA-Kontext oder alles erledigt
exit 0
