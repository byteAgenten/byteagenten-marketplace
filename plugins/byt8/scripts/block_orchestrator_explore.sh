#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Orchestrator Explore-Blocker (PreToolUse Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Explore/general-purpose Agents zu starten.
# Erlaubt: byt8:* Agents (spezialisierte Phase-Agents)
# Blockiert: Explore, general-purpose (Orchestrator soll delegieren, nicht explorieren)
#
# Skill-scoped Hook → feuert NUR für Orchestrator, NICHT für Subagents
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')

# Kein subagent_type → kein Task-Aufruf → durchlassen
if [ -z "$SUBAGENT_TYPE" ] || [ "$SUBAGENT_TYPE" = "null" ]; then
  exit 0
fi

# byt8:* Agents → erlauben (spezialisierte Phase-Agents)
case "$SUBAGENT_TYPE" in
  byt8:*)
    exit 0
    ;;
esac

# Explore und general-purpose → BLOCKIEREN
case "$SUBAGENT_TYPE" in
  Explore|general-purpose)
    LOG_DIR=".workflow/logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: Orchestrator tried Task($SUBAGENT_TYPE)" >> "$LOG_DIR/hooks.log"

    echo "⛔ ORCHESTRATOR DARF NICHT EXPLORIEREN! Task($SUBAGENT_TYPE) blockiert. Delegiere die Arbeit an den zustaendigen byt8:AGENT via Task(byt8:AGENT). Bei Rollback-Entscheidungen: User fragen statt selbst explorieren." >&2
    exit 2
    ;;
esac

# Alles andere → durchlassen
exit 0
