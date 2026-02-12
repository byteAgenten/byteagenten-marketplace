#!/bin/bash
# bytM Completion Sound (Stop)
# Plays completion sound when workflow status is "completed".

INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

WORKFLOW_FILE=".workflow/workflow-state.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

# Ownership guard
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
[ "$WORKFLOW_TYPE" = "bytM-feature" ] || exit 0

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
[ "$STATUS" = "completed" ] || exit 0

# Only play once (check flag)
SOUND_PLAYED=$(jq -r '.completionSoundPlayed // false' "$WORKFLOW_FILE" 2>/dev/null || echo "false")
[ "$SOUND_PLAYED" = "true" ] && exit 0

# Set flag to prevent replaying
jq '.completionSoundPlayed = true' "$WORKFLOW_FILE" > /tmp/bytm-wf-tmp.json \
  && mv /tmp/bytm-wf-tmp.json "$WORKFLOW_FILE"

# Play completion sound
SOUND_DIR="${CLAUDE_PLUGIN_ROOT:-}/assets/sounds"
if [ -f "$SOUND_DIR/completion.wav" ]; then
  afplay "$SOUND_DIR/completion.wav" 2>/dev/null &
elif [ -f "/System/Library/Sounds/Funk.aiff" ]; then
  afplay "/System/Library/Sounds/Funk.aiff" 2>/dev/null &
fi

exit 0
