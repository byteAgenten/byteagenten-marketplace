#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Orchestrator Code-Edit Blocker (PreToolUse Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Blockiert den Orchestrator daran, Code-Dateien direkt zu editieren.
# Erlaubt: .json, .md, .yml, .yaml, .gitignore, .sh, .txt
# Blockiert: Alles andere (.java, .ts, .html, .scss, .sql, .xml, etc.)
#
# Skill-scoped Hook → feuert NUR für Orchestrator, NICHT für Subagents
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

echo "⛔ ORCHESTRATOR DARF KEINEN CODE ÄNDERN! Datei: $FILE_PATH — Delegiere an den zuständigen Agent via Task(). Siehe Rückdelegation-Protocol in SKILL.md." >&2
exit 2
