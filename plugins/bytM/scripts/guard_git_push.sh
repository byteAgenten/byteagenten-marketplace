#!/bin/bash
# bytM Git Push Guard (PreToolUse/Bash)
# Blocks git push and gh pr create during active bytM workflow.
# Uses JSON permissionDecision: "deny" (PreToolUse pattern).

INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

# Extract command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$COMMAND" ] || [ "$COMMAND" = "null" ] && exit 0

# Only check git push / gh pr create
echo "$COMMAND" | grep -qE 'git push|gh pr create' || exit 0

# Check workflow file
WORKFLOW_FILE=".workflow/workflow-state.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

# Ownership guard: only bytM workflows
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
[ "$WORKFLOW_TYPE" = "bytM-feature" ] || exit 0

# Session isolation: only block the workflow-owning session
_CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
_OWNER_SESSION=$(jq -r '.ownerSessionId // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ -n "$_OWNER_SESSION" ] && [ -n "$_CURRENT_SESSION" ] && [ "$_CURRENT_SESSION" != "$_OWNER_SESSION" ]; then
  exit 0
fi

# Allow if completed
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
[ "$STATUS" = "completed" ] && exit 0

# Allow if push approved
PUSH_APPROVED=$(jq -r '.pushApproved // false' "$WORKFLOW_FILE" 2>/dev/null || echo "false")
[ "$PUSH_APPROVED" = "true" ] && exit 0

# DENY — use JSON pattern for PreToolUse
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "bytM workflow active. Git push/PR only allowed after explicit approval in Round 5 (SHIP)."
  }
}'
exit 0
