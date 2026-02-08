#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA User Prompt Context Injection (UserPromptSubmit Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert bei JEDEM User-Prompt. stdout wird in Claudes Kontext injiziert.
#
# Zweck:
# 1. Workflow-Status in Claudes Kontext halten
# 2. Approval-Gate-Anweisungen injizieren (Option C: Heuristik + User-Wahl)
# 3. stopHookBlockCount zuruecksetzen (Loop-Prevention Reset)
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
_HOOK_INPUT=$(cat)
_HOOK_CWD=$(echo "$_HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOGS_DIR="${WORKFLOW_DIR}/logs"

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# ═══════════════════════════════════════════════════════════════════════════
# KEIN WORKFLOW → NICHTS TUN
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Inaktive Workflows → kein Output
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "idle" ] || [ "$STATUS" = "unknown" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# STOP HOOK BLOCK COUNTER ZURUECKSETZEN
# ═══════════════════════════════════════════════════════════════════════════
if jq -e '.stopHookBlockCount > 0' "$WORKFLOW_FILE" > /dev/null 2>&1; then
  jq '.stopHookBlockCount = 0' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" 2>/dev/null && \
    mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
fi

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")
PHASE_NAME=$(get_phase_name "$PHASE")

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] UserPromptSubmit: Phase $PHASE ($PHASE_NAME) | Status: $STATUS" >> "$LOGS_DIR/hooks.log" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# KONTEXT-INJECTION (stdout → Claudes Kontext)
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" = "paused" ]; then
  PAUSE_REASON=$(jq -r '.pauseReason // "unbekannt"' "$WORKFLOW_FILE" 2>/dev/null)
  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW PAUSIERT | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM"
  echo "Grund: $PAUSE_REASON"
  echo "Optionen: /bytA:wf-resume | /bytA:wf-retry-reset | /bytA:wf-skip"
  echo "</user-prompt-submit-hook>"
  exit 0
fi

if [ "$STATUS" = "awaiting_approval" ]; then
  # ADVANCE_CMD Prefix — deterministisch, kein manuelles jq noetig
  ADVANCE_CMD="${SCRIPT_DIR}/wf_advance.sh"

  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW APPROVAL GATE | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM: $ISSUE_TITLE"
  echo ""
  echo "WICHTIG: State-Aenderungen passieren DETERMINISTISCH im wf_advance.sh Script."
  echo "Du musst NUR den passenden Bash-Befehl ausfuehren und die EXECUTE-Anweisung aus dem Output befolgen."
  echo ""

  case $PHASE in
    0)
      echo "Der User antwortet auf die Technical Specification (Phase 0)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  Bash: $ADVANCE_CMD approve"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche an Tech Spec):"
      echo "  Bash: $ADVANCE_CMD feedback 'USER_FEEDBACK_HIER'"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      ;;

    1)
      echo "Der User antwortet auf die Wireframes (Phase 1)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  Bash: $ADVANCE_CMD approve"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche an Wireframes):"
      echo "  Bash: $ADVANCE_CMD feedback 'USER_FEEDBACK_HIER'"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      ;;

    7)
      echo "Der User antwortet auf das Security Audit Ergebnis (Phase 7)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  Bash: $ADVANCE_CMD approve"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      echo ""
      echo "BEI SECURITY-FIXES (Rollback noetig):"
      echo "  Bash: $ADVANCE_CMD rollback ZIEL 'SECURITY_FINDINGS_HIER'"
      echo "  Ziel: 4=Backend, 5=Frontend, 6=Tests (Default)"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      ;;

    8)
      echo "Der User antwortet auf das Code Review Ergebnis (Phase 8)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  Bash: $ADVANCE_CMD approve"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      echo ""
      echo "BEI FEEDBACK (Re-Review gleiche Phase):"
      echo "  Bash: $ADVANCE_CMD feedback 'USER_FEEDBACK_HIER'"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      echo ""
      echo "BEI ROLLBACK (zu anderer Phase):"
      echo "  Bash: $ADVANCE_CMD rollback ZIEL 'REVIEW_FINDINGS_HIER'"
      echo "  Ziel: 3=DB, 4=Backend, 5=Frontend, 6=Tests"
      echo "  Fuehre die EXECUTE-Anweisung aus dem Output aus."
      ;;

    9)
      echo "Der User antwortet auf Push & PR (Phase 9)."
      echo ""
      echo "BEI APPROVAL (Ja, pushen):"
      echo "  Bash: $ADVANCE_CMD approve"
      echo "  Fuehre die Anweisungen aus dem Output aus (Build Gate + Push + PR)."
      echo "  Nach erfolgreichem Push+PR:"
      echo "  Bash: $ADVANCE_CMD complete"
      ;;
  esac

  echo "</user-prompt-submit-hook>"
  exit 0
fi

if [ "$STATUS" = "active" ]; then
  echo "<user-prompt-submit-hook>"
  echo "AKTIVER WORKFLOW | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM | Status: active"
  echo "Workflow laeuft. Bei Phase-Aktionen: lies .workflow/workflow-state.json fuer aktuellen State."
  echo "</user-prompt-submit-hook>"
  exit 0
fi

exit 0
