#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA SubagentStart Hook — Subagent-Active Marker
# ═══════════════════════════════════════════════════════════════════════════
# Creates .workflow/.subagent-active marker when a subagent starts.
# This allows plugin-level PreToolUse blockers to distinguish orchestrator
# tool calls (BLOCK) from subagent tool calls (ALLOW).
#
# Plugin-level hooks fire globally for ALL tool calls (main + subagent).
# Without this marker, the code-edit/read blockers would also block
# subagents from doing their actual work.
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix
INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Only process bytA-feature workflows
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_FILE=".workflow/workflow-state.json"
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# CREATE MARKER: Signal that a subagent is active
# ═══════════════════════════════════════════════════════════════════════════
touch .workflow/.subagent-active 2>/dev/null || true

exit 0
