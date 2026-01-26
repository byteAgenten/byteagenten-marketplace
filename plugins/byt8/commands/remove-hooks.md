---
name: remove-hooks
description: Remove workflow hooks from project settings.
---

# Remove Workflow Hooks

Removes byt8 workflow hooks from your project's `.claude/settings.json`.

## Usage

```
/byt8:remove-hooks
```

## Implementation

```bash
#!/bin/bash
SETTINGS_FILE=".claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "No settings file found."
    exit 0
fi

# Remove Stop and SubagentStop hooks
jq 'del(.hooks.Stop, .hooks.SubagentStop)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

# Clean up empty hooks object
jq 'if .hooks == {} then del(.hooks) else . end' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

echo "✅ Hooks removed from $SETTINGS_FILE"
echo ""
echo "Note: SessionStart hook from plugin remains active."
```
