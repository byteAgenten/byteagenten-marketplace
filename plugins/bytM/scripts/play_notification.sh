#!/bin/bash
# bytM Notification Sound (Notification/idle_prompt)
# Plays notification sound when user input is needed during active workflow.

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

# Session isolation: only play for workflow-owning session
_CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
_OWNER_SESSION=$(jq -r '.ownerSessionId // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ -n "$_OWNER_SESSION" ] && [ -n "$_CURRENT_SESSION" ] && [ "$_CURRENT_SESSION" != "$_OWNER_SESSION" ]; then
  exit 0
fi

# Play notification sound
SOUND_DIR="${CLAUDE_PLUGIN_ROOT:-}/assets/sounds"
if [ -f "$SOUND_DIR/notification.wav" ]; then
  afplay "$SOUND_DIR/notification.wav" 2>/dev/null &
elif [ -f "/System/Library/Sounds/Glass.aiff" ]; then
  afplay "/System/Library/Sounds/Glass.aiff" 2>/dev/null &
fi

exit 0
