#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Cleanup Script
# ═══════════════════════════════════════════════════════════════════════════
# Wird von SKILL.md aufgerufen bei Workflow-Start.
# Räumt abgeschlossene/alte Workflows auf, lässt aktive unberührt.
#
# Logik:
#   - Kein .workflow/ → nichts tun (wird später erstellt)
#   - status=completed → komplett löschen
#   - status=active/paused/awaiting_approval → WARNUNG ausgeben, nicht löschen
#
# Output auf stdout wird von Claude gelesen (ist Teil der SKILL-Ausführung).
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

# ═══════════════════════════════════════════════════════════════════════════
# KEIN WORKFLOW-FOLDER → Nichts zu tun
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "OK: Kein vorheriger Workflow vorhanden."
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# WORKFLOW-FOLDER OHNE STATE-FILE → Inkonsistent, aufräumen
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "CLEANUP: Inkonsistenter .workflow/ Folder (keine workflow-state.json). Lösche..."
  rm -rf "$WORKFLOW_DIR"
  echo "OK: Aufgeräumt."
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Unbekannt"' "$WORKFLOW_FILE" 2>/dev/null || echo "Unbekannt")
CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")

# ═══════════════════════════════════════════════════════════════════════════
# STATUS-BASIERTE ENTSCHEIDUNG
# ═══════════════════════════════════════════════════════════════════════════

case "$STATUS" in
  completed)
    echo "CLEANUP: Vorheriger Workflow abgeschlossen (Issue #$ISSUE_NUM: $ISSUE_TITLE)."
    echo "         Lösche .workflow/ für neuen Workflow..."
    rm -rf "$WORKFLOW_DIR"
    echo "OK: Aufgeräumt."
    ;;

  active|paused|awaiting_approval)
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────────────┐"
    echo "│ ⚠️  WARNUNG: AKTIVER WORKFLOW GEFUNDEN!                                      │"
    echo "├─────────────────────────────────────────────────────────────────────────────┤"
    echo "│ Issue:  #$ISSUE_NUM - ${ISSUE_TITLE:0:50}"
    echo "│ Status: $STATUS"
    echo "│ Phase:  $CURRENT_PHASE"
    echo "├─────────────────────────────────────────────────────────────────────────────┤"
    echo "│ Optionen:                                                                   │"
    echo "│   1. Fortsetzen: Starte mit /byt8:wf-resume                                │"
    echo "│   2. Abbrechen:  rm -rf .workflow && starte neu                            │"
    echo "└─────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "BLOCKED: Workflow NICHT aufgeräumt. User muss entscheiden."
    exit 1
    ;;

  idle|unknown|*)
    echo "CLEANUP: Inaktiver/unbekannter Workflow-Status ($STATUS). Lösche..."
    rm -rf "$WORKFLOW_DIR"
    echo "OK: Aufgeräumt."
    ;;
esac

exit 0
