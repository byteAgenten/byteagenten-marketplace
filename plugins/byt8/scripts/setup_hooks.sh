#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Setup Hooks Script
# ═══════════════════════════════════════════════════════════════════════════
# Configures Stop and SubagentStop hooks in project settings.
# Run via: /byt8:setup-hooks
# ═══════════════════════════════════════════════════════════════════════════

set -e

SETTINGS_FILE=".claude/settings.json"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/byteagenten-marketplace/byt8"

echo "═══════════════════════════════════════════════════════════════════════════"
echo "  byt8 Workflow Hooks Setup"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Find the latest plugin version
PLUGIN_VERSION=$(ls -1 "$PLUGIN_CACHE" 2>/dev/null | sort -V | tail -1)

if [ -z "$PLUGIN_VERSION" ]; then
    echo "❌ ERROR: byt8 plugin not found in cache."
    echo "   Expected: $PLUGIN_CACHE/<version>/"
    echo ""
    echo "   Please install the plugin first:"
    echo "   /plugin install byteagenten-marketplace"
    exit 1
fi

PLUGIN_ROOT="$PLUGIN_CACHE/$PLUGIN_VERSION"
echo "✓ Found plugin: $PLUGIN_ROOT"

# Verify scripts exist
if [ ! -f "$PLUGIN_ROOT/scripts/wf_engine.sh" ]; then
    echo "❌ ERROR: wf_engine.sh not found"
    exit 1
fi

if [ ! -f "$PLUGIN_ROOT/scripts/subagent_done.sh" ]; then
    echo "❌ ERROR: subagent_done.sh not found"
    exit 1
fi

echo "✓ Scripts verified"

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
    jq --arg wf "$PLUGIN_ROOT/scripts/wf_engine.sh" \
       --arg sa "$PLUGIN_ROOT/scripts/subagent_done.sh" \
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
    
    # Create new settings file
    cat > "$SETTINGS_FILE" << EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$PLUGIN_ROOT/scripts/wf_engine.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$PLUGIN_ROOT/scripts/subagent_done.sh"
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
echo "  Active hooks:"
echo "  ┌─────────────────┬─────────────────────────────────────────────────────┐"
echo "  │ SessionStart    │ session_recovery.sh (context recovery) - from plugin│"
echo "  │ Stop            │ wf_engine.sh (phase validation, auto-commits)       │"
echo "  │ SubagentStop    │ subagent_done.sh (agent output validation)          │"
echo "  └─────────────────┴─────────────────────────────────────────────────────┘"
echo ""
echo "  Config file: $SETTINGS_FILE"
echo ""
echo "  To verify: cat $SETTINGS_FILE"
echo "  To remove: /byt8:remove-hooks"
echo ""
