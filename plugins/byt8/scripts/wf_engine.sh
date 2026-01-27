#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Engine (Stop Hook) - Deterministische Steuerung
# ═══════════════════════════════════════════════════════════════════════════
# Dieser Hook steuert den GESAMTEN Workflow.
# Claude führt NUR die Anweisungen aus, die dieser Hook ausgibt.
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOGS_DIR="${WORKFLOW_DIR}/logs"
RECOVERY_DIR="${WORKFLOW_DIR}/recovery"

MAX_RETRIES=3

# Phase-Definitionen
declare -A PHASE_NAME=(
  [0]="Tech Spec"
  [1]="Wireframes"
  [2]="API Design"
  [3]="Migrations"
  [4]="Backend"
  [5]="Frontend"
  [6]="E2E Tests + Security"
  [7]="Code Review"
  [8]="Push & PR"
)

declare -A PHASE_AGENT=(
  [0]="byt8:architect-planner"
  [1]="byt8:ui-designer"
  [2]="byt8:api-architect"
  [3]="byt8:postgresql-architect"
  [4]="byt8:spring-boot-developer"
  [5]="byt8:angular-frontend-developer"
  [6]="byt8:test-engineer"
  [7]="byt8:code-reviewer"
  [8]="ORCHESTRATOR"
)

# Phasen mit Approval Gate (User muss bestätigen)
declare -A NEEDS_APPROVAL=(
  [0]=true
  [1]=true
  [6]=true
  [7]=true
  [8]=true
)

# Phasen mit WIP-Commit
declare -A NEEDS_COMMIT=(
  [1]=true
  [3]=true
  [4]=true
  [5]=true
  [6]=true
)

# Phasen mit Test-Gate
declare -A HAS_TEST_GATE=(
  [4]="mvn test"
  [5]="npm test -- --no-watch --browsers=ChromeHeadless"
  [6]="npx playwright test"
)

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

# State lesen
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")
FROM_BRANCH=$(jq -r '.fromBranch // "main"' "$WORKFLOW_FILE" 2>/dev/null || echo "main")

# ═══════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════

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
  mkdir -p "$RECOVERY_DIR" 2>/dev/null || true

  if [ ! -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    echo "{}" > "${RECOVERY_DIR}/retry-tracker.json"
  fi

  local current=$(get_retry_count $phase)
  local new=$((current + 1))

  jq ".phase_${phase} = ${new}" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp" 2>/dev/null
  mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
  echo $new
}

reset_retry() {
  local phase=$1
  if [ -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
    jq "del(.phase_${phase})" "${RECOVERY_DIR}/retry-tracker.json" > "${RECOVERY_DIR}/retry-tracker.json.tmp" 2>/dev/null
    mv "${RECOVERY_DIR}/retry-tracker.json.tmp" "${RECOVERY_DIR}/retry-tracker.json"
  fi
}

create_wip_commit() {
  local phase=$1

  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    local commit_msg="wip(#${ISSUE_NUM}/phase-${phase}): ${PHASE_NAME[$phase]} - ${ISSUE_TITLE:0:50}"

    git add -A 2>/dev/null || true
    if git commit -m "$commit_msg" 2>/dev/null; then
      echo "│ 📦 WIP-Commit: $commit_msg"
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $commit_msg" >> "$LOGS_DIR/hooks.log"
    fi
  fi
}

check_done() {
  case $PHASE in
    0) jq -e '.context.technicalSpec | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    1) ls wireframes/*.html > /dev/null 2>&1 || ls wireframes/*.svg > /dev/null 2>&1 ;;
    2) jq -e '.context.apiDesign | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    3) ls backend/src/main/resources/db/migration/V*.sql > /dev/null 2>&1 ;;
    4) jq -e '.context.backendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    5) jq -e '.context.frontendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    6) jq -e '.context.testResults | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    7) jq -e '.context.reviewFeedback.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    8) jq -e '.phases["8"].prUrl' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# AUSGABE: Anweisung für Claude
# ═══════════════════════════════════════════════════════════════════════════

print_instruction() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "WORKFLOW ENGINE - NÄCHSTE AKTION"
  echo "═══════════════════════════════════════════════════════════════════════════════"
}

print_footer() {
  echo "───────────────────────────────────────────────────────────────────────────────"
  echo "⛔ VERBOTEN: Andere Agents aufrufen, mehrere Phasen, eigene Entscheidungen"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# STATUS-HANDLING
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" == "paused" ]; then
  PAUSE_REASON=$(jq -r '.pauseReason // "unbekannt"' "$WORKFLOW_FILE")
  print_instruction
  echo "STATUS: paused"
  echo "GRUND: $PAUSE_REASON"
  echo ""
  echo "AKTION: Workflow ist pausiert. Warte auf User."
  echo ""
  echo "OPTIONEN FÜR USER:"
  echo "  → /byt8:wf-resume      Workflow fortsetzen"
  echo "  → /byt8:wf-retry-reset Retry-Counter zurücksetzen"
  print_footer
  exit 0
fi

if [ "$STATUS" == "idle" ] || [ "$STATUS" == "completed" ]; then
  print_instruction
  echo "STATUS: $STATUS"
  echo ""
  echo "AKTION: Workflow abgeschlossen. Kein weiterer Schritt nötig."
  print_footer
  exit 0
fi

if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# HAUPTLOGIK
# ═══════════════════════════════════════════════════════════════════════════

NEXT_PHASE=$((PHASE + 1))
CURRENT_AGENT="${PHASE_AGENT[$PHASE]}"
NEXT_AGENT="${PHASE_AGENT[$NEXT_PHASE]}"

# ───────────────────────────────────────────────────────────────────────────
# FALL 1: Warte auf Approval
# ───────────────────────────────────────────────────────────────────────────
if [ "$STATUS" == "awaiting_approval" ]; then
  print_instruction
  echo "STATUS: awaiting_approval"
  echo "PHASE: $PHASE (${PHASE_NAME[$PHASE]})"
  echo ""
  echo "WARTE AUF USER-INPUT:"
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────────────────┐"
  echo "│ WENN USER 'Ja/OK/Weiter/Approve':                                           │"
  echo "├─────────────────────────────────────────────────────────────────────────────┤"

  # WIP-Commit bei Approval?
  if [ "${NEEDS_COMMIT[$PHASE]}" == "true" ]; then
    echo "│ 1. WIP-Commit erstellen (git add -A && git commit)                          │"
  fi

  echo "│ 2. State updaten:                                                            │"
  echo "│    jq '.status = \"active\" | .currentPhase = $NEXT_PHASE' \\                   │"
  echo "│      .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json│"
  echo "│                                                                              │"

  if [ "$NEXT_PHASE" -le 8 ]; then
    echo "│ 3. Nächste Phase starten:                                                    │"
    if [ "$NEXT_AGENT" == "ORCHESTRATOR" ]; then
      echo "│    → Phase 8 (Push & PR) direkt ausführen (kein Agent)                      │"
    else
      echo "│    → Task($NEXT_AGENT)                                                       │"
      echo "│      \"Phase $NEXT_PHASE für Issue #$ISSUE_NUM: $ISSUE_TITLE\"                │"
    fi
  fi

  echo "└─────────────────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────────────────┐"
  echo "│ WENN USER FEEDBACK GIBT (Änderungswünsche):                                 │"
  echo "├─────────────────────────────────────────────────────────────────────────────┤"
  echo "│ 1. State updaten:                                                            │"
  echo "│    jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp ... │"
  echo "│                                                                              │"
  echo "│ 2. Gleiche Phase mit Feedback wiederholen:                                   │"
  echo "│    → Task($CURRENT_AGENT)                                                    │"
  echo "│      \"Revise Phase $PHASE based on feedback: {USER_FEEDBACK}\"               │"
  echo "└─────────────────────────────────────────────────────────────────────────────┘"
  print_footer
  exit 0
fi

# ───────────────────────────────────────────────────────────────────────────
# FALL 2: Phase prüfen (status = active)
# ───────────────────────────────────────────────────────────────────────────

if check_done; then
  # ═══════════════════════════════════════════════════════════════════════
  # ✅ PHASE ERFOLGREICH ABGESCHLOSSEN
  # ═══════════════════════════════════════════════════════════════════════

  reset_retry $PHASE

  print_instruction
  echo "STATUS: active"
  echo "PHASE: $PHASE (${PHASE_NAME[$PHASE]}) ✅ DONE"
  echo ""

  # WIP-Commit?
  if [ "${NEEDS_COMMIT[$PHASE]}" == "true" ]; then
    create_wip_commit $PHASE
    echo "│"
  fi

  # Approval Gate?
  if [ "${NEEDS_APPROVAL[$PHASE]}" == "true" ]; then
    # Status auf awaiting_approval setzen
    jq '.status = "awaiting_approval" | .awaitingApprovalFor = .currentPhase' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    echo "⏸️  APPROVAL GATE"
    echo ""
    echo "AKTION FÜR CLAUDE:"
    echo "  Frage den User: \"Phase $PHASE (${PHASE_NAME[$PHASE]}) ist fertig. Zufrieden?\""
    echo ""
    echo "DANN STOPP - Warte auf User-Antwort."
    echo "Der nächste Hook-Aufruf gibt die Anweisung basierend auf User-Input."

  else
    # Auto-Advance
    jq --argjson np "$NEXT_PHASE" \
      '.currentPhase = $np | .status = "active"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    echo "▶️  AUTO-ADVANCE zu Phase $NEXT_PHASE"
    echo ""
    echo "AKTION FÜR CLAUDE:"
    echo "  → Task($NEXT_AGENT)"
    echo "    \"Phase $NEXT_PHASE (${PHASE_NAME[$NEXT_PHASE]}) für Issue #$ISSUE_NUM\""
    echo ""
    echo "Kontext für Agent:"

    case $NEXT_PHASE in
      3)
        echo "  - context.technicalSpec (Architektur)"
        echo "  - context.apiDesign (Datenmodell)"
        ;;
      4)
        echo "  - context.technicalSpec"
        echo "  - context.apiDesign"
        echo "  - context.migrations (DB Schema)"
        ;;
      5)
        echo "  - context.wireframes (UI)"
        echo "  - context.apiDesign (Endpoints)"
        ;;
      *)
        echo "  - Alle vorherigen context.* Keys"
        ;;
    esac
  fi

  print_footer

else
  # ═══════════════════════════════════════════════════════════════════════
  # ❌ PHASE NICHT FERTIG
  # ═══════════════════════════════════════════════════════════════════════

  print_instruction
  echo "STATUS: active"
  echo "PHASE: $PHASE (${PHASE_NAME[$PHASE]}) ❌ NICHT FERTIG"
  echo ""

  # Phase 7 Spezial: CHANGES_REQUESTED
  if [ "$PHASE" == "7" ]; then
    REVIEW_STATUS=$(jq -r '.context.reviewFeedback.status // "PENDING"' "$WORKFLOW_FILE" 2>/dev/null)

    if [ "$REVIEW_STATUS" == "CHANGES_REQUESTED" ]; then
      RETRY=$(increment_retry $PHASE)

      if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        jq '.status = "paused" | .pauseReason = "max_review_iterations"' \
          "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

        echo "🛑 MAX REVIEW-ITERATIONEN ($MAX_RETRIES)"
        echo ""
        echo "AKTION: Workflow pausiert. User muss manuell eingreifen."
        echo "  → /byt8:wf-retry-reset zum Zurücksetzen"
      else
        echo "🔄 CODE REVIEW: CHANGES REQUESTED (Iteration $RETRY/$MAX_RETRIES)"
        echo ""
        echo "FIXES:"
        jq -r '.context.reviewFeedback.fixes[]? | "  → [\(.type)] \(.issue)"' "$WORKFLOW_FILE" 2>/dev/null
        echo ""
        echo "AKTION FÜR CLAUDE:"
        echo ""

        # Fixes nach Typ gruppieren
        HAS_BACKEND=$(jq -r '.context.reviewFeedback.fixes[]? | select(.type == "backend") | .issue' "$WORKFLOW_FILE" 2>/dev/null)
        HAS_FRONTEND=$(jq -r '.context.reviewFeedback.fixes[]? | select(.type == "frontend") | .issue' "$WORKFLOW_FILE" 2>/dev/null)
        HAS_DATABASE=$(jq -r '.context.reviewFeedback.fixes[]? | select(.type == "database") | .issue' "$WORKFLOW_FILE" 2>/dev/null)
        HAS_TESTS=$(jq -r '.context.reviewFeedback.fixes[]? | select(.type == "tests") | .issue' "$WORKFLOW_FILE" 2>/dev/null)

        STEP=1
        if [ -n "$HAS_DATABASE" ]; then
          echo "  $STEP. Task(byt8:postgresql-architect, \"Fix: $HAS_DATABASE\")"
          STEP=$((STEP + 1))
        fi
        if [ -n "$HAS_BACKEND" ]; then
          echo "  $STEP. Task(byt8:spring-boot-developer, \"Fix: $HAS_BACKEND\")"
          STEP=$((STEP + 1))
        fi
        if [ -n "$HAS_FRONTEND" ]; then
          echo "  $STEP. Task(byt8:angular-frontend-developer, \"Fix: $HAS_FRONTEND\")"
          STEP=$((STEP + 1))
        fi
        if [ -n "$HAS_TESTS" ]; then
          echo "  $STEP. Task(byt8:test-engineer, \"Fix: $HAS_TESTS\")"
          STEP=$((STEP + 1))
        fi

        echo ""
        echo "  $STEP. context.reviewFeedback zurücksetzen:"
        echo "     jq 'del(.context.reviewFeedback)' .workflow/workflow-state.json > tmp && mv tmp ..."
        echo ""
        echo "  $((STEP + 1)). Erneut Code Review:"
        echo "     Task(byt8:code-reviewer, \"Re-review after fixes\")"
      fi

      print_footer
      exit 0
    fi
  fi

  # Test-Phasen: Retry bei Fehler
  if [ -n "${HAS_TEST_GATE[$PHASE]}" ]; then
    RETRY=$(increment_retry $PHASE)

    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
      jq '.status = "paused" | .pauseReason = "max_test_retries"' \
        "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

      echo "🛑 MAX TEST-RETRIES ($MAX_RETRIES)"
      echo ""
      echo "AKTION: Workflow pausiert. User muss manuell eingreifen."
      echo "  → /byt8:wf-retry-reset zum Zurücksetzen"
    else
      echo "⚠️  TESTS FEHLGESCHLAGEN (Versuch $RETRY/$MAX_RETRIES)"
      echo ""
      echo "Test-Command: ${HAS_TEST_GATE[$PHASE]}"
      echo ""
      echo "AKTION FÜR CLAUDE:"
      echo "  1. Fehler analysieren"
      echo "  2. Task($CURRENT_AGENT, \"Fix test failures\")"
      echo "  3. Tests werden beim nächsten Hook-Aufruf erneut geprüft"
    fi

    print_footer
    exit 0
  fi

  # Standard: Done-Kriterium nicht erfüllt
  echo "Done-Kriterium nicht erfüllt."
  echo ""

  case $PHASE in
    0) echo "Erwartet: context.technicalSpec muss existieren" ;;
    1) echo "Erwartet: wireframes/*.html oder wireframes/*.svg" ;;
    2) echo "Erwartet: context.apiDesign muss existieren" ;;
    3) echo "Erwartet: backend/src/main/resources/db/migration/V*.sql" ;;
    4) echo "Erwartet: context.backendImpl muss existieren" ;;
    5) echo "Erwartet: context.frontendImpl muss existieren" ;;
    6) echo "Erwartet: context.testResults muss existieren" ;;
    7) echo "Erwartet: context.reviewFeedback.status == 'APPROVED'" ;;
    8) echo "Erwartet: phases['8'].prUrl muss existieren" ;;
  esac

  echo ""
  echo "AKTION FÜR CLAUDE:"
  echo "  → Task($CURRENT_AGENT, \"Complete Phase $PHASE for Issue #$ISSUE_NUM\")"

  print_footer
fi
