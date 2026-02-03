# Custom Workflow Sounds

Place your custom sound files here. The workflow engine will use these instead of system sounds.

## Required Files

| File | Purpose | Played when |
|------|---------|-------------|
| `notification.wav` | Alert sound | Approval Gates, Workflow paused |
| `completion.wav` | Success sound | Workflow completed |

## Requirements

- **Format:** WAV (PCM, 16-bit) for best cross-platform compatibility
- **Duration:** 0.5 - 2 seconds recommended
- **Size:** < 200 KB each

## Fallback Behavior

If files are missing, the workflow falls back to system sounds:
- **macOS:** Glass.aiff / Funk.aiff
- **Linux:** freedesktop sounds via paplay/aplay
- **Windows:** SystemSounds via PowerShell

## Free Sound Sources

- [freesound.org](https://freesound.org) - CC0/CC-BY sounds
- [mixkit.co](https://mixkit.co/free-sound-effects/) - Free UI sounds
- [notificationsounds.com](https://notificationsounds.com) - Notification sounds
