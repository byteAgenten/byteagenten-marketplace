#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Git Push Guard (PreToolUse Hook - Plugin-Level)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert git push / gh pr create / gh pr merge während eines aktiven
# Workflows, es sei denn der User hat explizit zugestimmt (pushApproved).
#
# Plugin-Level Hook → feuert IMMER, auch nach Context Compaction wenn
# Claude außerhalb des Skills operiert.
#
# NICHT betroffen: git commit, git add, normales Arbeiten ohne Workflow.
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

WORKFLOW_FILE=".workflow/workflow-state.json"
LOG_DIR=".workflow/logs"

# ═══════════════════════════════════════════════════════════════════════════
# 1. Stdin JSON lesen → Command extrahieren
# ═══════════════════════════════════════════════════════════════════════════
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [ -z "$COMMAND" ] || [ "$COMMAND" = "null" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. Pattern-Check: Nur push/PR-Befehle prüfen
# ═══════════════════════════════════════════════════════════════════════════
case "$COMMAND" in
  *"git push"*|*"gh pr create"*|*"gh pr merge"*)
    # Weiter zur Workflow-Prüfung
    ;;
  *)
    exit 0  # Kein push/PR-Befehl → durchlassen
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# 3. Workflow-State prüfen
# ═══════════════════════════════════════════════════════════════════════════

# Kein Workflow vorhanden → erlauben
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur eigene Workflows verarbeiten
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "full-stack-feature" ]; then
  exit 0
fi

# State lesen (fail-open bei Parse-Fehler)
STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Workflow abgeschlossen oder idle → erlauben
case "$STATUS" in
  completed|idle|unknown)
    exit 0
    ;;
esac

# pushApproved-Flag prüfen
PUSH_APPROVED=$(jq -r '.pushApproved // false' "$WORKFLOW_FILE" 2>/dev/null || echo "false")

if [ "$PUSH_APPROVED" = "true" ]; then
  exit 0  # User hat zugestimmt → erlauben
fi

# ═══════════════════════════════════════════════════════════════════════════
# 4. BLOCKIEREN
# ═══════════════════════════════════════════════════════════════════════════

mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: git push/PR without approval. Status: $STATUS | Command: $COMMAND" >> "$LOG_DIR/hooks.log" 2>/dev/null || true

echo "⛔ PUSH/PR BLOCKIERT - Aktiver Workflow ohne User-Approval!" >&2
echo "" >&2
echo "Status: $STATUS | pushApproved: $PUSH_APPROVED" >&2
echo "" >&2
echo "Du operierst AUSSERHALB des Workflows. Das ist nach Context Compaction passiert." >&2
echo "git push und gh pr create sind gesperrt bis der User im Workflow zustimmt." >&2
echo "" >&2
echo "AKTION: Rufe /byt8:full-stack-feature auf um den Workflow fortzusetzen." >&2
echo "Phase 9 wird den User um Erlaubnis fragen und pushApproved setzen." >&2
exit 2
