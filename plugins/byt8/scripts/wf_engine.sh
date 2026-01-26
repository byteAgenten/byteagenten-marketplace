#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Engine (Stop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert nach JEDEM Tool-Call während des Workflows.
# Verantwortlich für:
# - Phase Validation (Done-Checks)
# - Auto-Commits bei erfolgreichen Phasen
# - Retry-Management
# - Context-Snapshots
# - Approval Gates
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR"
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Stop Hook fired" >> "$LOG_DIR/hooks.log"

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
CONTEXT_DIR="${WORKFLOW_DIR}/context"
RECOVERY_DIR="${WORKFLOW_DIR}/recovery"
LOGS_DIR="${WORKFLOW_DIR}/logs"

MAX_RETRIES=3

# ═══════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════

ensure_dirs() {
  mkdir -p "$CONTEXT_DIR" "$RECOVERY_DIR" "$LOGS_DIR"
}

get_retry_count() {
  local phase=$1
  if [ -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    jq -r ".phase_${phase} // 0" "${RECOVERY_DIR}/retry-tracker.json" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

increment_retry() {
  local phase=$1
  ensure_dirs
  
  if [ ! -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    echo "{}" > "${RECOVERY_DIR}/retry-tracker.json"
  fi
  
  local current=$(get_retry_count $phase)
  local new=$((current + 1))
  
  jq ".phase_${phase} = ${new}" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp"
  mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
}

reset_retry() {
  local phase=$1
  
  if [ -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    jq "del(.phase_${phase})" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp"
    mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
  fi
}

save_context_snapshot() {
  local phase=$1
  local phase_name=$2
  local context_data=$3
  
  ensure_dirs
  
  local snapshot_file="${CONTEXT_DIR}/phase-${phase}-${phase_name}.json"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  echo "{
    \"phase\": ${phase},
    \"completedAt\": \"${timestamp}\",
    \"summary\": ${context_data}
  }" | jq '.' > "$snapshot_file"
  
  # Auch als last-checkpoint speichern
  cp "$snapshot_file" "${RECOVERY_DIR}/last-checkpoint.json"
}

log_transition() {
  local from_phase=$1
  local to_phase=$2
  local reason=$3
  
  ensure_dirs
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  echo "{\"timestamp\":\"${timestamp}\",\"from\":${from_phase},\"to\":${to_phase},\"reason\":\"${reason}\"}" >> "${LOGS_DIR}/transitions.jsonl"
}

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFUNG: Aktiver Workflow?
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ]; then
  exit 0
fi

ensure_dirs

PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")

# ═══════════════════════════════════════════════════════════════════════════
# APPROVAL GATE CHECK
# ═══════════════════════════════════════════════════════════════════════════

NEXT_ACTION=$(jq -r '.nextStep.action // ""' "$WORKFLOW_FILE")

if [ "$NEXT_ACTION" == "AWAIT_USER_APPROVAL" ]; then
  echo ""
  echo "⏳ Warte auf User-Approval für Phase $PHASE"
  echo "   Antworte mit 'Ja' zum Fortfahren oder gib Feedback."
  echo ""
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-SPEZIFISCHE DONE-CHECKS
# ═══════════════════════════════════════════════════════════════════════════

check_done() {
  case $PHASE in
    0) # Tech Spec existiert?
       jq -e '.context.technicalSpec.data' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    1) # Wireframes existieren?
       ls wireframes/*.html > /dev/null 2>&1 || ls wireframes/*.svg > /dev/null 2>&1
       ;;
    2) # API Design existiert?
       jq -e '.context.apiDesign.data' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    3) # Migrations existieren?
       ls backend/src/main/resources/db/migration/V*.sql > /dev/null 2>&1
       ;;
    4) # Backend Tests PASS?
       if [ -d "backend" ]; then
         cd backend && mvn test -q 2>&1 | tail -5 | grep -q "BUILD SUCCESS"
         return $?
       else
         return 0
       fi
       ;;
    5) # Frontend Tests PASS?
       if [ -d "frontend" ]; then
         cd frontend && npm test -- --no-watch --browsers=ChromeHeadless 2>&1 | grep -q "SUCCESS"
         return $?
       else
         return 0
       fi
       ;;
    6) # E2E Tests PASS?
       if [ -f "playwright.config.ts" ] || [ -f "playwright.config.js" ]; then
         npx playwright test --reporter=list 2>&1 | grep -q "passed"
         return $?
       else
         return 0
       fi
       ;;
    7) # Review APPROVED?
       jq -e '.context.reviewFeedback.data.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    8) # PR erstellt?
       jq -e '.phases["8"].prUrl' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    *)
       return 0
       ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# ERGEBNIS VERARBEITEN
# ═══════════════════════════════════════════════════════════════════════════

PHASE_NAMES=("spec" "wireframes" "api" "migrations" "backend" "frontend" "tests" "review" "pr")
PHASE_DISPLAY=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Review" "PR")

if check_done; then
  # ═══════════════════════════════════════════════════════════════════════
  # ✅ PHASE ERFOLGREICH
  # ═══════════════════════════════════════════════════════════════════════
  
  # Retry-Counter zurücksetzen
  reset_retry $PHASE
  
  # Context-Snapshot speichern (aus workflow-state.json extrahieren)
  if jq -e '.context' "$WORKFLOW_FILE" > /dev/null 2>&1; then
    CONTEXT_DATA=$(jq '.context' "$WORKFLOW_FILE")
    save_context_snapshot $PHASE "${PHASE_NAMES[$PHASE]}" "$CONTEXT_DATA"
  fi
  
  # WIP-Commit (nur für commitbare Phasen: 1, 3, 4, 5, 6)
  if [[ "$PHASE" =~ ^(1|3|4|5|6)$ ]]; then
    ISSUE=$(jq -r '.issue.number // "0"' "$WORKFLOW_FILE")
    TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")
    git add -A 2>/dev/null || true
    git commit -m "wip(#${ISSUE}/phase-${PHASE}): ${PHASE_DISPLAY[$PHASE]} done - ${TITLE:0:50}" 2>/dev/null || true
  fi
  
  # Nächste Phase
  NEXT_PHASE=$((PHASE + 1))
  
  # Approval Gates nach Phase 0, 1, 6, 7
  if [[ "$PHASE" =~ ^(0|1|6|7)$ ]]; then
    jq --argjson np "$NEXT_PHASE" '
      .phases[(.currentPhase|tostring)].status = "completed" |
      .currentPhase = $np |
      .nextStep.action = "AWAIT_USER_APPROVAL" |
      .nextStep.phase = $np |
      .nextStep.description = "User-Approval erforderlich"
    ' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Phase $PHASE (${PHASE_DISPLAY[$PHASE]}) ABGESCHLOSSEN!                   "
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                               ║"
    echo "║  ⏳ APPROVAL GATE                                                             ║"
    echo "║                                                                               ║"
    echo "║  Bist du zufrieden mit dem Ergebnis von Phase $PHASE?                        "
    echo "║                                                                               ║"
    echo "║  → 'Ja' oder 'Weiter' zum Fortfahren mit Phase $NEXT_PHASE                  "
    echo "║  → Feedback eingeben für Änderungen                                          ║"
    echo "║                                                                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
  else
    # Automatisch zur nächsten Phase
    jq --argjson np "$NEXT_PHASE" '
      .phases[(.currentPhase|tostring)].status = "completed" |
      .currentPhase = $np |
      .nextStep.action = "START_PHASE" |
      .nextStep.phase = $np |
      .nextStep.description = "Phase \($np) starten"
    ' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    
    echo ""
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo "✅ Phase $PHASE (${PHASE_DISPLAY[$PHASE]}) → Phase $NEXT_PHASE (${PHASE_DISPLAY[$NEXT_PHASE]})"
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo ""
  fi
  
  log_transition $PHASE $NEXT_PHASE "completed"
  
else
  # ═══════════════════════════════════════════════════════════════════════
  # ❌ PHASE NICHT FERTIG / FEHLGESCHLAGEN
  # ═══════════════════════════════════════════════════════════════════════
  
  # Nur bei Test-Phasen Retry zählen (Phase 4, 5, 6)
  if [[ "$PHASE" =~ ^(4|5|6)$ ]]; then
    RETRY_COUNT=$(get_retry_count $PHASE)
    increment_retry $PHASE
    NEW_RETRY=$((RETRY_COUNT + 1))
    
    # State aktualisieren
    jq --argjson rc "$NEW_RETRY" '.retryCount = $rc' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    
    if [ $NEW_RETRY -ge $MAX_RETRIES ]; then
      # Max Retries erreicht → Pausieren
      jq '.status = "paused" | .pauseReason = "max_retries"' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
      
      echo ""
      echo "╔══════════════════════════════════════════════════════════════════════════════╗"
      echo "║  🛑 MAX RETRIES ERREICHT (${MAX_RETRIES}/${MAX_RETRIES})                                            ║"
      echo "╠══════════════════════════════════════════════════════════════════════════════╣"
      echo "║                                                                               ║"
      echo "║  Phase $PHASE (${PHASE_DISPLAY[$PHASE]}) konnte nach $MAX_RETRIES Versuchen             "
      echo "║  nicht abgeschlossen werden.                                                  ║"
      echo "║                                                                               ║"
      echo "║  OPTIONEN:                                                                    ║"
      echo "║  → /wf:retry-reset    Retry-Counter zurücksetzen                             ║"
      echo "║  → /wf:skip           Phase überspringen (nicht empfohlen)                   ║"
      echo "║  → Manuell fixen und /wf:resume                                              ║"
      echo "║                                                                               ║"
      echo "╚══════════════════════════════════════════════════════════════════════════════╝"
      echo ""
      
      log_transition $PHASE $PHASE "max_retries"
      exit 0
    fi
    
    # Noch Retries übrig → Fehler-Feedback
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "⚠️  PHASE $PHASE (${PHASE_DISPLAY[$PHASE]}) - DONE-KRITERIEN NICHT ERFÜLLT (${NEW_RETRY}/${MAX_RETRIES})"
    echo "══════════════════════════════════════════════════════════════════════════════"
    
    case $PHASE in
      4)
        echo ""
        echo "Backend-Tests fehlgeschlagen."
        if [ -d "backend" ]; then
          echo "Letzte Test-Fehler:"
          cd backend && mvn test 2>&1 | grep -A5 "FAILURE\|ERROR" | head -20 || true
        fi
        echo ""
        echo "→ Bitte Fehler beheben und erneut versuchen."
        ;;
      5)
        echo ""
        echo "Frontend-Tests fehlgeschlagen."
        echo "→ Bitte Fehler beheben und erneut versuchen."
        ;;
      6)
        echo ""
        echo "E2E-Tests fehlgeschlagen."
        echo "→ Hotfix-Loop: Fehler in Backend/Frontend beheben."
        ;;
    esac
    
    echo ""
    echo "Escape-Commands: /wf:pause, /wf:retry-reset, /wf:status"
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    log_transition $PHASE $PHASE "retry_$NEW_RETRY"
  fi
  # Für andere Phasen: Keine Aktion (noch nicht fertig ist normal)
fi
