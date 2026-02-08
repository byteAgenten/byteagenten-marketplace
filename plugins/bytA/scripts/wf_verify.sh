#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA External Done-Verification (Ralph-Loop Principle)
# ═══════════════════════════════════════════════════════════════════════════
# Prueft ob eine Phase EXTERN fertig ist — KEIN LLM beteiligt!
#
# Usage: wf_verify.sh <phase_number>
# Returns: exit 0 = done, exit 1 = not done
#
# Verification Methods:
#   GLOB:pattern         → ls $pattern (Datei existiert?)
#   VERIFY:command       → eval $command (Exit Code 0?)
#   STATE:jq_expression  → jq -e ".$expr" workflow-state.json
#   PHASE_STATUS         → phases[N].status == completed|skipped
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

set -e

PHASE=$1
WORKFLOW_FILE=".workflow/workflow-state.json"

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# ═══════════════════════════════════════════════════════════════════════════
# GUARD: Phase als skipped markiert? → done
# NOTE: "completed" ist KEIN Guard mehr! LLM konnte frueh "completed" setzen
# und damit die externe Verifikation umgehen. Jetzt wird IMMER geprueft.
# ═══════════════════════════════════════════════════════════════════════════
PHASE_STATUS=$(jq -r ".phases[\"$PHASE\"].status // \"pending\"" "$WORKFLOW_FILE" 2>/dev/null || echo "pending")
if [ "$PHASE_STATUS" = "skipped" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# DONE-CRITERION AUS PHASE-CONFIG LESEN
# ═══════════════════════════════════════════════════════════════════════════
CRITERION=$(get_phase_criterion "$PHASE")

if [ -z "$CRITERION" ]; then
  # Keine Konfiguration gefunden → nicht done
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# COMPOUND CRITERIA: criterion1+criterion2 (ALL must pass)
# Bash 3.x kompatibel: IFS-Split mit set --
# ═══════════════════════════════════════════════════════════════════════════
if echo "$CRITERION" | grep -q '+'; then
  OLD_IFS="$IFS"
  IFS='+'
  set -- $CRITERION
  IFS="$OLD_IFS"

  for PART; do
    case "$PART" in
      STATE:*)
        JQ_EXPR="${PART#STATE:}"
        if echo "$JQ_EXPR" | grep -q '=='; then
          JQ_PATH=$(echo "$JQ_EXPR" | cut -d'=' -f1)
          JQ_VALUE=$(echo "$JQ_EXPR" | sed 's/.*==//')
          jq -e ".$JQ_PATH == $JQ_VALUE" "$WORKFLOW_FILE" > /dev/null 2>&1 || exit 1
        else
          jq -e ".$JQ_EXPR" "$WORKFLOW_FILE" > /dev/null 2>&1 || exit 1
        fi
        ;;
      GLOB:*)
        PATTERN="${PART#GLOB:}"
        ls $PATTERN > /dev/null 2>&1 || exit 1
        ;;
      VERIFY:*)
        CMD="${PART#VERIFY:}"
        eval "$CMD" > /dev/null 2>&1 || exit 1
        ;;
      *) exit 1 ;;
    esac
  done
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICATION DISPATCH (single criterion)
# ═══════════════════════════════════════════════════════════════════════════
case "$CRITERION" in
  STATE:*)
    # JSON-State-Check auf workflow-state.json
    JQ_EXPR="${CRITERION#STATE:}"
    # Handle == comparisons (e.g., context.testResults.allPassed==true)
    if echo "$JQ_EXPR" | grep -q '=='; then
      # Split on == and build jq expression
      JQ_PATH=$(echo "$JQ_EXPR" | cut -d'=' -f1)
      JQ_VALUE=$(echo "$JQ_EXPR" | sed 's/.*==//')
      jq -e ".$JQ_PATH == $JQ_VALUE" "$WORKFLOW_FILE" > /dev/null 2>&1
    else
      # Simple key existence check
      jq -e ".$JQ_EXPR" "$WORKFLOW_FILE" > /dev/null 2>&1
    fi
    ;;

  VERIFY:*)
    # Command execution — exit code determines done
    CMD="${CRITERION#VERIFY:}"
    eval "$CMD" > /dev/null 2>&1
    ;;

  GLOB:*)
    # File existence via glob pattern
    PATTERN="${CRITERION#GLOB:}"
    ls $PATTERN > /dev/null 2>&1
    ;;

  PHASE_STATUS)
    # Already handled above — if we get here, not done
    exit 1
    ;;

  *)
    # Unknown criterion type → not done
    exit 1
    ;;
esac
