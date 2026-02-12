#!/bin/bash
# bytM WIP Commit (TeammateIdle)
# Creates WIP commits when a teammate goes idle.
# Does NOT block the teammate (always exits 0).

INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

WORKFLOW_FILE=".workflow/workflow-state.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

# Ownership guard
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
[ "$WORKFLOW_TYPE" = "bytM-feature" ] || exit 0

TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "agent"' 2>/dev/null || echo "agent")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")
ROUND=$(jq -r '.currentRound // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

git add -A 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  MSG="wip(#${ISSUE_NUM}/${TEAMMATE}/${ROUND}): ${ISSUE_TITLE:0:50}"
  git commit -m "$MSG" 2>/dev/null || true
fi

exit 0
