#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert wenn ein Subagent fertig ist.
# - Zeigt sichtbare Ausgabe welcher Agent fertig ist
# - Erstellt WIP-Commits für commitbare Phasen (1, 3, 4, 5, 6)
# - Validiert die Outputs je nach Agent-Typ
#
# NOTE: WIP-Commits werden hier erstellt, weil der Stop Hook nur feuert wenn
#       der HAUPT-Agent fertig ist - nicht zwischen Subagent-Phasen!
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOG_DIR="${WORKFLOW_DIR}/logs"

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStop Hook fired" >> "$LOG_DIR/hooks.log"

# Prüfen ob Workflow aktiv
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# WORKFLOW-DATEN LADEN
# ═══════════════════════════════════════════════════════════════════════════
# Phase-Namen (muss vor Verwendung definiert sein)
PHASE_NAMES=("Tech-Spec" "Wireframes" "API-Design" "Migrations" "Backend" "Frontend" "E2E-Tests" "Review" "PR")

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
CURRENT_AGENT=$(jq -r '.currentAgent // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
ISSUE_NUMBER=$(jq -r '.issue.number // 0' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")

# ═══════════════════════════════════════════════════════════════════════════
# SICHTBARE AUSGABE: Welcher Agent ist fertig?
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│ 🤖 SUBAGENT FERTIG                                                  │"
echo "├─────────────────────────────────────────────────────────────────────┤"
if [ -n "$CURRENT_AGENT" ] && [ "$CURRENT_AGENT" != "null" ]; then
  echo "│ Agent: $CURRENT_AGENT"
else
  echo "│ Agent: (unbekannt)"
fi
echo "│ Phase: $CURRENT_PHASE (${PHASE_NAMES[$CURRENT_PHASE]:-unbekannt})"
echo "│ Issue: #$ISSUE_NUMBER - ${ISSUE_TITLE:0:45}"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# WIP-COMMIT LOGIK
# ═══════════════════════════════════════════════════════════════════════════
# Commitbare Phasen: 1 (Wireframes), 3 (Migrations), 4 (Backend), 5 (Frontend), 6 (E2E)
# Nicht commitbar: 0 (nur Doku), 2 (nur Doku), 7 (Review), 8 (finaler Commit)
#
# WICHTIG: Pfad-basierte Commits um Phasen-Dateien zu trennen!
# Jede Phase committed nur IHRE Dateien, nicht alle Änderungen.
#
# Phase-Pfade:
#   1 (Wireframes): wireframes/
#   3 (Migrations): **/db/migration/
#   4 (Backend):    backend/ (ohne migrations)
#   5 (Frontend):   frontend/
#   6 (E2E):        e2e/, playwright/, tests/

# Tracking welche Phasen schon committed wurden
COMMITTED_PHASES_FILE="${WORKFLOW_DIR}/.committed-phases"
touch "$COMMITTED_PHASES_FILE" 2>/dev/null || true

phase_committed() {
  grep -q "^$1$" "$COMMITTED_PHASES_FILE" 2>/dev/null
}

mark_phase_committed() {
  echo "$1" >> "$COMMITTED_PHASES_FILE"
}

# Funktion: Commit nur bestimmte Pfade für eine Phase
commit_phase_files() {
  local PHASE=$1
  local PHASE_NAME=$2
  shift 2
  local PATHS=("$@")

  # Prüfen ob es Änderungen in diesen Pfaden gibt
  local HAS_CHANGES=false
  for P in "${PATHS[@]}"; do
    if git status --porcelain "$P" 2>/dev/null | grep -q .; then
      HAS_CHANGES=true
      break
    fi
  done

  if [ "$HAS_CHANGES" = true ]; then
    COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${PHASE}): ${PHASE_NAME} - ${ISSUE_TITLE:0:50}"

    # Nur die Phase-spezifischen Pfade stagen
    for P in "${PATHS[@]}"; do
      git add "$P" 2>/dev/null || true
    done

    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      echo "┌─────────────────────────────────────────────────────────────────────┐"
      echo "│ 📦 WIP-COMMIT ERSTELLT (Phase $PHASE)                                        │"
      echo "├─────────────────────────────────────────────────────────────────────┤"
      echo "│ $COMMIT_MSG"
      echo "└─────────────────────────────────────────────────────────────────────┘"
      echo ""
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
      mark_phase_committed "$PHASE"
      return 0
    fi
  fi
  return 1
}

# ───────────────────────────────────────────────────────────────────────────
# SCHRITT 1: Aktuelle Phase committen (nur nicht-Approval Phasen: 3, 4, 5)
# ───────────────────────────────────────────────────────────────────────────

case "$CURRENT_PHASE" in
  3)
    # Migrations - spezifischer Pfad
    if ! phase_committed 3; then
      commit_phase_files 3 "Migrations done" \
        "backend/src/main/resources/db/migration" \
        "**/db/migration"
    fi
    ;;
  4)
    # Backend - ohne migrations
    if ! phase_committed 4; then
      # Erst Migrations committen falls noch offen (von Phase 3)
      if ! phase_committed 3; then
        commit_phase_files 3 "Migrations done" \
          "backend/src/main/resources/db/migration" \
          "**/db/migration"
      fi
      # Dann Backend (alles außer migrations)
      # git add backend, dann unstage migrations
      if git status --porcelain backend/ 2>/dev/null | grep -v "db/migration" | grep -q .; then
        COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-4): Backend done - ${ISSUE_TITLE:0:50}"
        git add backend/ 2>/dev/null || true
        git reset HEAD backend/src/main/resources/db/migration 2>/dev/null || true
        if git commit -m "$COMMIT_MSG" 2>/dev/null; then
          echo "┌─────────────────────────────────────────────────────────────────────┐"
          echo "│ 📦 WIP-COMMIT ERSTELLT (Phase 4)                                        │"
          echo "├─────────────────────────────────────────────────────────────────────┤"
          echo "│ $COMMIT_MSG"
          echo "└─────────────────────────────────────────────────────────────────────┘"
          echo ""
          echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
          mark_phase_committed 4
        fi
      fi
    fi
    ;;
  5)
    # Frontend
    if ! phase_committed 5; then
      commit_phase_files 5 "Frontend done" "frontend/"
    fi
    ;;
  1)
    # Wireframes - Approval-Gate, nur Info
    echo "│ ⏳ Phase 1 (Wireframes): Warte auf Approval"
    echo ""
    ;;
  6)
    # E2E Tests - Approval-Gate, nur Info
    echo "│ ⏳ Phase 6 (E2E-Tests): Warte auf Approval"
    echo ""
    ;;
esac

# ───────────────────────────────────────────────────────────────────────────
# SCHRITT 2: Approval-Gate Phasen committen die wir VERLASSEN haben
# ───────────────────────────────────────────────────────────────────────────

# Phase 1 (Wireframes): Commit wenn wir in Phase 2+ sind
if [ "$CURRENT_PHASE" -ge 2 ] && ! phase_committed 1; then
  commit_phase_files 1 "Wireframes approved" "wireframes/"
fi

# Phase 6 (E2E): Commit wenn wir in Phase 7+ sind
if [ "$CURRENT_PHASE" -ge 7 ] && ! phase_committed 6; then
  commit_phase_files 6 "E2E-Tests approved" "e2e/" "playwright/" "tests/"
fi

# ═══════════════════════════════════════════════════════════════════════════
# AGENT-SPEZIFISCHE VALIDIERUNG
# ═══════════════════════════════════════════════════════════════════════════

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
    echo "│ ✅ Output-Validierung: OK"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent $CURRENT_AGENT: Output OK" >> "$LOG_DIR/hooks.log"
  else
    echo "│ ⚠️  Output-Validierung: Warnung (erwartete Dateien fehlen)"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Agent $CURRENT_AGENT: Validation warning" >> "$LOG_DIR/hooks.log"
  fi
fi

echo ""
