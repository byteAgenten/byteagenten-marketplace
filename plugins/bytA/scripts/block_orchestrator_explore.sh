#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Orchestrator Explore-Blocker (PreToolUse/Task Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Explore/general-purpose Agents zu starten.
# Erlaubt: bytA:* Agents (spezialisierte Phase-Agents)
# Blockiert: Explore, general-purpose
#
# Skill-scoped Hook → feuert NUR fuer Orchestrator, NICHT fuer Subagents
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')

# Kein subagent_type → kein Task-Aufruf → durchlassen
if [ -z "$SUBAGENT_TYPE" ] || [ "$SUBAGENT_TYPE" = "null" ]; then
  exit 0
fi

# bytA:* Agents → erlauben
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

    echo "ORCHESTRATOR DARF NICHT EXPLORIEREN! Task($SUBAGENT_TYPE) blockiert. Delegiere an bytA:AGENT." >&2
    exit 2
    ;;
esac

# Alles andere → durchlassen
exit 0
