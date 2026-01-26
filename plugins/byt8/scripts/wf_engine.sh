#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Engine (Stop Hook) - Ralph Wiggum Pattern
# ═══════════════════════════════════════════════════════════════════════════
# Feuert am Ende JEDER Claude-Antwort.
#
# Kernprinzip: EINE Phase pro Aufruf
# 1. Claude führt EINE Phase aus und stoppt
# 2. Dieser Hook validiert und entscheidet über nächsten Schritt
# 3. User sieht klare Anweisungen was zu tun ist
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
CONTEXT_DIR="${WORKFLOW_DIR}/context"
RECOVERY_DIR="${WORKFLOW_DIR}/recovery"
LOGS_DIR="${WORKFLOW_DIR}/logs"

MAX_RETRIES=3

PHASE_NAMES=("spec" "wireframes" "api" "migrations" "backend" "frontend" "tests" "review" "pr")
PHASE_DISPLAY=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Review" "PR")

# Approval-Gate Phasen
APPROVAL_PHASES="0|1|6|7"

# Test-Phasen (Retry-Management)
TEST_PHASES="4|5|6"

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Stop Hook fired" >> "$LOGS_DIR/hooks.log"

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFUNG: Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")

# ═══════════════════════════════════════════════════════════════════════════
# STATUS-HANDLING
# ═══════════════════════════════════════════════════════════════════════════

# Nur bei "active" Status weitermachen
if [ "$STATUS" == "awaiting_approval" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║  ⏳ WARTE AUF APPROVAL                                                        ║"
  echo "╠══════════════════════════════════════════════════════════════════════════════╣"
  echo "║                                                                               ║"
  echo "║  Phase $PHASE (${PHASE_DISPLAY[$PHASE]}) wartet auf deine Bestätigung.       "
  echo "║                                                                               ║"
  echo "║  → 'Ja', 'OK', 'Weiter' oder 'Approve' zum Fortfahren                        ║"
  echo "║  → Oder gib Feedback für Änderungen                                          ║"
  echo "║                                                                               ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
fi

if [ "$STATUS" == "paused" ]; then
  PAUSE_REASON=$(jq -r '.pauseReason // "unbekannt"' "$WORKFLOW_FILE")
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║  ⏸️  WORKFLOW PAUSIERT                                                        ║"
  echo "╠══════════════════════════════════════════════════════════════════════════════╣"
  echo "║  Grund: $PAUSE_REASON"
  echo "║                                                                               ║"
  echo "║  → /byt8:wf-resume zum Fortsetzen                                            ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
fi

if [ "$STATUS" == "completed" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║  ✅ WORKFLOW ABGESCHLOSSEN                                                    ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
fi

if [ "$STATUS" != "active" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════

ensure_dirs() {
  mkdir -p "$CONTEXT_DIR" "$RECOVERY_DIR" "$LOGS_DIR" 2>/dev/null || true
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

  jq ".phase_${phase} = ${new}" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp" 2>/dev/null
  mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
}

reset_retry() {
  local phase=$1

  if [ -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    jq "del(.phase_${phase})" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp" 2>/dev/null
    mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
  fi
}

log_transition() {
  local from_phase=$1
  local to_phase=$2
  local reason=$3

  ensure_dirs
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"timestamp\":\"${timestamp}\",\"from\":${from_phase},\"to\":${to_phase},\"reason\":\"${reason}\"}" >> "${LOGS_DIR}/transitions.jsonl"
}

create_wip_commit() {
  local phase=$1
  local label=$2

  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    local commit_msg="wip(#${ISSUE_NUM}/phase-${phase}): ${label} - ${ISSUE_TITLE:0:50}"

    git add -A 2>/dev/null || true
    if git commit -m "$commit_msg" 2>/dev/null; then
      echo ""
      echo "┌─────────────────────────────────────────────────────────────────────┐"
      echo "│ 📦 WIP-COMMIT ERSTELLT                                              │"
      echo "├─────────────────────────────────────────────────────────────────────┤"
      echo "│ $commit_msg"
      echo "└─────────────────────────────────────────────────────────────────────┘"
      echo ""
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $commit_msg" >> "$LOGS_DIR/hooks.log"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-SPEZIFISCHE DONE-CHECKS
# ═══════════════════════════════════════════════════════════════════════════

check_done() {
  case $PHASE in
    0) # Tech Spec existiert?
       jq -e '.context.technicalSpec | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    1) # Wireframes existieren?
       ls wireframes/*.html > /dev/null 2>&1 || ls wireframes/*.svg > /dev/null 2>&1
       ;;
    2) # API Design existiert?
       jq -e '.context.apiDesign | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1
       ;;
    3) # Migrations existieren?
       ls backend/src/main/resources/db/migration/V*.sql > /dev/null 2>&1
       ;;
    4) # Backend Tests PASS?
       if [ -d "backend" ]; then
         (cd backend && mvn test -q 2>&1 | tail -5 | grep -q "BUILD SUCCESS")
         return $?
       else
         return 0
       fi
       ;;
    5) # Frontend Tests PASS?
       if [ -d "frontend" ]; then
         (cd frontend && npm test -- --no-watch --browsers=ChromeHeadless 2>&1 | grep -q "SUCCESS")
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
       jq -e '.context.reviewFeedback.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1
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
# HAUPTLOGIK
# ═══════════════════════════════════════════════════════════════════════════

ensure_dirs

if check_done; then
  # ═══════════════════════════════════════════════════════════════════════
  # ✅ PHASE ERFOLGREICH
  # ═══════════════════════════════════════════════════════════════════════

  reset_retry $PHASE

  NEXT_PHASE=$((PHASE + 1))

  # WIP-Commit für commitbare Phasen (1, 3, 4, 5, 6)
  if [[ "$PHASE" =~ ^(1|3|4|5|6)$ ]]; then
    create_wip_commit $PHASE "${PHASE_DISPLAY[$PHASE]} done"
  fi

  # Ist es eine Approval-Gate Phase?
  if [[ "$PHASE" =~ ^($APPROVAL_PHASES)$ ]]; then
    # Status auf "awaiting_approval" setzen
    jq --argjson np "$NEXT_PHASE" '
      .phases[(.currentPhase|tostring)].status = "completed" |
      .status = "awaiting_approval" |
      .awaitingApprovalFor = .currentPhase
    ' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ PHASE $PHASE (${PHASE_DISPLAY[$PHASE]}) ABGESCHLOSSEN!                   "
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                               ║"
    echo "║  ⏳ APPROVAL GATE                                                             ║"
    echo "║                                                                               ║"
    echo "║  Bist du zufrieden mit dem Ergebnis?                                         ║"
    echo "║                                                                               ║"
    echo "║  → 'Ja', 'OK', 'Approve' oder 'Weiter' zum Fortfahren                        ║"
    echo "║  → Oder gib Feedback für Änderungen                                          ║"
    echo "║                                                                               ║"
    echo "║  Nächste Phase: $NEXT_PHASE (${PHASE_DISPLAY[$NEXT_PHASE]})                  "
    echo "║                                                                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    log_transition $PHASE $PHASE "awaiting_approval"

  else
    # Automatisch zur nächsten Phase
    jq --argjson np "$NEXT_PHASE" '
      .phases[(.currentPhase|tostring)].status = "completed" |
      .currentPhase = $np |
      .status = "active"
    ' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  ✅ PHASE $PHASE (${PHASE_DISPLAY[$PHASE]}) ABGESCHLOSSEN!                   "
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                               ║"
    echo "║  ▶️  WEITER MIT PHASE $NEXT_PHASE (${PHASE_DISPLAY[$NEXT_PHASE]})             "
    echo "║                                                                               ║"
    echo "║  → Rufe /byt8:full-stack-feature auf um fortzufahren                         ║"
    echo "║                                                                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    log_transition $PHASE $NEXT_PHASE "auto_advance"
  fi

else
  # ═══════════════════════════════════════════════════════════════════════
  # ❌ PHASE NICHT FERTIG
  # ═══════════════════════════════════════════════════════════════════════

  # Test-Phasen: Retry-Management
  if [[ "$PHASE" =~ ^($TEST_PHASES)$ ]]; then
    RETRY_COUNT=$(get_retry_count $PHASE)
    increment_retry $PHASE
    NEW_RETRY=$((RETRY_COUNT + 1))

    if [ $NEW_RETRY -ge $MAX_RETRIES ]; then
      # Max Retries erreicht → Pausieren
      jq '.status = "paused" | .pauseReason = "max_retries"' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

      echo ""
      echo "╔══════════════════════════════════════════════════════════════════════════════╗"
      echo "║  🛑 MAX RETRIES ERREICHT ($MAX_RETRIES/$MAX_RETRIES)                         "
      echo "╠══════════════════════════════════════════════════════════════════════════════╣"
      echo "║                                                                               ║"
      echo "║  Phase $PHASE (${PHASE_DISPLAY[$PHASE]}) konnte nicht abgeschlossen werden. "
      echo "║                                                                               ║"
      echo "║  OPTIONEN:                                                                    ║"
      echo "║  → /byt8:wf-retry-reset  Retry-Counter zurücksetzen                          ║"
      echo "║  → /byt8:wf-skip         Phase überspringen (nicht empfohlen)                ║"
      echo "║  → Manuell fixen, dann /byt8:wf-resume                                       ║"
      echo "║                                                                               ║"
      echo "╚══════════════════════════════════════════════════════════════════════════════╝"
      echo ""

      log_transition $PHASE $PHASE "max_retries"
    else
      # Noch Retries übrig
      echo ""
      echo "╔══════════════════════════════════════════════════════════════════════════════╗"
      echo "║  ⚠️  PHASE $PHASE (${PHASE_DISPLAY[$PHASE]}) - TESTS FEHLGESCHLAGEN          "
      echo "║      Versuch $NEW_RETRY von $MAX_RETRIES                                     "
      echo "╠══════════════════════════════════════════════════════════════════════════════╣"
      echo "║                                                                               ║"

      case $PHASE in
        4)
          echo "║  Backend-Tests fehlgeschlagen.                                              ║"
          echo "║  → Fehler beheben und /byt8:full-stack-feature erneut aufrufen              ║"
          ;;
        5)
          echo "║  Frontend-Tests fehlgeschlagen.                                             ║"
          echo "║  → Fehler beheben und /byt8:full-stack-feature erneut aufrufen              ║"
          ;;
        6)
          echo "║  E2E-Tests fehlgeschlagen.                                                  ║"
          echo "║  → Fehler beheben und /byt8:full-stack-feature erneut aufrufen              ║"
          ;;
      esac

      echo "║                                                                               ║"
      echo "╚══════════════════════════════════════════════════════════════════════════════╝"
      echo ""

      log_transition $PHASE $PHASE "retry_$NEW_RETRY"
    fi

  else
    # Nicht-Test Phase: Einfach Info ausgeben
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  ℹ️  PHASE $PHASE (${PHASE_DISPLAY[$PHASE]}) - NOCH NICHT ABGESCHLOSSEN       "
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                               ║"
    echo "║  Done-Kriterium nicht erfüllt.                                               ║"
    echo "║                                                                               ║"

    case $PHASE in
      0)
        echo "║  Erwartet: context.technicalSpec im State                                   ║"
        ;;
      1)
        echo "║  Erwartet: wireframes/*.html oder wireframes/*.svg                          ║"
        ;;
      2)
        echo "║  Erwartet: context.apiDesign im State                                       ║"
        ;;
      3)
        echo "║  Erwartet: backend/src/main/resources/db/migration/V*.sql                   ║"
        ;;
      7)
        echo "║  Erwartet: context.reviewFeedback.status = 'APPROVED'                       ║"
        ;;
      8)
        echo "║  Erwartet: phases['8'].prUrl im State                                       ║"
        ;;
    esac

    echo "║                                                                               ║"
    echo "║  → /byt8:full-stack-feature erneut aufrufen wenn fertig                       ║"
    echo "║                                                                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
  fi
fi
