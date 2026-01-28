#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Workflow Engine (Stop Hook) - Deterministische Steuerung
# ═══════════════════════════════════════════════════════════════════════════
# Dieser Hook steuert den GESAMTEN Workflow.
# Claude führt NUR die Anweisungen aus, die dieser Hook ausgibt.
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

# Phase-Namen für aktuelle/nächste Phase
PHASE_NAME_CURRENT=$(get_phase_name $PHASE)
PHASE_AGENT_CURRENT=$(get_phase_agent $PHASE)
NEXT_PHASE=$((PHASE + 1))
PHASE_NAME_NEXT=$(get_phase_name $NEXT_PHASE)
PHASE_AGENT_NEXT=$(get_phase_agent $NEXT_PHASE)

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
  local phase_name=$(get_phase_name $phase)

  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    local commit_msg="wip(#${ISSUE_NUM}/phase-${phase}): ${phase_name} - ${ISSUE_TITLE:0:50}"

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
    7) jq -e '.context.securityAudit | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    8) jq -e '.context.reviewFeedback.status == "APPROVED"' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
    9) jq -e '.phases["9"].prUrl' "$WORKFLOW_FILE" > /dev/null 2>&1 ;;
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

# ───────────────────────────────────────────────────────────────────────────
# FALL 1: Warte auf Approval
# ───────────────────────────────────────────────────────────────────────────
if [ "$STATUS" == "awaiting_approval" ]; then
  print_instruction
  echo "STATUS: awaiting_approval"
  echo "PHASE: $PHASE ($PHASE_NAME_CURRENT)"
  echo ""
  echo "WARTE AUF USER-INPUT:"
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────────────────┐"
  echo "│ WENN USER 'Ja/OK/Weiter/Approve':                                           │"
  echo "├─────────────────────────────────────────────────────────────────────────────┤"

  # WIP-Commit bei Approval?
  if needs_commit $PHASE; then
    echo "│ 1. WIP-Commit erstellen (git add -A && git commit)                          │"
  fi

  echo "│ 2. State updaten:                                                            │"
  if [ "$PHASE" == "7" ]; then
    echo "│    jq '.status = \"active\" | .currentPhase = $NEXT_PHASE | del(.securityFixCount)' \\│"
  else
    echo "│    jq '.status = \"active\" | .currentPhase = $NEXT_PHASE' \\                   │"
  fi
  echo "│      .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json│"
  echo "│                                                                              │"

  if [ "$NEXT_PHASE" -le 9 ]; then
    echo "│ 3. Nächste Phase starten:                                                    │"
    if [ "$PHASE_AGENT_NEXT" == "ORCHESTRATOR" ]; then
      echo "│    → Phase 9 (Push & PR) direkt ausführen (kein Agent)                      │"
    else
      echo "│    → Task($PHASE_AGENT_NEXT)                                                 │"
      echo "│      \"Phase $NEXT_PHASE für Issue #$ISSUE_NUM: $ISSUE_TITLE\"                │"
    fi
  fi

  echo "└─────────────────────────────────────────────────────────────────────────────┘"
  echo ""

  if [ "$PHASE" == "7" ]; then
    # Phase 7 (Security Audit): Iteration limit + Intelligentes Routing für Fixes
    SEC_FIX_COUNT=$(jq -r '.securityFixCount // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")

    echo "┌─────────────────────────────────────────────────────────────────────────────┐"
    echo "│ WENN USER ÄNDERUNGEN ODER FIXES WILL:                                       │"
    echo "├─────────────────────────────────────────────────────────────────────────────┤"

    if [ "$SEC_FIX_COUNT" -ge "$MAX_RETRIES" ]; then
      echo "│ 🛑 MAX SECURITY-FIX-ITERATIONEN ($MAX_RETRIES) ERREICHT                     │"
      echo "│                                                                              │"
      echo "│ AKTION: Informiere User dass Security-Fix-Limit erreicht ist.               │"
      echo "│ Optionen:                                                                    │"
      echo "│   - 'Weiter' → Verbleibende Findings akzeptieren, Phase 8                   │"
      echo "│   - /byt8:wf-retry-reset → Counter zurücksetzen, nochmal fixen              │"
      echo "│   - /byt8:wf-pause → Pausieren für manuelles Eingreifen                     │"
    else
      echo "│ Security-Fix Iteration: $((SEC_FIX_COUNT + 1))/$MAX_RETRIES                 │"
      echo "│                                                                              │"
      echo "│ 1. State updaten:                                                            │"
      echo "│    jq '.status = \"active\" | del(.context.securityAudit) |                   │"
      echo "│    del(.context.testResults) |                                               │"
      echo "│    .securityFixCount = (.securityFixCount // 0) + 1 |                       │"
      echo "│    .currentPhase = 6' \\                                                     │"
      echo "│      .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json│"
      echo "│                                                                              │"
      echo "│ 2. Claude analysiert User-Input und routet an zuständigen Agent:             │"
      echo "│    - Security Findings fixen:                                                │"
      echo "│      User kann: 'fix alle', 'fix critical+high', 'fix HIGH-001, MED-003'   │"
      echo "│      → Findings nach User-Auswahl filtern                                   │"
      echo "│      → Backend (.java) → Task(byt8:spring-boot-developer, \"Fix: ...\")       │"
      echo "│      → Frontend (.ts/.html) → Task(byt8:angular-frontend-developer, \"...\") │"
      echo "│                                                                              │"
      echo "│ 3. Phase 6 (E2E Tests) starten:                                             │"
      echo "│    → Task(byt8:test-engineer, \"Re-run tests after security fixes\")          │"
      echo "│    ℹ️  Auto-Advance: Phase 6 → Phase 7 (Re-Audit)                            │"
    fi

    echo "└─────────────────────────────────────────────────────────────────────────────┘"
  else
    # Alle anderen Phasen: Generischer Feedback-Loop
    echo "┌─────────────────────────────────────────────────────────────────────────────┐"
    echo "│ WENN USER FEEDBACK GIBT (Änderungswünsche):                                 │"
    echo "├─────────────────────────────────────────────────────────────────────────────┤"
    echo "│ 1. State updaten:                                                            │"
    echo "│    jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp ... │"
    echo "│                                                                              │"
    echo "│ 2. Gleiche Phase mit Feedback wiederholen:                                   │"
    echo "│    → Task($PHASE_AGENT_CURRENT)                                              │"
    echo "│      \"Revise Phase $PHASE based on feedback: {USER_FEEDBACK}\"               │"
    echo "└─────────────────────────────────────────────────────────────────────────────┘"
  fi

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
  echo "PHASE: $PHASE ($PHASE_NAME_CURRENT) ✅ DONE"
  echo ""

  # WIP-Commit?
  if needs_commit $PHASE; then
    create_wip_commit $PHASE
    echo "│"
  fi

  # Approval Gate?
  if needs_approval $PHASE; then
    # Status auf awaiting_approval setzen
    jq '.status = "awaiting_approval" | .awaitingApprovalFor = .currentPhase' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    echo "⏸️  APPROVAL GATE"
    echo ""

    # Phase 7 Spezial: Security Findings anzeigen
    if [ "$PHASE" == "7" ]; then
      CRITICAL_COUNT=$(jq -r '.context.securityAudit.severity.critical // 0' "$WORKFLOW_FILE" 2>/dev/null)
      HIGH_COUNT=$(jq -r '.context.securityAudit.severity.high // 0' "$WORKFLOW_FILE" 2>/dev/null)
      MEDIUM_COUNT=$(jq -r '.context.securityAudit.severity.medium // 0' "$WORKFLOW_FILE" 2>/dev/null)
      LOW_COUNT=$(jq -r '.context.securityAudit.severity.low // 0' "$WORKFLOW_FILE" 2>/dev/null)
      TOTAL_FINDINGS=$(jq -r '.context.securityAudit.findings | length // 0' "$WORKFLOW_FILE" 2>/dev/null)

      if [ "$TOTAL_FINDINGS" -gt 0 ]; then
        echo "SECURITY AUDIT ERGEBNIS: $TOTAL_FINDINGS Findings"
        echo "  Critical: $CRITICAL_COUNT | High: $HIGH_COUNT | Medium: $MEDIUM_COUNT | Low: $LOW_COUNT"
        echo ""
        echo "FINDINGS:"
        jq -r '.context.securityAudit.findings[]? | "  [\(.severity | ascii_upcase)] \(.id): \(.description) (\(.location))"' "$WORKFLOW_FILE" 2>/dev/null
        echo ""
        echo "AKTION FÜR CLAUDE:"
        echo "  Zeige dem User ALLE Findings als Tabelle (Severity, ID, Description, Location)."
        echo "  Frage: \"Security Audit fertig. Welche Findings sollen gefixt werden?\""
        echo "  Optionen:"
        echo "    - 'Weiter' → Alle akzeptieren, weiter zu Phase 8 (Code Review)"
        echo "    - 'Fix alle' → Alle Findings fixen"
        echo "    - 'Fix critical+high' → Nur ab Severity High fixen"
        echo "    - 'Fix HIGH-001, MEDIUM-003' → Bestimmte Findings per ID fixen"
      else
        echo "AKTION FÜR CLAUDE:"
        echo "  Frage den User: \"Phase $PHASE ($PHASE_NAME_CURRENT) ist fertig. Keine Security-Findings. Zufrieden?\""
      fi
    else
      echo "AKTION FÜR CLAUDE:"
      echo "  Frage den User: \"Phase $PHASE ($PHASE_NAME_CURRENT) ist fertig. Zufrieden?\""
    fi

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
    echo "  → Task($PHASE_AGENT_NEXT)"
    echo "    \"Phase $NEXT_PHASE ($PHASE_NAME_NEXT) für Issue #$ISSUE_NUM\""
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
      7)
        echo "  - context.testResults (Test-Ergebnisse)"
        echo "  - context.backendImpl (Backend Code)"
        echo "  - context.frontendImpl (Frontend Code)"
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
  echo "PHASE: $PHASE ($PHASE_NAME_CURRENT) ❌ NICHT FERTIG"
  echo ""

  # Phase 8 Spezial: CHANGES_REQUESTED
  if [ "$PHASE" == "8" ]; then
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

        # Dynamisches Rollback-Ziel basierend auf frühestem Fix-Typ
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

        echo "ROLLBACK ZU PHASE $ROLLBACK_TARGET ($ROLLBACK_NAME)"
        echo ""
        echo "AKTION FÜR CLAUDE:"
        echo ""
        echo "  1. Review-Feedback merken (für Agent-Prompt)"
        echo ""
        echo "  2. Context zurücksetzen und Rollback:"
        echo "     jq '$CLEAR_CMD | .currentPhase = $ROLLBACK_TARGET | .status = \"active\"' \\"
        echo "       .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
        echo ""
        echo "  3. Phase $ROLLBACK_TARGET ($ROLLBACK_NAME) starten:"
        echo "     Task($ROLLBACK_AGENT, \"Phase $ROLLBACK_TARGET für Issue #$ISSUE_NUM."
        echo "       Review-Feedback: {FIXES_VON_OBEN}\")"
        echo ""
        echo "  ℹ️  Auto-Advance: Phase $ROLLBACK_TARGET → ... → Phase 8 (Re-Review)"
      fi

      print_footer
      exit 0
    fi
  fi

  # Test-Phasen: Retry bei Fehler
  TEST_CMD=$(get_test_command $PHASE)
  if [ -n "$TEST_CMD" ]; then
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
      echo "Test-Command: $TEST_CMD"
      echo ""
      echo "AKTION FÜR CLAUDE:"
      echo "  1. Fehler analysieren"
      echo "  2. Task($PHASE_AGENT_CURRENT, \"Fix test failures\")"
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
    7) echo "Erwartet: context.securityAudit muss existieren" ;;
    8) echo "Erwartet: context.reviewFeedback.status == 'APPROVED'" ;;
    9) echo "Erwartet: phases['9'].prUrl muss existieren" ;;
  esac

  echo ""
  echo "AKTION FÜR CLAUDE:"
  echo "  → Task($PHASE_AGENT_CURRENT, \"Complete Phase $PHASE for Issue #$ISSUE_NUM\")"

  print_footer
fi
