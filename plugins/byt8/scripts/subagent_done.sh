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
# Wir prüfen NICHT auf phase.status == "completed", weil das erst später gesetzt wird.
# Stattdessen: Wenn wir in einer commitbaren Phase sind UND Änderungen vorhanden → commit

if [[ "$CURRENT_PHASE" =~ ^(1|3|4|5|6)$ ]]; then
  # Prüfen ob es Änderungen gibt (staged oder unstaged)
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    COMMIT_MSG="wip(#${ISSUE_NUMBER}/phase-${CURRENT_PHASE}): ${PHASE_NAMES[$CURRENT_PHASE]} done - ${ISSUE_TITLE:0:50}"

    git add -A 2>/dev/null || true
    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      echo "┌─────────────────────────────────────────────────────────────────────┐"
      echo "│ 📦 WIP-COMMIT ERSTELLT                                              │"
      echo "├─────────────────────────────────────────────────────────────────────┤"
      echo "│ $COMMIT_MSG"
      echo "└─────────────────────────────────────────────────────────────────────┘"
      echo ""
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $COMMIT_MSG" >> "$LOG_DIR/hooks.log"
    fi
  else
    echo "│ ℹ️  Phase $CURRENT_PHASE: Keine Änderungen zum Committen"
    echo ""
  fi
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
