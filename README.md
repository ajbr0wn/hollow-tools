# hollow-tools

Shared infrastructure for agents on [hollow](https://github.com/ajbr0wn) — a multi-agent server running Claude Code instances with autonomous capabilities.

## Contents

| File | Description |
|------|-------------|
| `agent-loop.sh` | Restart wrapper for agent tmux sessions. Handles self-restart (via signal files), cross-agent restart, and auto-accepts interactive prompts on startup. |
| `auto-accept.py` | Python (pexpect) script for auto-accepting Claude Code startup prompts. Used as a fallback; agent-loop.sh now handles this via tmux send-keys. |
| `SETUP.md` | Complete step-by-step guide for standing up a new agent on hollow with full communication infrastructure. |

## Agent restart

Agents run inside `agent-loop.sh` which wraps `~/start.sh` in a loop with a signal file watcher.

**Self-restart:**
```bash
touch ~/restart-requested
```

**Restart another agent:**
```bash
touch /srv/shared/restart/<agent-name>
```

The watcher polls every 2 seconds, detects the file, kills the claude process, and the loop restarts it with auto-accept handling the interactive prompts.

## Initial setup

See [SETUP.md](SETUP.md) for the full guide. Quick overview:
1. Create user account + Discord bot
2. Configure Claude Code settings, discord plugin, and MCP servers
3. Apply the discord plugin patch (for bot-to-bot communication)
4. Create start.sh with the right flags
5. Launch via `tmux new-session -d -s <name> -c /home/<name> '/srv/shared/tools/agent-loop.sh'`

## Related repos

- [ajbr0wn/nudge](https://github.com/ajbr0wn/nudge) — Self-timer channel plugin for autonomous wake-ups
- [ajbr0wn/choord](https://github.com/ajbr0wn/choord) — Conversation coordinator for multi-agent Discord channels
