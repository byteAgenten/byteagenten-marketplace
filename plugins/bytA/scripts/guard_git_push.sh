#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Git Push Guard (PreToolUse/Bash Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert git push und gh pr create waehrend aktivem Workflow,
# AUSSER pushApproved=true in workflow-state.json gesetzt ist.
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Kein Bash-Befehl → durchlassen
if [ -z "$COMMAND" ] || [ "$COMMAND" = "null" ]; then
  exit 0
fi

# Nur git push und gh pr pruefen
if ! echo "$COMMAND" | grep -qE 'git push|gh pr create'; then
  exit 0
fi

# Kein Workflow → durchlassen
WORKFLOW_FILE=".workflow/workflow-state.json"
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Inaktiver Workflow → durchlassen
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "idle" ]; then
  exit 0
fi

# pushApproved gesetzt? → durchlassen
PUSH_APPROVED=$(jq -r '.pushApproved // false' "$WORKFLOW_FILE" 2>/dev/null || echo "false")
if [ "$PUSH_APPROVED" = "true" ]; then
  exit 0
fi

# BLOCKIEREN
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: $COMMAND (pushApproved=$PUSH_APPROVED)" >> "$LOG_DIR/hooks.log"

echo "PUSH BLOCKIERT! Workflow aktiv (Phase $(jq -r '.currentPhase' "$WORKFLOW_FILE")). Git push/PR ist nur in Phase 9 mit pushApproved=true erlaubt." >&2
exit 2
