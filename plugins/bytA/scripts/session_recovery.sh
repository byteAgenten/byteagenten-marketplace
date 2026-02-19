#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Session Recovery (SessionStart Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert bei Session-Start UND nach Context Compaction.
#
# source=startup/resume/clear → "Rufe /bytA:feature auf"
# source=compact             → Starke Transport-Layer Instruktionen
#                               + "Sage Done." (Stop-Hook uebernimmt)
#
# Nach Compaction darf NICHT /bytA:feature aufgerufen werden, weil
# wf_cleanup.sh den aktiven Workflow als BLOCKED meldet.
# Stattdessen: "Done." sagen → Stop-Hook fuehrt Ralph-Loop fort.
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
_HOOK_INPUT=$(cat)
_HOOK_CWD=$(echo "$_HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# Detect source (startup, resume, clear, compact)
SOURCE=$(echo "$_HOOK_INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")

# ═══════════════════════════════════════════════════════════════════════════
# PRUEFEN: Aktiver Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ] && [ "$STATUS" != "paused" ] && [ "$STATUS" != "awaiting_approval" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# RECOVERY: Kontext-Injektion
# ═══════════════════════════════════════════════════════════════════════════

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Unbekannt"' "$WORKFLOW_FILE")

PHASE_NAME=$(get_phase_name "$CURRENT_PHASE")

# Log recovery event
LOG_DIR="${WORKFLOW_DIR}/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$TIMESTAMP] SessionStart($SOURCE): Phase $CURRENT_PHASE ($PHASE_NAME) | Status: $STATUS" >> "$LOG_DIR/hooks.log"

# ═══════════════════════════════════════════════════════════════════════════
# SESSION RE-CLAIM: Bei resume/startup die ownerSessionId aktualisieren.
# Resume erzeugt eine neue session_id (by design, GitHub #8069).
# Startup = neue Session die den Workflow fortsetzen will.
# Compact = gleiche Session, gleiche ID → kein Update noetig.
# ═══════════════════════════════════════════════════════════════════════════
if [ "$SOURCE" = "resume" ] || [ "$SOURCE" = "startup" ]; then
  _CURRENT_SESSION=$(echo "$_HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
  if [ -n "$_CURRENT_SESSION" ]; then
    jq --arg sid "$_CURRENT_SESSION" '.ownerSessionId = $sid' \
      "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" && mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
    echo "[$TIMESTAMP] SESSION RE-CLAIM ($SOURCE): ownerSessionId → ${_CURRENT_SESSION:0:12}..." >> "$LOG_DIR/hooks.log"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# STALE MARKER CLEANUP: Team-Planning-Marker kann nicht Session-Grenzen
# ueberleben. Wenn die Session neu startet/resumed wird, ist das Team weg.
# ═══════════════════════════════════════════════════════════════════════════
rm -f "${WORKFLOW_DIR}/.team-planning-active" 2>/dev/null || true

# Stale Pause-Marker: Kann nach Session-Crash uebrig bleiben.
# Wenn Status bereits paused ist, wurde der Marker verarbeitet.
# Wenn Status active/awaiting_approval ist, war der Marker stale.
if [ -f "${WORKFLOW_DIR}/.pause-requested" ]; then
  rm -f "${WORKFLOW_DIR}/.pause-requested"
  echo "[$TIMESTAMP] STALE MARKER: .pause-requested removed (session restart)" >> "$LOG_DIR/hooks.log" 2>/dev/null || true
fi

if [ "$SOURCE" = "compact" ]; then
  # ═══════════════════════════════════════════════════════════════════════
  # COMPACT RECOVERY: Starke Transport-Layer Instruktionen
  # ═══════════════════════════════════════════════════════════════════════
  # Nach Compaction hat Claude die SKILL.md Instruktionen verloren.
  # Skill-Level Hooks in Plugins feuern NICHT (GitHub #17688).
  # Plugin-Level PreToolUse Hooks BLOCKIEREN Code-Zugriff deterministisch.
  # Dieser Hook re-injiziert die Kern-Instruktionen.
  # ═══════════════════════════════════════════════════════════════════════
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "⚠ WORKFLOW RECOVERY nach Context Compaction"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""
  echo "  Issue:  #${ISSUE_NUMBER} - ${ISSUE_TITLE}"
  echo "  Phase:  ${CURRENT_PHASE} (${PHASE_NAME})"
  echo "  Status: ${STATUS}"
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────────┐"
  echo "  │  DU BIST EIN TRANSPORT-LAYER — KEIN ENTWICKLER!            │"
  echo "  │                                                             │"
  echo "  │  VERBOTEN (Hooks blockieren technisch):                     │"
  echo "  │  - Code lesen (.ts, .java, .html, .scss, .xml, etc.)      │"
  echo "  │  - Code schreiben/editieren                                 │"
  echo "  │  - Bugs analysieren oder Loesungen vorschlagen             │"
  echo "  │  - Explore/general-purpose Agents starten                  │"
  echo "  │                                                             │"
  echo "  │  DEINE EINZIGE AKTION JETZT:                               │"
  echo "  │  Sage \"Done.\" — der Stop-Hook uebernimmt ALLES.           │"
  echo "  │                                                             │"
  echo "  │  Der Stop-Hook wird:                                        │"
  echo "  │  1. Den Workflow-State pruefen                              │"
  echo "  │  2. Die naechste Phase starten (oder Approval anfordern)   │"
  echo "  │  3. Dir den exakten Task()-Aufruf geben                    │"
  echo "  │                                                             │"
  echo "  │  DU MUSST NUR 'Done.' SAGEN!                               │"
  echo "  └─────────────────────────────────────────────────────────────┘"
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo ""
else
  # ═══════════════════════════════════════════════════════════════════════
  # NORMAL RECOVERY: Neue Session / Resume / Clear
  # ═══════════════════════════════════════════════════════════════════════
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "WORKFLOW RECOVERY nach Session-Neustart"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""
  echo "  Issue:  #${ISSUE_NUMBER} - ${ISSUE_TITLE}"
  echo "  Phase:  ${CURRENT_PHASE} (${PHASE_NAME})"
  echo "  Status: ${STATUS}"
  echo ""
  echo "  PFLICHT-AKTION: Rufe /bytA:feature auf!"
  echo ""
  echo "  Das laedt den Skill neu. Die Hooks uebernehmen dann:"
  echo "  - Stop Hook: Ralph-Loop setzt automatisch fort"
  echo "  - UserPromptSubmit Hook: Injiziert Approval-Gate-Kontext"
  echo "  - PreToolUse Hooks: Blockieren unerlaubte Aktionen"
  echo ""
  echo "  KEINE eigenstaendigen Aktionen ausfuehren!"
  echo "  NUR /bytA:feature aufrufen."
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo ""
fi
