---
description: Show bytA plugin version and cache path
---

# bytA Version

Ermittle die Plugin-Version und zeige sie dem User:

```bash
PLUGIN_ROOT=$(ls -d ~/.claude/plugins/cache/byteagenten-marketplace/bytA/*/scripts/ 2>/dev/null | head -1 | sed 's|/scripts/||')
PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
echo "bytA Plugin v${PLUGIN_VERSION} | Root: $PLUGIN_ROOT"
```

Zeige dem User:
- **Version:** aus plugin.json
- **Cache-Pfad:** wo das Plugin geladen wurde
- **Tipp:** Bei Problemen Cache clearen mit `rm -rf ~/.claude/plugins/cache/byteagenten-marketplace/` und Session neu starten.
