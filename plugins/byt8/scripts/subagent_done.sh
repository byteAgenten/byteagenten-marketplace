#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert wenn ein Subagent fertig ist.
# - Validiert die Outputs je nach Agent-Typ
# - Erstellt WIP-Commits nach commitbaren Phasen
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStop Hook fired" >> "$LOG_DIR/hooks.log"

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

# Prüfen ob Workflow aktiv
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ]; then
  exit 0
fi

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

# Phase-Namen für Commit-Messages
PHASE_NAMES=("Tech-Spec" "Wireframes" "API-Design" "Migrations" "Backend" "Frontend" "E2E-Tests" "Review" "PR")

# ═══════════════════════════════════════════════════════════════════════════
# WIP-COMMIT LOGIK
# ═══════════════════════════════════════════════════════════════════════════
# Commitbare Phasen: 1 (Wireframes), 3 (Migrations), 4 (Backend), 5 (Frontend), 6 (E2E)
# Nicht commitbar: 0 (nur Doku), 2 (nur Doku), 7 (Review), 8 (finaler Commit)

create_wip_commit() {
  local phase=$1
  local phase_name="${PHASE_NAMES[$phase]}"
  
  # Prüfen ob es unstaged changes gibt
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Phase $phase: No changes to commit" >> "$LOG_DIR/hooks.log"
    return 0
  fi
  
  # WIP-Commit erstellen
  local commit_msg="wip(#${ISSUE_NUMBER}/phase-${phase}): ${phase_name} done - ${ISSUE_TITLE:0:50}"
  
  git add -A 2>/dev/null || true
  if git commit -m "$commit_msg" 2>/dev/null; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit created: $commit_msg" >> "$LOG_DIR/hooks.log"
    echo ""
    echo "📦 WIP-Commit: $commit_msg"
    echo ""
    return 0
  fi
  return 1
}

# Track welche Phase zuletzt committed wurde
LAST_COMMITTED_FILE="${WORKFLOW_DIR}/.last-wip-phase"
LAST_COMMITTED_PHASE=-1
if [ -f "$LAST_COMMITTED_FILE" ]; then
  LAST_COMMITTED_PHASE=$(cat "$LAST_COMMITTED_FILE" 2>/dev/null || echo "-1")
fi

# Wenn die aktuelle Phase höher ist als die zuletzt committete
# UND die vorherige Phase commitbar war → WIP-Commit für vorherige Phase
if [ "$CURRENT_PHASE" -gt "$LAST_COMMITTED_PHASE" ]; then
  # Prüfe alle Phasen zwischen lastCommitted+1 und currentPhase-1
  for (( phase=LAST_COMMITTED_PHASE+1; phase<CURRENT_PHASE; phase++ )); do
    # Nur commitbare Phasen: 1, 3, 4, 5, 6
    if [[ "$phase" =~ ^(1|3|4|5|6)$ ]]; then
      PHASE_STATUS=$(jq -r ".phases[\"$phase\"].status // \"\"" "$WORKFLOW_FILE" 2>/dev/null || echo "")
      if [[ "$PHASE_STATUS" == "completed" ]]; then
        create_wip_commit "$phase"
      fi
    fi
  done
  
  # Auch aktuelle Phase prüfen wenn sie commitbar und completed ist
  if [[ "$CURRENT_PHASE" =~ ^(1|3|4|5|6)$ ]]; then
    PHASE_STATUS=$(jq -r ".phases[\"$CURRENT_PHASE\"].status // \"\"" "$WORKFLOW_FILE" 2>/dev/null || echo "")
    if [[ "$PHASE_STATUS" == "completed" ]]; then
      create_wip_commit "$CURRENT_PHASE"
    fi
  fi
  
  # Update tracker
  echo "$CURRENT_PHASE" > "$LAST_COMMITTED_FILE"
fi

# ═══════════════════════════════════════════════════════════════════════════
# AGENT-SPEZIFISCHE VALIDIERUNG (optional, nur Logging)
# ═══════════════════════════════════════════════════════════════════════════

CURRENT_AGENT=$(jq -r '.currentAgent // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")

validate_output() {
  case "$CURRENT_AGENT" in
    *"architect-planner"*)
      jq -e '.context.technicalSpec' "$WORKFLOW_FILE" > /dev/null 2>&1
      ;;
    *"ui-designer"*)
      ls wireframes/*.html > /dev/null 2>&1 || ls wireframes/*.svg > /dev/null 2>&1
      ;;
    *"api-architect"*)
      jq -e '.context.apiDesign' "$WORKFLOW_FILE" > /dev/null 2>&1
      ;;
    *"postgresql-architect"*)
      ls backend/src/main/resources/db/migration/V*.sql > /dev/null 2>&1
      ;;
    *"spring-boot-developer"*)
      [ -d "backend" ] && (cd backend && mvn compile -q 2>/dev/null)
      ;;
    *"angular-frontend-developer"*)
      [ -d "frontend" ] && (cd frontend && npm run build --silent 2>/dev/null)
      ;;
    *)
      return 0
      ;;
  esac
}

if [ -n "$CURRENT_AGENT" ] && [ "$CURRENT_AGENT" != "null" ]; then
  if validate_output 2>/dev/null; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent $CURRENT_AGENT: Output OK" >> "$LOG_DIR/hooks.log"
  else
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent $CURRENT_AGENT: Validation warning" >> "$LOG_DIR/hooks.log"
  fi
fi
