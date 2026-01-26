#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Setup Hooks Script
# ═══════════════════════════════════════════════════════════════════════════
# Configures Stop and SubagentStop hooks in project settings.
# Run via: /byt8:setup-hooks
#
# IMPORTANT: Uses ${CLAUDE_PLUGIN_ROOT} which is resolved by Claude Code at
# runtime. This ensures hooks always point to the current plugin version.
# ═══════════════════════════════════════════════════════════════════════════

set -e

SETTINGS_FILE=".claude/settings.json"

# Script paths using Claude Code's runtime variable
# These are literal strings that Claude Code resolves at hook execution time
WF_ENGINE_CMD='${CLAUDE_PLUGIN_ROOT}/scripts/wf_engine.sh'
SUBAGENT_DONE_CMD='${CLAUDE_PLUGIN_ROOT}/scripts/subagent_done.sh'

echo "═══════════════════════════════════════════════════════════════════════════"
echo "  byt8 Workflow Hooks Setup"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "✓ Using \${CLAUDE_PLUGIN_ROOT} for version-independent paths"

# Create .claude directory if needed
mkdir -p .claude

# Check if settings.json exists
if [ -f "$SETTINGS_FILE" ]; then
    echo "✓ Found existing $SETTINGS_FILE"

    # Backup existing
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
    echo "✓ Backup created: ${SETTINGS_FILE}.backup"

    # Check if hooks already configured
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo ""
        echo "⚠️  Hooks already configured. Overwrite? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    # Merge hooks into existing settings (preserve other settings)
    # Note: Using literal ${CLAUDE_PLUGIN_ROOT} which Claude Code resolves at runtime
    jq --arg wf "$WF_ENGINE_CMD" \
       --arg sa "$SUBAGENT_DONE_CMD" \
       '.hooks.Stop = [{
            "hooks": [{
                "type": "command",
                "command": $wf
            }]
        }] | .hooks.SubagentStop = [{
            "hooks": [{
                "type": "command",
                "command": $sa
            }]
        }]' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
else
    echo "✓ Creating new $SETTINGS_FILE"

    # Create new settings file with ${CLAUDE_PLUGIN_ROOT} (literal string)
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/wf_engine.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/subagent_done.sh"
          }
        ]
      }
    ]
  }
}
EOF
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  ✅ Hooks configured successfully!"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Active hooks (using \${CLAUDE_PLUGIN_ROOT} for version independence):"
echo "  ┌─────────────────┬─────────────────────────────────────────────────────┐"
echo "  │ SessionStart    │ session_recovery.sh (context recovery) - from plugin│"
echo "  │ Stop            │ wf_engine.sh (phase validation, auto-commits)       │"
echo "  │ SubagentStop    │ subagent_done.sh (agent output validation)          │"
echo "  └─────────────────┴─────────────────────────────────────────────────────┘"
echo ""
echo "  Paths resolve to current plugin version at runtime."
echo ""
echo "  Config file: $SETTINGS_FILE"
echo ""
echo "  To verify: cat $SETTINGS_FILE"
echo "  To remove: /byt8:remove-hooks"
echo ""
