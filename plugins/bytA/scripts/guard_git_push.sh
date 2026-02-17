#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Git Push Guard (PreToolUse/Bash Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert git push und gh pr create waehrend aktivem Workflow,
# AUSSER pushApproved=true in workflow-state.json gesetzt ist.
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

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

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Inaktiver Workflow → durchlassen
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "idle" ]; then
  exit 0
fi

# Session-Check: Nur die Workflow-Session blockieren
_CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
_OWNER_SESSION=$(jq -r '.ownerSessionId // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ -n "$_OWNER_SESSION" ] && [ -n "$_CURRENT_SESSION" ] && [ "$_CURRENT_SESSION" != "$_OWNER_SESSION" ]; then
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

# JSON deny Pattern (zuverlaessiger als exit 2, siehe GitHub #13744)
CURRENT_PHASE=$(jq -r '.currentPhase // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
jq -n --arg phase "$CURRENT_PHASE" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("Git Push blockiert. Workflow aktiv (Phase " + $phase + "). Push ist nur in Phase 7 nach User-Approval erlaubt (pushApproved=true). Sage Done. und der Stop-Hook uebernimmt.")
  }
}'
