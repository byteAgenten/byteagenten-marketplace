#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Orchestrator Code-Read Blocker (PreToolUse/Read Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Code-Dateien direkt zu lesen.
# Erlaubt: .json, .md, .yml, .yaml, .gitignore, .sh, .txt, .conf, .log, .jsonl
# Blockiert: Alles andere (.java, .ts, .html, .scss, .sql, .xml, etc.)
#
# Plugin-level Hook → feuert fuer ALLE Tool-Aufrufe (Orchestrator + Subagents)
# → Ownership Guard: nur bei aktivem bytA-feature Workflow
# → Subagent-Check: erlaubt wenn .subagent-active Marker existiert
# → JSON deny Pattern: zuverlaessiger als exit 2 (GitHub #13744)
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

# ═══════════════════════════════════════════════════════════════════════════
# OWNERSHIP GUARD: Nur bei aktivem bytA-feature Workflow blockieren
# ═══════════════════════════════════════════════════════════════════════════
WORKFLOW_FILE=".workflow/workflow-state.json"
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ "$WORKFLOW_TYPE" != "bytA-feature" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUBAGENT CHECK: Wenn Subagent aktiv → durchlassen (Subagents DUERFEN Code lesen)
# ═══════════════════════════════════════════════════════════════════════════
if [ -f ".workflow/.subagent-active" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# DATEITYP PRUEFEN: Erlaubte Dateitypen durchlassen
# ═══════════════════════════════════════════════════════════════════════════
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Kein Dateipfad → durchlassen
if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "null" ]; then
  exit 0
fi

# Erlaubte Dateitypen (Config, Doku, Workflow, Logs)
case "$FILE_PATH" in
  *.json|*.md|*.yml|*.yaml|*.sh|*.gitignore|*.txt|*.conf|*.log|*.jsonl)
    exit 0
    ;;
esac

# Workflow-Verzeichnis immer erlauben
case "$FILE_PATH" in
  *.workflow/*|*/.workflow/*)
    exit 0
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# BLOCKIEREN: Code-Datei im Orchestrator-Kontext
# ═══════════════════════════════════════════════════════════════════════════
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: Orchestrator tried to read $FILE_PATH" >> "$LOG_DIR/hooks.log"

# JSON deny Pattern (zuverlaessiger als exit 2)
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "ORCHESTRATOR DARF KEINEN CODE LESEN! Datei: '"$FILE_PATH"' — Agents lesen Code-Dateien selbst. Du bist nur Transport-Layer. Sage Done. und der Stop-Hook gibt dir den naechsten Task."
  }
}'
