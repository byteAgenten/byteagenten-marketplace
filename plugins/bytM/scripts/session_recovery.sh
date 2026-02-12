#!/bin/bash
# bytM Session Recovery (SessionStart)
# Handles compaction recovery and ownerSessionId updates.
# Outputs recovery prompt on compact, updates session ID on startup/resume.

INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

WORKFLOW_FILE=".workflow/workflow-state.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

# Ownership guard
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
[ "$WORKFLOW_TYPE" = "bytM-feature" ] || exit 0

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
case "$STATUS" in
  active|paused|awaiting_approval) ;;
  *) exit 0 ;;
esac

SOURCE=$(echo "$INPUT" | jq -r '.source // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Update ownerSessionId on startup/resume (session_id changes on resume)
if [ -n "$SESSION_ID" ]; then
  case "$SOURCE" in
    startup|resume)
      jq --arg sid "$SESSION_ID" '.ownerSessionId = $sid' "$WORKFLOW_FILE" > /tmp/bytm-wf-tmp.json \
        && mv /tmp/bytm-wf-tmp.json "$WORKFLOW_FILE"
      ;;
  esac
fi

# Compaction recovery: re-inject workflow context
if [ "$SOURCE" = "compact" ]; then
  ROUND=$(jq -r '.currentRound // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
  ISSUE=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
  TITLE=$(jq -r '.issue.title // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")

  echo "BYTM WORKFLOW RECOVERY (post-compaction)"
  echo "========================================="
  echo "Issue: #${ISSUE} - ${TITLE}"
  echo "Round: ${ROUND}"
  echo "Status: ${STATUS}"
  echo ""
  echo "You are the bytM Team Lead. Read .workflow/workflow-state.json and continue from round '${ROUND}'."
  echo "Your teammates may still be active. Check TaskList for current task status."
  echo "Say 'Done.' to acknowledge recovery."
fi

exit 0
