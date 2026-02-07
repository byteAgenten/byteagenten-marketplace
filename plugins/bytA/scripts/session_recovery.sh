#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Session Recovery (SessionStart Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert nach Context Overflow / neuer Session.
# Wenn aktiver Workflow existiert → Minimalen Recovery-Prompt ausgeben.
#
# Unterschied zu byt8: Deutlich kuerzer, weil der Ralph-Loop
# State auf Disk hat und die Stop/UserPromptSubmit Hooks den Rest machen.
# Dieser Hook muss nur sicherstellen, dass Claude weiss:
# 1. Es gibt einen aktiven Workflow
# 2. Es soll /bytA:feature aufrufen (damit SKILL.md geladen wird)
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

# ═══════════════════════════════════════════════════════════════════════════
# PRUEFEN: Aktiver Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f "$WORKFLOW_FILE" ]; then
  # Kein Workflow → aber vielleicht Session-Marker?
  if [ -f "${WORKFLOW_DIR}/bytA-session" ]; then
    echo ""
    echo "WORKFLOW RECOVERY: Session-Marker gefunden aber kein Workflow-State."
    echo "Startup wurde nicht abgeschlossen. Rufe /bytA:feature auf."
    echo ""
  fi
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ] && [ "$STATUS" != "paused" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# RECOVERY: Minimaler Kontext
# ═══════════════════════════════════════════════════════════════════════════

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Unbekannt"' "$WORKFLOW_FILE")

# Phase-Namen
PHASE_NAMES=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Security Audit" "Code Review" "Push & PR")
PHASE_NAME="${PHASE_NAMES[$CURRENT_PHASE]:-Phase $CURRENT_PHASE}"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "WORKFLOW RECOVERY nach Context Overflow"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Issue:  #${ISSUE_NUMBER} - ${ISSUE_TITLE}"
echo "  Phase:  ${CURRENT_PHASE} (${PHASE_NAME})"
echo "  Status: ${STATUS}"
echo ""
echo "  PFLICHT-AKTION: Rufe /bytA:feature auf!"
echo ""
echo "  Das laedt den Skill neu. Die Hooks uebernehmen dann:"
echo "  - Stop Hook: Ralph-Loop setzt automatisch fort"
echo "  - UserPromptSubmit Hook: Injiziert Approval-Gate-Kontext"
echo "  - PreToolUse Hooks: Blockieren unerlaubte Aktionen"
echo ""
echo "  KEINE eigenstaendigen Aktionen ausfuehren!"
echo "  NUR /bytA:feature aufrufen."
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
