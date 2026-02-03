#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA WIP-Commit Script (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Creates WIP commits after implementation phases.
# Minimal logic - just commit if there are changes.
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Read hook input
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")

# Only commit for implementation agents
case "$AGENT_TYPE" in
  bytA-backend-dev|bytA-frontend-dev|bytA-db-architect|bytA-test-engineer)
    # Check if there are changes to commit
    if git diff --quiet && git diff --cached --quiet; then
      exit 0  # No changes
    fi

    # Get issue number from .workflow/state.json
    ISSUE_NUM="?"
    if [ -f ".workflow/state.json" ]; then
      ISSUE_NUM=$(jq -r '.issue // "?"' .workflow/state.json 2>/dev/null || echo "?")
    fi

    # Create WIP commit
    git add -A
    git commit -m "wip(#${ISSUE_NUM}): ${AGENT_TYPE} changes" --no-verify 2>/dev/null || true
    ;;
esac

exit 0
