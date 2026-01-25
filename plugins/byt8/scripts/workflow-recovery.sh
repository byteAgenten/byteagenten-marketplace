#!/bin/bash
# byt8 Workflow Recovery Hook
# Prüft ob ein aktiver Workflow existiert und warnt den Agent

WORKFLOW_FILE=".workflow/workflow-state.json"

if [ -f "$WORKFLOW_FILE" ]; then
  STATUS=$(jq -r '.status' "$WORKFLOW_FILE" 2>/dev/null)
  PHASE=$(jq -r '.currentPhase' "$WORKFLOW_FILE" 2>/dev/null)
  NEXT=$(jq -r '.nextStep' "$WORKFLOW_FILE" 2>/dev/null)

  if [ "$STATUS" = "active" ]; then
    echo ""
    echo "=================================================="
    echo "⛔⛔⛔ AKTIVER WORKFLOW GEFUNDEN ⛔⛔⛔"
    echo "=================================================="
    echo ""
    echo "Phase:          $PHASE"
    echo "Nächster Schritt: $NEXT"
    echo ""
    echo "DU MUSST JETZT:"
    echo "→ /byt8:full-stack-feature ausführen"
    echo ""
    echo "NICHT aus dem Summary weiterarbeiten!"
    echo "Der Skill enthält alle Phasen-Definitionen."
    echo ""
    echo "=================================================="
    echo ""
  fi
fi
