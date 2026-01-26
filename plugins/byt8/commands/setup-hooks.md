---
name: setup-hooks
description: Configure workflow hooks in project settings for Stop and SubagentStop events.
---

# Setup Workflow Hooks

Configures byt8 workflow hooks in your project's `.claude/settings.json`.

**Why needed:** Plugin hooks only support `SessionStart`. For `Stop` and `SubagentStop` hooks to work, they must be registered in project settings.

## Usage

```
/byt8:setup-hooks
```

## What to do

Run the setup script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup_hooks.sh"
```

Or if `CLAUDE_PLUGIN_ROOT` is not available, find the plugin path:

```bash
PLUGIN_PATH=$(find ~/.claude/plugins/cache -name "setup_hooks.sh" -path "*byt8*" 2>/dev/null | head -1)
bash "$PLUGIN_PATH"
```

## After Setup

Active hooks:

| Hook | Script | Function |
|------|--------|----------|
| `SessionStart` | `session_recovery.sh` | Context recovery (from plugin) |
| `Stop` | `wf_engine.sh` | Phase validation, auto-commits, approval gates |
| `SubagentStop` | `subagent_done.sh` | Agent output validation |

## Uninstall

```
/byt8:remove-hooks
```
