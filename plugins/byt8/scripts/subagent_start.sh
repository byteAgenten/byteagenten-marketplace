#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Subagent Start Handler (SubagentStart Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert wenn ein Subagent (Task tool) gestartet wird.
#
# Zweck:
# 1. AUTO-CLEANUP: Abgeschlossene Workflows deterministisch aufräumen
# 2. Sichtbarkeit - zeigt welcher Agent startet
# 3. Logging - protokolliert Agent-Starts für Debugging
#
# Input (stdin JSON): agent_id, agent_type
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# INPUT LESEN
# ═══════════════════════════════════════════════════════════════════════════
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOG_DIR="${WORKFLOW_DIR}/logs"

# ═══════════════════════════════════════════════════════════════════════════
# AUTO-CLEANUP: Abgeschlossene Workflows aufräumen (DETERMINISTISCH)
# ═══════════════════════════════════════════════════════════════════════════
# Läuft bei JEDEM Task()-Aufruf, aber nur wenn status=completed.
# Das stellt sicher, dass alte Workflows automatisch aufgeräumt werden,
# bevor ein neuer Workflow oder Agent startet.
# ═══════════════════════════════════════════════════════════════════════════
if [ -f "$WORKFLOW_FILE" ]; then
  CLEANUP_STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
  CLEANUP_WORKFLOW=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
  if [ "$CLEANUP_STATUS" = "completed" ] && [ "$CLEANUP_WORKFLOW" = "full-stack-feature" ]; then
    # Eigener abgeschlossener Workflow gefunden → aufräumen
    rm -rf "$WORKFLOW_DIR"
    # Kein weiterer Code nötig, exit 0
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFEN: Workflow vorhanden? (nach potentiellem Cleanup)
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "full-stack-feature" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING (nur wenn Workflow existiert)
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStart Hook fired: $AGENT_TYPE" >> "$LOG_DIR/hooks.log"

# Save agent type to workflow state for SubagentStop hook
if [ "$AGENT_TYPE" != "unknown" ]; then
  jq --arg agent "$AGENT_TYPE" '.currentAgent = $agent | .currentAgentPhase = .currentPhase' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" 2>/dev/null && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE" || true
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Nur bei aktivem Workflow anzeigen
if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# WORKFLOW-DATEN LADEN
# ═══════════════════════════════════════════════════════════════════════════
PHASE_NAMES=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Security Audit" "Code Review" "Push & PR")

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

# ═══════════════════════════════════════════════════════════════════════════
# SICHTBARE AUSGABE
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ ▶ SUBAGENT GESTARTET                                                │"
echo "├─────────────────────────────────────────────────────────────────────┤"
echo "│ Agent: $AGENT_TYPE"
echo "│ Phase: $CURRENT_PHASE (${PHASE_NAMES[$CURRENT_PHASE]:-unbekannt})"
echo "│ Issue: #$ISSUE_NUMBER - ${ISSUE_TITLE:0:45}"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# Log
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent started: $AGENT_TYPE (Phase $CURRENT_PHASE)" >> "$LOG_DIR/hooks.log"
