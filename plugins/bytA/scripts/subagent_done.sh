#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Erstellt deterministische WIP-Commits nach Agent-Abschluss.
# KEIN LLM beteiligt — rein shell-basiert.
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOG_DIR="${WORKFLOW_DIR}/logs"

if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# Source phase configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../config/phases.conf"

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# Workflow-Daten (aus workflow-state.json + phases.conf)
CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

PHASE_NAME=$(get_phase_name "$CURRENT_PHASE")
PHASE_AGENT=$(get_phase_agent "$CURRENT_PHASE")

# Logging
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStop: $PHASE_AGENT (Phase $CURRENT_PHASE)" >> "$LOG_DIR/hooks.log"

# Sichtbare Ausgabe
echo ""
echo "Agent fertig: $PHASE_AGENT | Phase $CURRENT_PHASE ($PHASE_NAME) | Issue #$ISSUE_NUMBER"
echo ""

# WIP-Commit (deterministisch, nur fuer code-produzierende Phasen)
# needs_commit prueft WIP_COMMIT_PHASES aus phases.conf (Phasen 1,3,4,5,6)
if needs_commit "$CURRENT_PHASE"; then
  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${CURRENT_PHASE}): ${PHASE_NAME} - ${ISSUE_TITLE:0:50}"

    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      echo "WIP-Commit: $COMMIT_MSG"
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
    fi
  fi
fi
