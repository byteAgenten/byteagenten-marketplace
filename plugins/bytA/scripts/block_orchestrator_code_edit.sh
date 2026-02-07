#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Orchestrator Code-Edit Blocker (PreToolUse/Edit|Write Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Code-Dateien direkt zu editieren.
# Erlaubt: .json, .md, .yml, .yaml, .gitignore, .sh, .txt
# Blockiert: Alles andere (.java, .ts, .html, .scss, .sql, .xml, etc.)
#
# Skill-scoped Hook → feuert NUR fuer Orchestrator, NICHT fuer Subagents
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // ""')

# Kein Dateipfad → durchlassen
if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "null" ]; then
  exit 0
fi

# Erlaubte Dateitypen (Config, Doku, Workflow)
case "$FILE_PATH" in
  *.json|*.md|*.yml|*.yaml|*.sh|*.gitignore|*.txt)
    exit 0
    ;;
esac

# Alles andere = Code-Datei → BLOCKIEREN
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: Orchestrator tried to edit $FILE_PATH" >> "$LOG_DIR/hooks.log"

echo "ORCHESTRATOR DARF KEINEN CODE AENDERN! Datei: $FILE_PATH — Delegiere an den zustaendigen Agent via Task(bytA:AGENT)." >&2
exit 2
