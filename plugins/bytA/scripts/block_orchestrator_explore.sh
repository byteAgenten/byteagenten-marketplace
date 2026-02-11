#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Orchestrator Explore-Blocker (PreToolUse/Task Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Explore/general-purpose Agents zu starten.
# Erlaubt: bytA:* Agents (spezialisierte Phase-Agents)
# Blockiert: Explore, general-purpose
#
# Plugin-level Hook → feuert fuer ALLE Tool-Aufrufe (Orchestrator + Subagents)
# → Ownership Guard: nur bei aktivem bytA-feature Workflow
# → Subagent-Check: erlaubt wenn .subagent-active Marker existiert
# → JSON deny Pattern: zuverlaessiger als exit 2 (GitHub #13744)
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur bei aktivem bytA-feature Workflow blockieren
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
# SUBAGENT CHECK: Wenn Subagent aktiv → durchlassen
# ═══════════════════════════════════════════════════════════════════════════
if [ -f ".workflow/.subagent-active" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUBAGENT-TYP PRUEFEN
# ═══════════════════════════════════════════════════════════════════════════
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')

# Kein subagent_type → kein Task-Aufruf → durchlassen
if [ -z "$SUBAGENT_TYPE" ] || [ "$SUBAGENT_TYPE" = "null" ]; then
  exit 0
fi

# bytA:* Agents → erlauben (spezialisierte Phase-Agents)
case "$SUBAGENT_TYPE" in
  bytA:*)
    exit 0
    ;;
esac

# Explore und general-purpose → BLOCKIEREN
case "$SUBAGENT_TYPE" in
  Explore|general-purpose)
    LOG_DIR=".workflow/logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: Orchestrator tried Task($SUBAGENT_TYPE)" >> "$LOG_DIR/hooks.log"

    # JSON deny Pattern (zuverlaessiger als exit 2)
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "ORCHESTRATOR DARF NICHT EXPLORIEREN! Task('"$SUBAGENT_TYPE"') blockiert. Delegiere an bytA:AGENT. Sage Done. und der Stop-Hook gibt dir den naechsten Task."
      }
    }'
    exit 0
    ;;
esac

# Alles andere (Bash, Plan, etc.) → durchlassen
exit 0
