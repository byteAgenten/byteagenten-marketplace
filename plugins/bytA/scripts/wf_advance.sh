#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Workflow Advance — Deterministic State Manipulation
# ═══════════════════════════════════════════════════════════════════════════
# Wird von Claude aufgerufen (1 Bash-Befehl) statt manuellem jq.
# Alle State-Aenderungen passieren hier — deterministisch, nicht im LLM.
#
# Subcommands:
#   approve              — Advance nach User-Approval
#   feedback 'MESSAGE'   — Gleiche Phase nochmal mit Feedback
#   rollback TARGET 'MSG'— Rollback zu frueherer Phase
#   complete             — Workflow als completed markieren
#
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

# Source phase configuration
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# ═══════════════════════════════════════════════════════════════════════════
# GUARDS
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "ERROR: $WORKFLOW_FILE not found." >&2
  exit 1
fi

WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  echo "ERROR: Not a bytA workflow (found: $WORKFLOW_TYPE)." >&2
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOGS_DIR/hooks.log" 2>/dev/null || true
}

log_transition() {
  local event="$1"
  local detail="$2"
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ\""),\"event\":\"$event\",\"detail\":\"$detail\"}" >> "$LOGS_DIR/transitions.jsonl" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════
# SOUND NOTIFICATIONS (gleiche Logik wie wf_orchestrator.sh)
# ═══════════════════════════════════════════════════════════════════════════
CUSTOM_SOUND_DIR="${CLAUDE_PLUGIN_ROOT:-}/assets/sounds"

play_sound() {
  local sound_file="$1"
  local fallback_mac="$2"
  local fallback_linux="$3"
  case "$(uname -s)" in
    Darwin)
      if [ -f "$CUSTOM_SOUND_DIR/$sound_file" ]; then
        afplay "$CUSTOM_SOUND_DIR/$sound_file" 2>/dev/null &
      else
        afplay "$fallback_mac" 2>/dev/null &
      fi
      ;;
    Linux)
      if [ -f "$CUSTOM_SOUND_DIR/$sound_file" ]; then
        paplay "$CUSTOM_SOUND_DIR/$sound_file" 2>/dev/null &
      elif command -v paplay >/dev/null 2>&1; then
        paplay "$fallback_linux" 2>/dev/null &
      fi
      ;;
  esac
}

play_completion() {
  play_sound "completion.wav" "/System/Library/Sounds/Funk.aiff" "/usr/share/sounds/freedesktop/stereo/complete.oga"
}

# ═══════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════

# Context ab einer Phase aufraeumen (gleiche Logik wie wf_orchestrator.sh Rollback)
cleanup_context() {
  local from_phase=$1
  local clear_cmd="del(.context.reviewFeedback) | del(.context.securityAudit) | del(.context.testResults)"
  [ "$from_phase" -le 5 ] && clear_cmd="$clear_cmd | del(.context.frontendImpl)"
  [ "$from_phase" -le 4 ] && clear_cmd="$clear_cmd | del(.context.backendImpl)"
  [ "$from_phase" -le 3 ] && clear_cmd="$clear_cmd | del(.context.migrations)"
  [ "$from_phase" -le 2 ] && clear_cmd="$clear_cmd | del(.context.apiDesign)"
  [ "$from_phase" -le 1 ] && clear_cmd="$clear_cmd | del(.context.wireframes)"
  [ "$from_phase" -le 0 ] && clear_cmd="$clear_cmd | del(.context.technicalSpec)"
  echo "$clear_cmd"
}

# Spec-Dateien ab einer Phase loeschen (verhindert stale GLOB-Matches)
cleanup_specs() {
  local from_phase=$1
  local p=$from_phase
  while [ "$p" -le 8 ]; do
    local pf
    pf=$(printf "%02d" "$p")
    rm -f .workflow/specs/issue-*-ph${pf}-*.md 2>/dev/null || true
    p=$((p + 1))
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
APPROVAL_PHASE=$(jq -r '.awaitingApprovalFor // .currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")
BRANCH=$(jq -r '.branch // "feature-branch"' "$WORKFLOW_FILE" 2>/dev/null || echo "feature-branch")
FROM_BRANCH=$(jq -r '.fromBranch // "main"' "$WORKFLOW_FILE" 2>/dev/null || echo "main")

# ═══════════════════════════════════════════════════════════════════════════
# SUBCOMMAND DISPATCH
# ═══════════════════════════════════════════════════════════════════════════
ACTION="${1:-}"

case "$ACTION" in

# ═══════════════════════════════════════════════════════════════════════════
# APPROVE — Advance nach User-Approval
# ═══════════════════════════════════════════════════════════════════════════
approve)
  if [ "$STATUS" != "awaiting_approval" ]; then
    echo "ERROR: Status ist '$STATUS', nicht 'awaiting_approval'." >&2
    exit 1
  fi

  PHASE_NAME=$(get_phase_name "$APPROVAL_PHASE")

  # ─── Phase 9 Spezial: Push & PR ───────────────────────────────────────
  if [ "$APPROVAL_PHASE" = "9" ]; then
    jq '.pushApproved = true' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "ADVANCE: Phase 9 (Push & PR) approved. pushApproved=true"
    log_transition "user_advance" "action=approve phase=9"

    echo "=== bytA ADVANCE: approve (Phase 9) ==="
    echo "Push approved."
    echo ""
    echo "PRE-PUSH BUILD GATE (PFLICHT!):"
    echo "1. cd backend && mvn verify"
    echo "2. cd frontend && npm test -- --no-watch --browsers=ChromeHeadless"
    echo "3. cd frontend && npm run build"
    echo ""
    echo "Bei GRUENEN TESTS:"
    echo "4. git push -u origin $BRANCH"
    echo "5. gh pr create --base $FROM_BRANCH --title 'feat(#$ISSUE_NUM): $ISSUE_TITLE'"
    echo ""
    echo "Nach erfolgreichem Push+PR:"
    echo "EXECUTE: Bash('${SCRIPT_DIR}/wf_advance.sh complete')"
    exit 0
  fi

  # ─── Phase 8 Spezial: userApproved setzen ─────────────────────────────
  if [ "$APPROVAL_PHASE" = "8" ]; then
    jq '.context.reviewFeedback.userApproved = true' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
  fi

  # ─── Naechste aktive Phase berechnen ──────────────────────────────────
  NEXT_PHASE=$(get_next_active_phase "$APPROVAL_PHASE" "$WORKFLOW_FILE")
  NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
  NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")

  # ─── State advance (DETERMINISTISCH) ──────────────────────────────────
  jq --argjson np "$NEXT_PHASE" '.currentPhase = $np | .status = "active"' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  log "ADVANCE: Phase $APPROVAL_PHASE ($PHASE_NAME) approved → Phase $NEXT_PHASE ($NEXT_NAME)"
  log_transition "user_advance" "action=approve from=$APPROVAL_PHASE to=$NEXT_PHASE"

  # ─── Prompt bauen ─────────────────────────────────────────────────────
  PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$NEXT_PHASE")

  echo "=== bytA ADVANCE: approve ==="
  echo "Phase $APPROVAL_PHASE ($PHASE_NAME) approved."
  echo "Next: Phase $NEXT_PHASE ($NEXT_NAME) — Agent: $NEXT_AGENT"
  echo ""
  echo "EXECUTE: Task(bytA:$NEXT_AGENT, '$PROMPT')"
  ;;

# ═══════════════════════════════════════════════════════════════════════════
# FEEDBACK — Gleiche Phase nochmal mit User-Feedback
# ═══════════════════════════════════════════════════════════════════════════
feedback)
  FEEDBACK="${2:-}"
  if [ -z "$FEEDBACK" ]; then
    echo "ERROR: Feedback-Text fehlt. Usage: wf_advance.sh feedback 'MESSAGE'" >&2
    exit 1
  fi

  if [ "$STATUS" != "awaiting_approval" ]; then
    echo "ERROR: Status ist '$STATUS', nicht 'awaiting_approval'." >&2
    exit 1
  fi

  PHASE_NAME=$(get_phase_name "$APPROVAL_PHASE")
  PHASE_AGENT=$(get_phase_agent "$APPROVAL_PHASE")

  # ─── State: gleiche Phase, status=active ──────────────────────────────
  jq '.status = "active"' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  log "ADVANCE: Phase $APPROVAL_PHASE ($PHASE_NAME) feedback. Re-running with: ${FEEDBACK:0:100}"
  log_transition "user_advance" "action=feedback phase=$APPROVAL_PHASE"

  # ─── Spec-Datei der aktuellen Phase loeschen (Agent muss neue schreiben) ─
  local_pf=$(printf "%02d" "$APPROVAL_PHASE")
  rm -f .workflow/specs/issue-*-ph${local_pf}-*.md 2>/dev/null || true

  # ─── Prompt bauen mit Feedback ────────────────────────────────────────
  PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$APPROVAL_PHASE" "$FEEDBACK")

  echo "=== bytA ADVANCE: feedback ==="
  echo "Phase $APPROVAL_PHASE ($PHASE_NAME) — Re-run with feedback."
  echo ""
  echo "EXECUTE: Task(bytA:$PHASE_AGENT, '$PROMPT')"
  ;;

# ═══════════════════════════════════════════════════════════════════════════
# ROLLBACK — Zu frueherer Phase zurueckrollen
# ═══════════════════════════════════════════════════════════════════════════
rollback)
  TARGET="${2:-}"
  FEEDBACK="${3:-}"

  if [ -z "$TARGET" ]; then
    echo "ERROR: Rollback-Ziel fehlt. Usage: wf_advance.sh rollback TARGET 'MESSAGE'" >&2
    echo ""
    echo "Verfuegbare Ziele:"
    echo "  0 = Tech Spec (architect-planner)"
    echo "  1 = Wireframes (ui-designer)"
    echo "  2 = API Design (api-architect)"
    echo "  3 = Database (postgresql-architect)"
    echo "  4 = Backend (spring-boot-developer)"
    echo "  5 = Frontend (angular-frontend-developer)"
    echo "  6 = Tests (test-engineer)"
    echo "  7 = Security Audit (security-auditor)"
    exit 1
  fi

  # Validate target
  if [ "$TARGET" -lt 0 ] 2>/dev/null || [ "$TARGET" -gt 7 ] 2>/dev/null; then
    echo "ERROR: Ungueltige Ziel-Phase: $TARGET (erlaubt: 0-7)" >&2
    exit 1
  fi

  TARGET_NAME=$(get_phase_name "$TARGET")
  TARGET_AGENT=$(get_phase_agent "$TARGET")
  FROM_PHASE_NAME=$(get_phase_name "$APPROVAL_PHASE")

  # ─── Context aufraeumen ───────────────────────────────────────────────
  CLEAR_CMD=$(cleanup_context "$TARGET")

  jq "$CLEAR_CMD | .currentPhase = $TARGET | .status = \"active\"" \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  # ─── Spec-Dateien ab Rollback-Ziel loeschen ───────────────────────────
  cleanup_specs "$TARGET"

  log "ADVANCE: Rollback from Phase $APPROVAL_PHASE ($FROM_PHASE_NAME) → Phase $TARGET ($TARGET_NAME). Feedback: ${FEEDBACK:0:100}"
  log_transition "user_advance" "action=rollback from=$APPROVAL_PHASE to=$TARGET"

  # ─── Prompt bauen ─────────────────────────────────────────────────────
  if [ -n "$FEEDBACK" ]; then
    PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$TARGET" "$FEEDBACK")
  else
    PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$TARGET")
  fi

  echo "=== bytA ADVANCE: rollback ==="
  echo "Rollback: Phase $APPROVAL_PHASE ($FROM_PHASE_NAME) → Phase $TARGET ($TARGET_NAME)"
  echo "Context & Specs ab Phase $TARGET geloescht."
  echo ""
  echo "EXECUTE: Task(bytA:$TARGET_AGENT, '$PROMPT')"
  ;;

# ═══════════════════════════════════════════════════════════════════════════
# COMPLETE — Workflow abschliessen
# ═══════════════════════════════════════════════════════════════════════════
complete)
  jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '.status = "completed" | .completedAt = $ts' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  log "ADVANCE: Workflow completed"
  log_transition "user_advance" "action=complete"

  play_completion

  echo "=== bytA ADVANCE: complete ==="
  echo "Workflow fuer Issue #$ISSUE_NUM abgeschlossen."
  echo "Status: completed | CompletedAt: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  ;;

# ═══════════════════════════════════════════════════════════════════════════
# UNKNOWN
# ═══════════════════════════════════════════════════════════════════════════
*)
  echo "ERROR: Unbekannter Befehl '$ACTION'" >&2
  echo "Usage: wf_advance.sh {approve|feedback|rollback|complete}" >&2
  echo ""
  echo "  approve              — Advance nach User-Approval"
  echo "  feedback 'MESSAGE'   — Gleiche Phase nochmal mit Feedback"
  echo "  rollback TARGET 'MSG'— Rollback zu frueherer Phase"
  echo "  complete             — Workflow als completed markieren"
  exit 1
  ;;

esac
