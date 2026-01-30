#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Engine (Stop Hook) - v7.0 Context-Injection
# ═══════════════════════════════════════════════════════════════════════════
# Kontrolliert den Workflow via JSON decision:block Mechanismus.
# Claude SIEHT die "reason" und MUSS weitermachen wenn decision=block.
#
# Output-Kanäle:
#   stdout JSON {"decision":"block","reason":"..."} → Claude sieht "reason"
#   stdout (kein JSON, exit 0)                      → nur User (verbose mode)
#   Log-Datei (.workflow/logs/hooks.log)             → Debugging
#   State (jq auf workflow-state.json)               → Direkte Modifikation
#
# WICHTIG: Nur JSON auf stdout wenn Claude weitermachen soll!
# Alles andere → Log-Datei oder gar nichts.
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
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
MAX_STOP_HOOK_BLOCKS=15

# ═══════════════════════════════════════════════════════════════════════════
# STDIN LESEN (stop_hook_active prüfen für Loop-Prevention)
# ═══════════════════════════════════════════════════════════════════════════
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-DEFINITIONEN (Bash 3.x kompatibel via case statements)
# ═══════════════════════════════════════════════════════════════════════════

get_phase_name() {
  case $1 in
    0) echo "Tech Spec" ;;
    1) echo "Wireframes" ;;
    2) echo "API Design" ;;
    3) echo "Migrations" ;;
    4) echo "Backend" ;;
    5) echo "Frontend" ;;
    6) echo "E2E Tests" ;;
    7) echo "Security Audit" ;;
    8) echo "Code Review" ;;
    9) echo "Push & PR" ;;
    *) echo "Unknown" ;;
  esac
}

get_phase_agent() {
  case $1 in
    0) echo "byt8:architect-planner" ;;
    1) echo "byt8:ui-designer" ;;
    2) echo "byt8:api-architect" ;;
    3) echo "byt8:postgresql-architect" ;;
    4) echo "byt8:spring-boot-developer" ;;
    5) echo "byt8:angular-frontend-developer" ;;
    6) echo "byt8:test-engineer" ;;
    7) echo "byt8:security-auditor" ;;
    8) echo "byt8:code-reviewer" ;;
    9) echo "ORCHESTRATOR" ;;
    *) echo "" ;;
  esac
}

# Phasen mit Approval Gate (User muss bestätigen)
needs_approval() {
  case $1 in
    0|1|7|8|9) return 0 ;;  # true
    *) return 1 ;;          # false
  esac
}

# Phasen mit WIP-Commit
needs_commit() {
  case $1 in
    1|3|4|5|6) return 0 ;;  # true
    *) return 1 ;;            # false
  esac
}

# Phasen mit Test-Gate
get_test_command() {
  case $1 in
    4) echo "mvn test" ;;
    5) echo "npm test -- --no-watch --browsers=ChromeHeadless" ;;
    6) echo "npx playwright test" ;;
    *) echo "" ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING (nur in Datei, NICHT auf stdout)
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOGS_DIR/hooks.log" 2>/dev/null || true
}

log_transition() {
  local event="$1"
  local detail="$2"
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"event\":\"$event\",\"detail\":\"$detail\"}" >> "$LOGS_DIR/transitions.jsonl" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════
# JSON OUTPUT: Claude sieht "reason" und MUSS weitermachen
# ═══════════════════════════════════════════════════════════════════════════
output_block() {
  local reason="$1"

  # Block-Counter inkrementieren
  local count
  count=$(jq -r '.stopHookBlockCount // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
  count=$((count + 1))
  jq --argjson c "$count" '.stopHookBlockCount = $c' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  log "BLOCK ($count/$MAX_STOP_HOOK_BLOCKS): ${reason:0:120}"
  log_transition "stop_hook_block" "count=$count"

  # JSON auf stdout → Claude Code parsed dies und zeigt "reason" an Claude
  jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
  exit 0
}

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
  local phase_name
  phase_name=$(get_phase_name $phase)

  # Alles stagen, dann prüfen
  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    local commit_msg="wip(#${ISSUE_NUM}/phase-${phase}): ${phase_name} - ${ISSUE_TITLE:0:50}"

    if git commit -m "$commit_msg" 2>/dev/null; then
      log "WIP-Commit: $commit_msg"
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
    7) jq -e '.context.securityAudit | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    8) jq -e '.context.reviewFeedback.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    9) jq -e '.phases["9"].prUrl' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

# Phase-Skip Guard: Prüft ob ALLE Vorgänger-Phasen ihren Context geschrieben haben.
detect_skipped_phase() {
  local current=$1
  local i=0

  while [ $i -lt $current ]; do
    case $i in
      0) jq -e '.context.technicalSpec | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      1) jq -e '.context.wireframes | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      2) jq -e '.context.apiDesign | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      3) jq -e '.context.migrations | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      4) jq -e '.context.backendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      5) jq -e '.context.frontendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      6) jq -e '.context.testResults | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      7) jq -e '.context.securityAudit | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
      8) jq -e '.context.reviewFeedback.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1 || { echo $i; return; } ;;
    esac
    i=$((i + 1))
  done
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFUNG: Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  log "Stop Hook fired (kein Workflow)"
  exit 0
fi

# State lesen
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")
FROM_BRANCH=$(jq -r '.fromBranch // "main"' "$WORKFLOW_FILE" 2>/dev/null || echo "main")

PHASE_NAME=$(get_phase_name $PHASE)
PHASE_AGENT=$(get_phase_agent $PHASE)
NEXT_PHASE=$((PHASE + 1))
NEXT_NAME=$(get_phase_name $NEXT_PHASE)
NEXT_AGENT=$(get_phase_agent $NEXT_PHASE)

log "Stop Hook fired: Phase $PHASE ($PHASE_NAME) | Status: $STATUS | stop_hook_active: $STOP_HOOK_ACTIVE"

# ═══════════════════════════════════════════════════════════════════════════
# LOOP-PREVENTION: Zu viele consecutive blocks → Workflow pausieren
# ═══════════════════════════════════════════════════════════════════════════
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  BLOCK_COUNT=$(jq -r '.stopHookBlockCount // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
  if [ "$BLOCK_COUNT" -ge "$MAX_STOP_HOOK_BLOCKS" ]; then
    jq '.status = "paused" | .pauseReason = "stop_hook_loop_detected"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    log "LOOP DETECTED: $BLOCK_COUNT consecutive blocks. Pausing workflow."
    log_transition "loop_detected" "blockCount=$BLOCK_COUNT"
    exit 0  # Claude darf stoppen
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# STATUS-HANDLING: Nicht-aktive Zustände → Claude darf stoppen
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" = "completed" ]; then
  # Dauer berechnen und speichern
  STARTED_AT=$(jq -r '.startedAt // ""' "$WORKFLOW_FILE" 2>/dev/null)
  COMPLETED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [ -n "$STARTED_AT" ] && [ "$STARTED_AT" != "null" ]; then
    START_EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED_AT" +%s 2>/dev/null || echo "")
    END_EPOCH=$(date -u +%s)

    if [ -n "$START_EPOCH" ]; then
      DURATION_SEC=$((END_EPOCH - START_EPOCH))
      DURATION_MIN=$((DURATION_SEC / 60))
      DURATION_REM_SEC=$((DURATION_SEC % 60))

      jq --arg ca "$COMPLETED_AT" --arg dur "${DURATION_MIN}m ${DURATION_REM_SEC}s" \
        '.completedAt = $ca | .duration = $dur' \
        "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

      log "Workflow completed: #${ISSUE_NUM} - ${ISSUE_TITLE} (Duration: ${DURATION_MIN}m ${DURATION_REM_SEC}s)"
    fi
  fi
  exit 0
fi

if [ "$STATUS" = "paused" ] || [ "$STATUS" = "idle" ]; then
  log "Stop allowed: Status=$STATUS"
  exit 0
fi

# Nur active und awaiting_approval weiter verarbeiten
if [ "$STATUS" != "active" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# AWAITING_APPROVAL → Claude darf stoppen
# UserPromptSubmit Hook injiziert Kontext beim nächsten User-Prompt
# ═══════════════════════════════════════════════════════════════════════════
if [ "$STATUS" = "awaiting_approval" ]; then
  log "Stop allowed: awaiting_approval (Phase $PHASE)"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# AB HIER: status = active → Workflow läuft
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-SKIP GUARD: Fehlende Vorgänger-Phasen abfangen
# ═══════════════════════════════════════════════════════════════════════════
SKIPPED_TO=$(detect_skipped_phase $PHASE)
if [ -n "$SKIPPED_TO" ]; then
  SKIP_NAME=$(get_phase_name $SKIPPED_TO)
  SKIP_AGENT=$(get_phase_agent $SKIPPED_TO)

  log "PHASE SKIP DETECTED: Phase $PHASE erfordert Phase $SKIPPED_TO ($SKIP_NAME). Auto-Korrektur."
  log_transition "phase_skip_corrected" "from=$PHASE to=$SKIPPED_TO"

  # State auto-korrigieren
  jq --argjson sp "$SKIPPED_TO" '.currentPhase = $sp | .status = "active"' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  output_block "PHASE-SKIP ERKANNT UND KORRIGIERT: Phase $SKIPPED_TO ($SKIP_NAME) wurde uebersprungen. State auf Phase $SKIPPED_TO zurueckgesetzt. Starte sofort: Task($SKIP_AGENT, 'Phase $SKIPPED_TO ($SKIP_NAME) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE'). Lies .workflow/workflow-state.json fuer Spec-File-Pfade."
fi

# ═══════════════════════════════════════════════════════════════════════════
# DONE-CHECK: Phase abgeschlossen?
# ═══════════════════════════════════════════════════════════════════════════
if check_done; then
  # ═════════════════════════════════════════════════════════════════════════
  # ✅ PHASE ERFOLGREICH ABGESCHLOSSEN
  # ═════════════════════════════════════════════════════════════════════════

  reset_retry $PHASE

  # WIP-Commit (silent, kein stdout)
  if needs_commit $PHASE; then
    create_wip_commit $PHASE
  fi

  if needs_approval $PHASE; then
    # ═══════════════════════════════════════════════════════════════════════
    # APPROVAL GATE → Claude darf stoppen, User antwortet
    # UserPromptSubmit Hook injiziert dann den Kontext
    # ═══════════════════════════════════════════════════════════════════════
    jq '.status = "awaiting_approval" | .awaitingApprovalFor = .currentPhase' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "APPROVAL GATE: Phase $PHASE ($PHASE_NAME) done. awaiting_approval gesetzt."
    log_transition "approval_gate" "phase=$PHASE"

    # Kein JSON → exit 0 → Claude stoppt normal
    # SKILL.md im Context sagt Claude: User fragen
    exit 0

  else
    # ═══════════════════════════════════════════════════════════════════════
    # AUTO-ADVANCE → Claude MUSS weitermachen (decision:block)
    # ═══════════════════════════════════════════════════════════════════════
    jq --argjson np "$NEXT_PHASE" \
      '.currentPhase = $np | .status = "active"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "AUTO-ADVANCE: Phase $PHASE ($PHASE_NAME) → Phase $NEXT_PHASE ($NEXT_NAME)"
    log_transition "auto_advance" "from=$PHASE to=$NEXT_PHASE"

    output_block "Phase $PHASE ($PHASE_NAME) DONE. Auto-Advance zu Phase $NEXT_PHASE ($NEXT_NAME). Starte sofort: Task($NEXT_AGENT, 'Phase $NEXT_PHASE ($NEXT_NAME) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE'). Lies .workflow/workflow-state.json fuer Spec-File-Pfade (File Reference Protocol)."
  fi

else
  # ═════════════════════════════════════════════════════════════════════════
  # ❌ PHASE NICHT FERTIG
  # ═════════════════════════════════════════════════════════════════════════

  # ─────────────────────────────────────────────────────────────────────────
  # Phase 8 Spezial: CHANGES_REQUESTED → Deterministic Rollback
  # ─────────────────────────────────────────────────────────────────────────
  if [ "$PHASE" = "8" ]; then
    REVIEW_STATUS=$(jq -r '.context.reviewFeedback.status // "PENDING"' "$WORKFLOW_FILE" 2>/dev/null)

    if [ "$REVIEW_STATUS" = "CHANGES_REQUESTED" ]; then
      RETRY=$(increment_retry $PHASE)

      if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        jq '.status = "paused" | .pauseReason = "max_review_iterations"' \
          "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
        log "MAX REVIEW ITERATIONS ($MAX_RETRIES). Pausing."
        log_transition "max_review_retries" "retry=$RETRY"
        exit 0  # Claude darf stoppen, User muss eingreifen
      fi

      # Fixes-Text ZUERST lesen (vor State-Bereinigung!)
      FIXES_TEXT=$(jq -r '[.context.reviewFeedback.fixes[]? | "[\(.type)] \(.issue)"] | join("; ")' "$WORKFLOW_FILE" 2>/dev/null || echo "Review changes requested")

      # Rollback-Ziel deterministisch bestimmen
      ROLLBACK_TARGET=6
      if jq -e '.context.reviewFeedback.fixes[]? | select(.type == "database")' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        ROLLBACK_TARGET=3
      elif jq -e '.context.reviewFeedback.fixes[]? | select(.type == "backend")' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        ROLLBACK_TARGET=4
      elif jq -e '.context.reviewFeedback.fixes[]? | select(.type == "frontend")' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        ROLLBACK_TARGET=5
      fi

      ROLLBACK_NAME=$(get_phase_name $ROLLBACK_TARGET)
      ROLLBACK_AGENT=$(get_phase_agent $ROLLBACK_TARGET)

      # Context ab Rollback-Ziel aufräumen
      CLEAR_CMD="del(.context.reviewFeedback) | del(.securityFixCount)"
      if [ "$ROLLBACK_TARGET" -le 3 ]; then
        CLEAR_CMD="$CLEAR_CMD | del(.context.migrations)"
      fi
      if [ "$ROLLBACK_TARGET" -le 4 ]; then
        CLEAR_CMD="$CLEAR_CMD | del(.context.backendImpl)"
      fi
      if [ "$ROLLBACK_TARGET" -le 5 ]; then
        CLEAR_CMD="$CLEAR_CMD | del(.context.frontendImpl)"
      fi
      CLEAR_CMD="$CLEAR_CMD | del(.context.testResults) | del(.context.securityAudit)"

      # State korrigieren
      jq "$CLEAR_CMD | .currentPhase = $ROLLBACK_TARGET | .status = \"active\"" \
        "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

      log "REVIEW ROLLBACK: Phase 8 → Phase $ROLLBACK_TARGET ($ROLLBACK_NAME). Retry $RETRY/$MAX_RETRIES. Fixes: $FIXES_TEXT"
      log_transition "review_rollback" "target=$ROLLBACK_TARGET retry=$RETRY"

      output_block "Phase 8 Code Review: CHANGES_REQUESTED (Iteration $RETRY/$MAX_RETRIES). Rollback zu Phase $ROLLBACK_TARGET ($ROLLBACK_NAME). State bereits korrigiert (currentPhase=$ROLLBACK_TARGET, downstream Context geloescht). Starte sofort: Task($ROLLBACK_AGENT, 'Phase $ROLLBACK_TARGET ($ROLLBACK_NAME) Hotfix fuer Issue #$ISSUE_NUM. Review-Fixes: $FIXES_TEXT'). Auto-Advance laeuft bis Phase 8 (Re-Review)."
    fi
  fi

  # ─────────────────────────────────────────────────────────────────────────
  # Test-Phasen: Retry bei Fehler
  # ─────────────────────────────────────────────────────────────────────────
  TEST_CMD=$(get_test_command $PHASE)
  if [ -n "$TEST_CMD" ]; then
    RETRY=$(increment_retry $PHASE)

    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
      jq '.status = "paused" | .pauseReason = "max_test_retries"' \
        "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
      log "MAX TEST RETRIES ($MAX_RETRIES). Phase $PHASE. Pausing."
      log_transition "max_test_retries" "phase=$PHASE retry=$RETRY"
      exit 0  # Claude darf stoppen
    fi

    log "TEST RETRY: Phase $PHASE ($PHASE_NAME), Versuch $RETRY/$MAX_RETRIES"
    log_transition "test_retry" "phase=$PHASE retry=$RETRY"

    output_block "Phase $PHASE ($PHASE_NAME) Tests fehlgeschlagen (Versuch $RETRY/$MAX_RETRIES). Starte: Task($PHASE_AGENT, 'Fix test failures in Phase $PHASE ($PHASE_NAME) fuer Issue #$ISSUE_NUM'). Tests: $TEST_CMD"
  fi

  # ─────────────────────────────────────────────────────────────────────────
  # Standard: Done-Kriterium nicht erfüllt
  # ─────────────────────────────────────────────────────────────────────────
  EXPECTED=""
  case $PHASE in
    0) EXPECTED="context.technicalSpec" ;;
    1) EXPECTED="wireframes/*.html oder wireframes/*.svg" ;;
    2) EXPECTED="context.apiDesign" ;;
    3) EXPECTED="V*.sql in backend/src/main/resources/db/migration/" ;;
    4) EXPECTED="context.backendImpl" ;;
    5) EXPECTED="context.frontendImpl" ;;
    6) EXPECTED="context.testResults" ;;
    7) EXPECTED="context.securityAudit" ;;
    8) EXPECTED="context.reviewFeedback.status = APPROVED" ;;
    9) EXPECTED="phases.9.prUrl" ;;
  esac

  log "PHASE NOT DONE: Phase $PHASE ($PHASE_NAME). Expected: $EXPECTED"
  log_transition "phase_not_done" "phase=$PHASE expected=$EXPECTED"

  output_block "Phase $PHASE ($PHASE_NAME) NICHT FERTIG. Erwartet: $EXPECTED. Starte: Task($PHASE_AGENT, 'Complete Phase $PHASE ($PHASE_NAME) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE'). Lies .workflow/workflow-state.json fuer Spec-File-Pfade."
fi
