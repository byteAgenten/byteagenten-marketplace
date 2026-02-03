#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert wenn ein Subagent (Task tool) fertig ist.
#
# Zweck:
# 1. Sichtbarkeit - zeigt welcher Agent fertig ist
# 2. WIP-Commits - erstellt automatisch Commits für Phasen 1, 3, 4, 5, 6
#
# WICHTIG: Dieser Hook ist DETERMINISTISCH - er feuert IMMER nach Task()
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOG_DIR="${WORKFLOW_DIR}/logs"

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFEN: Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING (nur wenn Workflow existiert)
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOG_DIR" 2>/dev/null || true

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Nur bei aktivem Workflow anzeigen
if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# WORKFLOW-DATEN LADEN
# ═══════════════════════════════════════════════════════════════════════════
PHASE_NAMES=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Security Audit" "Code Review" "Push & PR")

# currentAgentPhase = Phase bei SubagentStart (gespeichert von subagent_start.sh)
# Fallback auf currentPhase falls nicht gesetzt
CURRENT_PHASE=$(jq -r '.currentAgentPhase // .currentPhase // 0' "$WORKFLOW_FILE")
CURRENT_AGENT=$(jq -r '.currentAgent // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

# ═══════════════════════════════════════════════════════════════════════════
# SICHTBARE AUSGABE
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 🤖 SUBAGENT FERTIG                                                  │"
echo "├─────────────────────────────────────────────────────────────────────┤"
if [ -n "$CURRENT_AGENT" ] && [ "$CURRENT_AGENT" != "null" ]; then
  echo "│ Agent: $CURRENT_AGENT"
else
  echo "│ Agent: (Phase $CURRENT_PHASE Agent)"
fi
echo "│ Phase: $CURRENT_PHASE (${PHASE_NAMES[$CURRENT_PHASE]:-unbekannt})"
echo "│ Issue: #$ISSUE_NUMBER - ${ISSUE_TITLE:0:45}"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# Log
AGENT_LABEL="${CURRENT_AGENT:-Phase $CURRENT_PHASE Agent}"
[ "$AGENT_LABEL" = "null" ] && AGENT_LABEL="Phase $CURRENT_PHASE Agent"
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStop Hook fired: $AGENT_LABEL" >> "$LOG_DIR/hooks.log"
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent finished: $AGENT_LABEL (Phase $CURRENT_PHASE)" >> "$LOG_DIR/hooks.log"

# ═══════════════════════════════════════════════════════════════════════════
# WIP-COMMIT (Deterministisch für Phasen 1, 3, 4, 5, 6)
# ═══════════════════════════════════════════════════════════════════════════
needs_commit() {
  case $1 in
    1|3|4|5|6) return 0 ;;  # true
    *) return 1 ;;          # false
  esac
}

# Safety Net: Agent-basierte Erkennung für Hotfix-Situationen.
# Wenn currentPhase 7 oder 8 ist, aber ein Code-produzierender Agent lief
# (z.B. bei Rückdelegation/Hotfix), trotzdem WIP-Commit erstellen.
agent_produces_code() {
  case "$1" in
    *ui-designer*|*postgresql*|*spring-boot*|*angular-frontend*|*test-engineer*) return 0 ;;
    *) return 1 ;;
  esac
}

get_phase_name() {
  echo "${PHASE_NAMES[$1]:-Phase $1}"
}

if needs_commit $CURRENT_PHASE || agent_produces_code "$CURRENT_AGENT"; then
  # Erst stagen, dann prüfen (git diff erkennt keine untracked files!)
  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    PHASE_NAME=$(get_phase_name $CURRENT_PHASE)

    # Bei Hotfix: Agent-Info in Commit-Message, damit klar ist WAS geändert wurde
    if ! needs_commit $CURRENT_PHASE && agent_produces_code "$CURRENT_AGENT"; then
      # Hotfix-Commit: Phase stimmt nicht mit Agent überein
      AGENT_SHORT="${CURRENT_AGENT##*:}"  # "byt8:angular-frontend-developer" → "angular-frontend-developer"
      COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${CURRENT_PHASE}-hotfix): ${AGENT_SHORT} - ${ISSUE_TITLE:0:50}"
    else
      COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${CURRENT_PHASE}): ${PHASE_NAME} - ${ISSUE_TITLE:0:50}"
    fi

    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      echo "┌─────────────────────────────────────────────────────────────────────┐"
      echo "│ 📦 WIP-COMMIT ERSTELLT                                              │"
      echo "├─────────────────────────────────────────────────────────────────────┤"
      echo "│ $COMMIT_MSG"
      echo "└─────────────────────────────────────────────────────────────────────┘"
      echo ""
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
    fi
  fi
fi
