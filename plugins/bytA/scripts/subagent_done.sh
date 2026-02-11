#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Erstellt deterministische WIP-Commits nach Agent-Abschluss.
# KEIN LLM beteiligt — rein shell-basiert.
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
_HOOK_INPUT=$(cat)
_HOOK_CWD=$(echo "$_HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOG_DIR="${WORKFLOW_DIR}/logs"

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

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# Workflow-Daten (aus workflow-state.json + phases.conf)
CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

PHASE_NAME=$(get_phase_name "$CURRENT_PHASE")
PHASE_AGENT=$(get_phase_agent "$CURRENT_PHASE")

# ═══════════════════════════════════════════════════════════════════════════
# CLEANUP: Subagent-Active Marker entfernen
# ═══════════════════════════════════════════════════════════════════════════
rm -f .workflow/.subagent-active 2>/dev/null || true

# Logging
mkdir -p "$LOG_DIR" 2>/dev/null || true
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$TIMESTAMP] SubagentStop: $PHASE_AGENT (Phase $CURRENT_PHASE)" >> "$LOG_DIR/hooks.log"

# ═══════════════════════════════════════════════════════════════════════════
# COMPACT-REPORT: Context-Kompaktierung aus Agent-Transcript erkennen
# ═══════════════════════════════════════════════════════════════════════════
AGENT_TRANSCRIPT=$(echo "$_HOOK_INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null || echo "")
if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
  COMPACT_COUNT=$(grep -c '"compact_boundary"' "$AGENT_TRANSCRIPT" 2>/dev/null || echo "0")
  if [ "$COMPACT_COUNT" -gt 0 ]; then
    # Peak: hoechster preTokens-Wert aus compact_boundary Entries
    PEAK=$(grep '"compact_boundary"' "$AGENT_TRANSCRIPT" | jq -r '.compactMetadata.preTokens // 0' 2>/dev/null | sort -rn | head -1)
    # Final: letzter total_input aus dem letzten assistant-Turn
    FINAL=$(grep '"assistant"' "$AGENT_TRANSCRIPT" | tail -1 | jq '(.message.usage.input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0)' 2>/dev/null || echo "0")
    # Turns: Anzahl assistant-Eintraege
    TURNS=$(grep -c '"assistant"' "$AGENT_TRANSCRIPT" 2>/dev/null || echo "0")

    REPORT="COMPACT-REPORT: $PHASE_AGENT | compacts=$COMPACT_COUNT | peak=$PEAK | final=$FINAL | turns=$TURNS"
    echo "[$TIMESTAMP] $REPORT" >> "$LOG_DIR/hooks.log"
    echo "⚠ $REPORT"
  fi
fi

# Sichtbare Ausgabe
echo ""
echo "Agent fertig: $PHASE_AGENT | Phase $CURRENT_PHASE ($PHASE_NAME) | Issue #$ISSUE_NUMBER"
echo ""

# WIP-Commit (deterministisch, nur fuer code-produzierende Phasen)
# needs_commit prueft WIP_COMMIT_PHASES aus phases.conf (Phasen 1,3,4,5,6)
if needs_commit "$CURRENT_PHASE"; then
  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${CURRENT_PHASE}): ${PHASE_NAME} - ${ISSUE_TITLE:0:50}"

    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      echo "WIP-Commit: $COMMIT_MSG"
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
    fi
  fi
fi
