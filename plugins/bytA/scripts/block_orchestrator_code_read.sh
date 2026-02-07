#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Orchestrator Code-Read Blocker (PreToolUse/Read Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Code-Dateien direkt zu lesen.
# Erlaubt: .json, .md, .yml, .yaml, .gitignore, .sh, .txt, .conf, .log
# Blockiert: Alles andere (.java, .ts, .html, .scss, .sql, .xml, etc.)
#
# Skill-scoped Hook → feuert NUR fuer Orchestrator, NICHT fuer Subagents
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
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

# Alles andere = Code-Datei → BLOCKIEREN
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: Orchestrator tried to read $FILE_PATH" >> "$LOG_DIR/hooks.log"

echo "ORCHESTRATOR DARF KEINEN CODE LESEN! Datei: $FILE_PATH — Agents lesen Code-Dateien selbst. Du bist nur Transport-Layer." >&2
exit 2
