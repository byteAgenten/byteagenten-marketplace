#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Workflow Orchestrator (Stop Hook) — Boomerang + Ralph-Loop
# ═══════════════════════════════════════════════════════════════════════════
# Deterministischer Workflow-Controller. KEIN LLM trifft Entscheidungen.
#
# Architektur-Prinzipien:
#   1. RALPH LOOP: while !verify_done; do spawn_agent; done
#   2. BOOMERANG:  Agents laufen isoliert, Orchestrator prueft extern
#   3. DETERMINISMUS: Alle Transitions in Shell, nie im LLM
#
# Output-Kanaele:
#   stdout JSON {"decision":"block","reason":"..."}  → Claude MUSS weitermachen
#   stdout (kein JSON, exit 0)                       → Claude darf stoppen
#   Log-Datei (.workflow/logs/hooks.log)             → Debugging
#   State (jq auf workflow-state.json)               → Direkte Modifikation
#
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# HOOK INIT: Stdin lesen + CWD aus Hook-Input
# Hooks koennen von beliebigem CWD gestartet werden. Wir nutzen cwd aus
# dem Hook-Input um ins Projekt-Root zu wechseln.
# Muss VOR set -e stehen damit Fehler nicht zum stillen Crash fuehren.
# ═══════════════════════════════════════════════════════════════════════════
INPUT=$(cat)
_DLOG="/tmp/bytA-orchestrator-debug.log"
{
  echo "=== $(date -u +"%Y-%m-%dT%H:%M:%SZ") ==="
  echo "CWD_BEFORE=$(pwd)"
  echo "DOLLAR_ZERO=$0"
  echo "PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-unset}"
} >> "$_DLOG" 2>/dev/null || true

_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
if [ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ]; then
  cd "$_HOOK_CWD"
fi

{
  echo "CWD_AFTER=$(pwd)"
  echo "WF_EXISTS=$(test -f .workflow/workflow-state.json && echo yes || echo no)"
} >> "$_DLOG" 2>/dev/null || true

trap 'echo "ERR exit=$? line=$LINENO cmd=$BASH_COMMAND" >> "'"$_DLOG"'" 2>/dev/null || true' ERR

set -e

# ═══════════════════════════════════════════════════════════════════════════
# KONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOGS_DIR="${WORKFLOW_DIR}/logs"

# Source phase configuration (CLAUDE_PLUGIN_ROOT ist zuverlaessiger als $0 im Hook-Kontext)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# Stop-Hook-spezifische Felder aus bereits gelesenem INPUT
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING (nur in Datei, NICHT auf stdout)
# ═══════════════════════════════════════════════════════════════════════════
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

  log "BLOCK ($count/$MAX_STOP_HOOK_BLOCKS): ${reason:0:200}"
  log_transition "stop_hook_block" "count=$count"

  jq -n --arg r "$reason" '{"decision":"block","reason":$r}'
  exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-AWARE DISPATCH: Phase 0 uses Team Planning Protocol, not single agent
# ═══════════════════════════════════════════════════════════════════════════
build_dispatch_msg() {
  local phase=$1
  local prompt=$2
  local phase_agent
  phase_agent=$(get_phase_agent "$phase")

  if [ "$phase" = "0" ]; then
    # Phase 0 = Team Planning Protocol — inline instructions (survive compaction)
    # WICHTIG: $prompt IST bereits der komplette Output von wf_prompt_builder.sh.
    # Claude soll ihn DIREKT parsen, NICHT nochmal wf_prompt_builder.sh aufrufen!
    echo "TEAM PLANNING PROTOCOL — Parse und fuehre das folgende Protokoll DIREKT aus (NICHT nochmal wf_prompt_builder.sh aufrufen!): 0) touch .workflow/.team-planning-active, 1) TeamCreate(team_name aus TEAM_NAME-Zeile), 2) Spawne ALLE Specialists + HUB parallel via Task() mit den Prompts aus den SPECIALIST/HUB-Bloecken, 3) Warte auf Architect Done-Nachricht, 4) Pruefe ob ALLE Spec-Dateien aus VERIFY-Block existieren, 5) Sende shutdown_request an alle Teammates, 6) TeamDelete, 7) rm -f .workflow/.team-planning-active, 8) Sage Done. Bei TeamCreate-Fehler: rm -f .workflow/.team-planning-active, dann Fallback auf single Task(bytA:architect-planner). --- PROTOKOLL-START --- $prompt --- PROTOKOLL-ENDE ---"
  else
    echo "Task(bytA:$phase_agent, '$prompt')"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# SOUND NOTIFICATIONS
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

play_notification() {
  play_sound "notification.wav" "/System/Library/Sounds/Glass.aiff" "/usr/share/sounds/freedesktop/stereo/bell.oga"
}

play_completion() {
  play_sound "completion.wav" "/System/Library/Sounds/Funk.aiff" "/usr/share/sounds/freedesktop/stereo/complete.oga"
}

# ═══════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════

get_retry_count() {
  jq -r ".recovery.phase_${1}_attempts // 0" "$WORKFLOW_FILE" 2>/dev/null || echo "0"
}

increment_retry() {
  local phase=$1
  local current=$(get_retry_count "$phase")
  local new=$((current + 1))
  jq ".recovery.phase_${phase}_attempts = ${new}" \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
  echo "$new"
}

reset_retry() {
  local phase=$1
  jq "del(.recovery.phase_${phase}_attempts)" \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE" 2>/dev/null || true
}

# NOTE: subagent_done.sh (SubagentStop hook) commits CODE changes when the agent finishes.
# This function commits STATE changes (workflow-state.json updates from phase transitions).
# Both hooks use git add -A so timing determines who commits what.
create_wip_commit() {
  local phase=$1
  local phase_name
  phase_name=$(get_phase_name "$phase")

  git add -A 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    local msg="wip(#${ISSUE_NUM}/phase-${phase}): ${phase_name} - ${ISSUE_TITLE:0:50}"
    git commit -m "$msg" 2>/dev/null && log "WIP-Commit: $msg" || true
  fi
}

mark_phase_completed() {
  local phase=$1
  local phase_name
  phase_name=$(get_phase_name "$phase")

  jq --argjson p "$phase" --arg name "$phase_name" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '.phases[($p | tostring)] = {"name": $name, "status": "completed", "completedAt": $ts}' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  log "Phase $phase ($phase_name) marked completed"
}

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFUNG: Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════

# Skill-Session-Marker: Wird vom SKILL.md Startup gesetzt.
# Wenn Marker existiert aber kein Workflow → Startup wurde nicht abgeschlossen.
SESSION_MARKER="${WORKFLOW_DIR}/bytA-session"

if [ ! -f "$WORKFLOW_FILE" ]; then
  if [ -f "$SESSION_MARKER" ]; then
    # Skill ist aktiv, aber Workflow nicht initialisiert → BLOCK
    # Claude MUSS den Startup-Prozess abschliessen
    jq -n --arg r "STARTUP UNVOLLSTAENDIG: Skill aktiv aber kein workflow-state.json gefunden. Fuehre den SKILL.md Startup-Prozess aus: 1. wf_cleanup.sh 2. mkdir -p .workflow/logs .workflow/specs .workflow/recovery 3. User nach Issue/Branch fragen 4. workflow-state.json erstellen 5. Phase 0 starten mit Task(bytA:architect-planner, ...)" \
      '{"decision":"block","reason":$r}'
    exit 0
  fi
  # Kein Skill aktiv, kein Workflow → nichts zu tun
  exit 0
fi

mkdir -p "$LOGS_DIR" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# Plugin-Level Hooks feuern GLOBAL — andere Plugins (z.B. byt8) haben
# eigene Stop-Hooks die denselben workflow-state.json lesen/schreiben.
# Ohne diesen Guard: Race Condition + State-Corruption.
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEAM PLANNING GUARD: Skip orchestrator while Phase 0 team is active.
# During team planning, the transport layer manages the entire flow
# (TeamCreate → spawn agents → wait → cleanup → Done). The Stop hook
# must NOT fire until the transport layer says "Done." after cleanup.
# The marker is set by SKILL.md before TeamCreate and removed after TeamDelete.
# ═══════════════════════════════════════════════════════════════════════════
if [ -f "${WORKFLOW_DIR}/.team-planning-active" ]; then
  log "Team planning active: skipping orchestrator (transport layer handles Phase 0)"
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# ADVANCING GUARD: Prevent re-entrant orchestrator calls
# The lock file prevents race conditions from concurrent Stop events.
# ═══════════════════════════════════════════════════════════════════════════
LOCK_FILE="${WORKFLOW_DIR}/.advancing"
if [ -f "$LOCK_FILE" ]; then
  log "Advancing guard: another orchestrator call in progress, skipping"
  exit 0
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ═══════════════════════════════════════════════════════════════════════════
# SESSION CLAIM: Erste Session die den Orchestrator triggert wird Owner.
# Andere Sessions (z.B. fuer Issue-Erstellung) werden NICHT blockiert.
# Bei Resume aendert sich die session_id → session_recovery.sh aktualisiert.
# ═══════════════════════════════════════════════════════════════════════════
_CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
_OWNER_SESSION=$(jq -r '.ownerSessionId // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ -z "$_OWNER_SESSION" ] && [ -n "$_CURRENT_SESSION" ]; then
  jq --arg sid "$_CURRENT_SESSION" '.ownerSessionId = $sid' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
  log "SESSION CLAIM: ownerSessionId set to ${_CURRENT_SESSION:0:12}..."
fi

# State lesen
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")

PHASE_NAME=$(get_phase_name "$PHASE")
PHASE_AGENT=$(get_phase_agent "$PHASE")

log "Stop Hook: Phase $PHASE ($PHASE_NAME) | Status: $STATUS | stop_hook_active: $STOP_HOOK_ACTIVE"

# ═══════════════════════════════════════════════════════════════════════════
# LOOP-PREVENTION: Zu viele consecutive blocks → Workflow pausieren
# ═══════════════════════════════════════════════════════════════════════════
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  BLOCK_COUNT=$(jq -r '.stopHookBlockCount // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
  if [ "$BLOCK_COUNT" -ge "$MAX_STOP_HOOK_BLOCKS" ]; then
    jq '.status = "paused" | .pauseReason = "stop_hook_loop_detected"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    log "LOOP DETECTED: $BLOCK_COUNT blocks. Pausing."
    log_transition "loop_detected" "blockCount=$BLOCK_COUNT"
    play_notification
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# STATUS-HANDLING: Nicht-aktive Zustaende → Claude darf stoppen
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" = "completed" ]; then
  # Dauer berechnen (nur einmal)
  COMPLETED_AT_EXISTS=$(jq -r '.completedAt // ""' "$WORKFLOW_FILE" 2>/dev/null)
  if [ -z "$COMPLETED_AT_EXISTS" ] || [ "$COMPLETED_AT_EXISTS" = "null" ]; then
    COMPLETED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg ca "$COMPLETED_AT" '.completedAt = $ca' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    log "Workflow completed: #${ISSUE_NUM} - ${ISSUE_TITLE}"
    # Session-Marker entfernen (Skill nicht mehr aktiv)
    rm -f "${WORKFLOW_DIR}/bytA-session"
    play_completion
  fi
  exit 0
fi

if [ "$STATUS" = "paused" ] || [ "$STATUS" = "idle" ]; then
  log "Stop allowed: Status=$STATUS"
  exit 0
fi

if [ "$STATUS" = "awaiting_approval" ]; then
  # ═══════════════════════════════════════════════════════════════════════
  # GUARD: Verify GLOB criteria even in awaiting_approval
  # GLOB = "Agent produced output" (must always be verified)
  # STATE = "Advance condition" (skipped here, checked by normal flow)
  # Without this guard, LLM can set awaiting_approval and skip verify!
  # ═══════════════════════════════════════════════════════════════════════
  CRITERION=$(get_phase_criterion "$PHASE")
  GLOB_FAILED=false

  if echo "$CRITERION" | grep -q "GLOB:"; then
    OLD_IFS="$IFS"
    IFS='+'
    for PART in $CRITERION; do
      case "$PART" in
        GLOB:*)
          PATTERN="${PART#GLOB:}"
          if ! ls $PATTERN > /dev/null 2>&1; then
            GLOB_FAILED=true
          fi
          ;;
      esac
    done
    IFS="$OLD_IFS"
  fi

  if [ "$GLOB_FAILED" = "true" ]; then
    log "GUARD: awaiting_approval but GLOB criterion NOT met for Phase $PHASE ($PHASE_NAME). Resetting to active."
    log_transition "criterion_bypass_blocked" "phase=$PHASE"

    jq '.status = "active"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    RETRY=$(increment_retry "$PHASE")
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
      jq --arg reason "criterion_bypass_phase_${PHASE}" \
        '.status = "paused" | .pauseReason = $reason' \
        "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
      log "MAX RETRIES ($MAX_RETRIES) for Phase $PHASE (criterion bypass). Pausing."
      play_notification
      exit 0
    fi

    PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$PHASE")
    # Phase 0: Marker setzen BEVOR output_block, damit nachfolgende Stop-Hooks skippen
    if [ "$PHASE" = "0" ]; then
      touch "${WORKFLOW_DIR}/.team-planning-active"
    fi
    DISPATCH=$(build_dispatch_msg "$PHASE" "$PROMPT")
    output_block "GUARD: Phase $PHASE ($PHASE_NAME) als awaiting_approval markiert, aber GLOB-Kriterium NICHT erfuellt (Versuch $RETRY/$MAX_RETRIES). Starte: $DISPATCH"
  fi

  log "Stop allowed: awaiting_approval (Phase $PHASE, GLOB verified)"
  exit 0
fi

# Nur active weiterverarbeiten
if [ "$STATUS" != "active" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# PAUSE CHECK: User hat Pause angefordert → Workflow pausieren
# ═══════════════════════════════════════════════════════════════════════════
if [ -f "${WORKFLOW_DIR}/.pause-requested" ]; then
  rm -f "${WORKFLOW_DIR}/.pause-requested"
  jq '.status = "paused" | .pauseReason = "user_requested"' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
  log "PAUSE: User-requested at Phase $PHASE ($PHASE_NAME)"
  log_transition "user_pause" "phase=$PHASE"
  play_notification
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# AB HIER: status = active → RALPH LOOP
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# PHASE-SKIP GUARD: Fehlende Vorgaenger-Phasen abfangen
# ═══════════════════════════════════════════════════════════════════════════
detect_skipped_phase() {
  local current=$1
  local i=0

  while [ $i -lt $current ]; do
    local ps
    ps=$(jq -r ".phases[\"$i\"].status // \"pending\"" "$WORKFLOW_FILE" 2>/dev/null || echo "pending")
    if [ "$ps" = "completed" ] || [ "$ps" = "skipped" ]; then
      i=$((i + 1))
      continue
    fi

    # Context-Check fuer pending Phasen
    local has_context=true
    case $i in
      0) jq -e '.context.technicalSpec | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      1) jq -e '.context.migrations | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      2) jq -e '.context.backendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      3) jq -e '.context.frontendImpl | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      4) jq -e '.context.testResults | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      5) jq -e '.context.securityAudit | keys | length > 0' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
      6) jq -e '.context.reviewFeedback.userApproved == true' "$WORKFLOW_FILE" > /dev/null 2>&1 || has_context=false ;;
    esac

    if [ "$has_context" = "false" ]; then
      echo "$i"
      return
    fi
    i=$((i + 1))
  done
  echo ""
}

SKIPPED_TO=$(detect_skipped_phase "$PHASE")
if [ -n "$SKIPPED_TO" ]; then
  SKIP_NAME=$(get_phase_name "$SKIPPED_TO")
  SKIP_AGENT=$(get_phase_agent "$SKIPPED_TO")

  log "PHASE SKIP DETECTED: Phase $PHASE requires Phase $SKIPPED_TO ($SKIP_NAME). Auto-correcting."
  log_transition "phase_skip_corrected" "from=$PHASE to=$SKIPPED_TO"

  jq --argjson sp "$SKIPPED_TO" --arg name "$SKIP_NAME" \
    '.phases[($sp | tostring)] = {"name": $name, "status": "active"} | .currentPhase = $sp | .status = "active"' \
    "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

  # Build prompt for skipped phase
  PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$SKIPPED_TO")
  # Phase 0: Marker setzen BEVOR output_block, damit nachfolgende Stop-Hooks skippen
  if [ "$SKIPPED_TO" = "0" ]; then
    touch "${WORKFLOW_DIR}/.team-planning-active"
  fi
  DISPATCH=$(build_dispatch_msg "$SKIPPED_TO" "$PROMPT")
  output_block "PHASE-SKIP KORRIGIERT: Phase $SKIPPED_TO ($SKIP_NAME) fehlt. State korrigiert. Starte sofort: $DISPATCH"
fi

# ═══════════════════════════════════════════════════════════════════════════
# VERIFY: Ist die aktuelle Phase fertig? (EXTERNE Pruefung!)
# ═══════════════════════════════════════════════════════════════════════════
if "${SCRIPT_DIR}/wf_verify.sh" "$PHASE"; then
  # ═════════════════════════════════════════════════════════════════════════
  # PHASE DONE — Transition
  # ═════════════════════════════════════════════════════════════════════════

  # ─────────────────────────────────────────────────────────────────────────
  # SKIP-ADVANCE: Phase pre-skipped → bypass approval, auto-advance
  # ─────────────────────────────────────────────────────────────────────────
  CURRENT_PHASE_STATUS=$(jq -r ".phases[\"$PHASE\"].status // \"pending\"" "$WORKFLOW_FILE" 2>/dev/null)
  if [ "$CURRENT_PHASE_STATUS" = "skipped" ]; then
    NEXT_PHASE=$(get_next_active_phase "$PHASE")
    NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
    NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")

    jq --argjson np "$NEXT_PHASE" --arg name "$NEXT_NAME" \
      '.phases[($np | tostring)] = {"name": $name, "status": "active"} | .currentPhase = $np | .status = "active"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "SKIP-ADVANCE: Phase $PHASE ($PHASE_NAME) pre-skipped → Phase $NEXT_PHASE ($NEXT_NAME)"
    log_transition "skip_advance" "from=$PHASE to=$NEXT_PHASE"

    PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$NEXT_PHASE")
    output_block "Phase $PHASE ($PHASE_NAME) uebersprungen (pre-skipped). Starte Phase $NEXT_PHASE ($NEXT_NAME): Task(bytA:$NEXT_AGENT, '$PROMPT')"
  fi

  reset_retry "$PHASE"

  # ─────────────────────────────────────────────────────────────────────────
  # RE-COMPLETION GUARD: Bereits completed Phasen nicht nochmal completen
  # Verhindert Endlos-Zyklen wenn LLM currentPhase auf completed Phase setzt
  # ─────────────────────────────────────────────────────────────────────────
  EXISTING_PHASE_STATUS=$(jq -r ".phases[\"$PHASE\"].status // \"\"" "$WORKFLOW_FILE" 2>/dev/null)
  if [ "$EXISTING_PHASE_STATUS" = "completed" ]; then
    log "RE-COMPLETION GUARD: Phase $PHASE already completed. Skipping mark_phase_completed."
    log_transition "re_completion_blocked" "phase=$PHASE"
  else
    mark_phase_completed "$PHASE"
  fi

  # WIP-Commit (silent)
  if needs_commit "$PHASE"; then
    create_wip_commit "$PHASE"
  fi

  if needs_approval "$PHASE"; then
    # ═══════════════════════════════════════════════════════════════════════
    # APPROVAL GATE → Claude darf stoppen, User antwortet
    # ═══════════════════════════════════════════════════════════════════════
    jq '.status = "awaiting_approval" | .awaitingApprovalFor = .currentPhase | del(.recovery.rollbackContext)' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "APPROVAL GATE: Phase $PHASE ($PHASE_NAME) done. awaiting_approval gesetzt."
    log_transition "approval_gate" "phase=$PHASE"
    play_notification

    # Ergebnis-Datei fuer den Approval-Kontext finden
    PHASE_PAD=$(printf "%02d" "$PHASE")
    SPEC_FILE=$(ls .workflow/specs/issue-*-ph${PHASE_PAD}-*.md 2>/dev/null | head -1 || echo "")
    # Phase 0 hat plan-consolidated.md statt ph00-*.md
    if [ -z "$SPEC_FILE" ] && [ "$PHASE" = "0" ]; then
      SPEC_FILE=$(ls .workflow/specs/issue-*-plan-consolidated.md 2>/dev/null | head -1 || echo "")
    fi

    APPROVAL_MSG="APPROVAL GATE: Phase $PHASE ($PHASE_NAME) ist abgeschlossen."

    if [ -n "$SPEC_FILE" ]; then
      # ─── Spec-Datei: Vorschau aus ersten 40 Zeilen extrahieren ───
      # Spart ~20K+ Tokens weil Claude die Datei NICHT selbst lesen muss.
      SPEC_PREVIEW=$(head -40 "$SPEC_FILE" 2>/dev/null || echo "(Vorschau nicht verfuegbar)")
      APPROVAL_MSG="$APPROVAL_MSG Ergebnis: $SPEC_FILE — VORSCHAU (erste 40 Zeilen, NICHT die Datei lesen!): --- $SPEC_PREVIEW ---"
    fi

    APPROVAL_MSG="$APPROVAL_MSG Praesentiere dem User die Vorschau/Ergebnisse. Frage dann: 'Soll ich mit dem Workflow fortfahren? (approve/weiter) oder hast du Aenderungswuensche?' WICHTIG: KEINE Datei lesen! Die Vorschau oben reicht. Fuehre KEINE weiteren Aktionen aus — warte auf die Antwort des Users."

    output_block "$APPROVAL_MSG"

  else
    # ═══════════════════════════════════════════════════════════════════════
    # AUTO-ADVANCE → Naechste Phase (deterministisch)
    # ═══════════════════════════════════════════════════════════════════════
    NEXT_PHASE=$(get_next_active_phase "$PHASE")
    NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
    NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")

    jq --argjson np "$NEXT_PHASE" --arg name "$NEXT_NAME" \
      '.phases[($np | tostring)] = {"name": $name, "status": "active"} | .currentPhase = $np | .status = "active"' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"

    log "AUTO-ADVANCE: Phase $PHASE ($PHASE_NAME) → Phase $NEXT_PHASE ($NEXT_NAME)"
    log_transition "auto_advance" "from=$PHASE to=$NEXT_PHASE"

    # ─── Phase Summary extrahieren (Sichtbarkeit fuer User) ──────────
    _SUMMARY_PAD=$(printf "%02d" "$PHASE")
    _SUMMARY_SPEC=$(ls .workflow/specs/issue-*-ph${_SUMMARY_PAD}-*.md 2>/dev/null | head -1 || echo "")
    _PHASE_SUMMARY=""
    if [ -n "$_SUMMARY_SPEC" ]; then
      _PHASE_SUMMARY=$(head -10 "$_SUMMARY_SPEC" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' || echo "")
    fi

    # Build prompt for next phase
    PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$NEXT_PHASE")

    _BLOCK_MSG="Phase $PHASE ($PHASE_NAME) DONE."
    if [ -n "$_PHASE_SUMMARY" ]; then
      _BLOCK_MSG="$_BLOCK_MSG [SUMMARY: ${_PHASE_SUMMARY:0:300}]"
    fi
    _BLOCK_MSG="$_BLOCK_MSG Auto-Advance zu Phase $NEXT_PHASE ($NEXT_NAME). Starte sofort: Task(bytA:$NEXT_AGENT, '$PROMPT')"
    output_block "$_BLOCK_MSG"
  fi

else
  # ═════════════════════════════════════════════════════════════════════════
  # PHASE NICHT FERTIG — Ralph-Loop: Re-spawn oder Pause
  # ═════════════════════════════════════════════════════════════════════════

  # ─────────────────────────────────────────────────────────────────────────
  # GUARD: Phase muss existieren (Orchestrator hat zu frueh transitioned)
  # ─────────────────────────────────────────────────────────────────────────
  PHASE_EXISTS=$(jq -r ".phases[\"$PHASE\"] // \"null\"" "$WORKFLOW_FILE" 2>/dev/null)
  if [ "$PHASE_EXISTS" = "null" ]; then
    log "GUARD: Phase $PHASE not in phases[]. Initializing and continuing Ralph-Loop."
    log_transition "phase_initialized" "phase=$PHASE"
    jq --argjson p "$PHASE" --arg name "$PHASE_NAME" \
      '.phases[($p | tostring)] = {"name": $name, "status": "active"}' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
  fi

  # ─────────────────────────────────────────────────────────────────────────
  # RALPH LOOP: Retry-Counter pruefen, Agent re-spawnen
  # ─────────────────────────────────────────────────────────────────────────
  RETRY=$(increment_retry "$PHASE")

  if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
    jq --arg reason "max_retries_phase_${PHASE}" \
      '.status = "paused" | .pauseReason = $reason' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    log "MAX RETRIES ($MAX_RETRIES) for Phase $PHASE. Pausing."
    log_transition "max_retries" "phase=$PHASE retry=$RETRY"
    play_notification
    exit 0
  fi

  log "RALPH-LOOP: Phase $PHASE ($PHASE_NAME), attempt $RETRY/$MAX_RETRIES"
  log_transition "ralph_loop_retry" "phase=$PHASE retry=$RETRY"

  # Build prompt with retry context
  PROMPT=$("${SCRIPT_DIR}/wf_prompt_builder.sh" "$PHASE")
  # Phase 0: Marker setzen BEVOR output_block, damit nachfolgende Stop-Hooks skippen
  if [ "$PHASE" = "0" ]; then
    touch "${WORKFLOW_DIR}/.team-planning-active"
  fi
  DISPATCH=$(build_dispatch_msg "$PHASE" "$PROMPT")
  output_block "RALPH-LOOP Phase $PHASE ($PHASE_NAME) nicht fertig (Versuch $RETRY/$MAX_RETRIES). Starte: $DISPATCH"
fi
