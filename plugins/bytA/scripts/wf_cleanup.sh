#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Workflow Cleanup (Startup Check)
# ═══════════════════════════════════════════════════════════════════════════
# Prueft bei Skill-Start ob ein alter Workflow aufgeraeumt werden muss.
#
# Exit Codes:
#   0 = OK (kein Workflow oder completed → aufgeraeumt)
#   1 = BLOCKED (aktiver Workflow gefunden)
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

case "$STATUS" in
  completed)
    rm -rf "$WORKFLOW_DIR"
    echo "Abgeschlossener Workflow aufgeraeumt."
    exit 0
    ;;
  active|paused|awaiting_approval)
    PHASE=$(jq -r '.currentPhase // "?"' "$WORKFLOW_FILE" 2>/dev/null)
    ISSUE=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null)
    echo "AKTIVER WORKFLOW GEFUNDEN: Issue #$ISSUE, Phase $PHASE, Status: $STATUS"
    echo "Optionen:"
    echo "  → /bytA:wf-resume  (Workflow fortsetzen)"
    echo "  → rm -rf .workflow/ (Workflow verwerfen)"
    exit 1
    ;;
  *)
    rm -rf "$WORKFLOW_DIR"
    exit 0
    ;;
esac
