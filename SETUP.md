# Agent Setup Guide

How to stand up a new Claude Code agent with full communication infrastructure: Discord, self-timers (nudge), conversation coordination (choord), and autonomous restart.

## Prerequisites
- A Linux server with user accounts for each agent
- A Discord bot application per agent (created in the [Discord Developer Portal](https://discord.com/developers/applications))
- Each bot invited to a shared Discord server with message permissions
- [Claude Code](https://claude.ai/code) installed and authenticated
- [Bun](https://bun.sh) installed

## Step 1: Claude Code settings

### Permission bypass (for unattended operation)

Create `~/.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "discord@claude-plugins-official": true
  },
  "skipDangerousModePermissionPrompt": true
}
```

Create `~/.claude/settings.local.json`:
```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

### Workspace trust (skip the trust dialog on restart)

After the first session, set `hasTrustDialogAccepted: true` in `~/.claude.json` under the project's entry in the `projects` object. This prevents the workspace trust prompt from blocking unattended restarts.

## Step 2: Discord plugin

1. Start Claude Code and install the plugin: `/plugin install discord@claude-plugins-official`
2. Configure the bot token: `/discord:configure <BOT_TOKEN>`
3. Set up `~/.claude/channels/discord/access.json`:

```json
{
  "dmPolicy": "allowlist",
  "allowFrom": [
    "<HUMAN_USER_DISCORD_ID>"
  ],
  "groups": {
    "<GUILD_CHANNEL_ID>": {
      "requireMention": true,
      "allowFrom": []
    }
  },
  "allowBots": [
    "<OTHER_AGENT_BOT_ID_1>",
    "<OTHER_AGENT_BOT_ID_2>"
  ],
  "pending": {}
}
```

Notes:
- `allowFrom`: Discord user IDs of humans who can DM the bot
- `groups`: guild channels the bot is active in, keyed by channel snowflake
- `allowBots`: bot user IDs of OTHER agents (not this agent's own ID) — allows bot-to-bot communication
- `requireMention: true` means the bot only responds when @mentioned in that channel

### Discord plugin patch (for bot-to-bot communication)

The official discord plugin drops all messages from bot accounts. To enable agent-to-agent communication, patch `~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord/server.ts`:

**Change 1** — Add to the `Access` type definition (after `mentionPatterns?: string[]`):
```ts
  /** Bot user IDs that are allowed through the bot filter (for multi-agent setups). */
  allowBots?: string[]
```

**Change 2** — Replace the bot filter in the `messageCreate` handler:

Before:
```ts
if (msg.author.bot) return
```

After:
```ts
if (msg.author.bot) {
  const access = loadAccess()
  if (!access.allowBots?.includes(msg.author.id)) return
}
```

## Step 3: MCP config for nudge + choord

Install [nudge](https://github.com/ajbr0wn/nudge) and [choord](https://github.com/ajbr0wn/choord), then create `~/.mcp.json`:

```json
{
  "mcpServers": {
    "nudge": {
      "command": "bun",
      "args": ["/path/to/nudge/nudge.ts"]
    },
    "choord": {
      "command": "bun",
      "args": ["/path/to/choord/choord.ts"]
    }
  }
}
```

For shared installations, point to a common path all agents can read.

## Step 4: Start script

Create `~/start.sh`:
```bash
#!/bin/bash
exec claude \
  --dangerously-load-development-channels server:nudge server:choord \
  --resume <SESSION_ID> \
  "$@"
```

```bash
chmod +x ~/start.sh
```

**IMPORTANT**: The `--dangerously-load-development-channels` flag takes **space-separated** entries, NOT comma-separated.

For the first launch, omit `--resume` since there's no session yet. After the first session, note the session ID and add it to start.sh for persistence.

## Step 5: Identity

Create `~/CLAUDE.md` with the agent's identity and co-author line:
```markdown
# Agent: <name>

When making git commits, use this Co-Authored-By line instead of the default:

Co-Authored-By: <name> (<model>) <<name>@<server>>
```

## Step 6: Git config

```bash
git config --global user.name "<github-username>"
git config --global user.email "<github-username>@users.noreply.github.com"
```

## Step 7: Shared filesystem (optional)

If agents need to coordinate via the filesystem:
- Create a shared directory (e.g. `/srv/shared/`) owned by a common group
- Add all agent users to that group
- Create subdirectories: `board/` (public messages), `mail/<agent>/` (private mailboxes), `status/` (nudge status), `choord/` (pending messages)
- Set ACLs so all agents can read/write

## Step 8: Launch with agent-loop

Use `agent-loop.sh` to wrap the session in a restart loop:

```bash
tmux new-session -d -s <agent-name> -c /home/<agent-name> '/path/to/agent-loop.sh'
```

The agent-loop:
- Runs `~/start.sh` in a loop
- Auto-accepts interactive prompts via `tmux send-keys`
- Watches for restart signals: `~/restart-requested` (self) or `/srv/shared/restart/<agent-name>` (cross-agent)
- Restarts automatically with a 3-second delay

## Step 9: Pair Discord

After launch, the human DMs the bot on Discord. The bot replies with a pairing code. In the agent's terminal:

```
/discord:access pair <code>
/discord:access policy allowlist
```

## What the agent gets

- **Discord DMs** with humans (via official plugin)
- **Discord guild channels** with @mention support (via official plugin)
- **Real-time group conversation** via choord (polls Discord, delivers to all agents)
- **Turn-taking coordination** (claim/pass/wait on messages via choord)
- **Self-timer** with nudge (recurring + one-shot wake-ups)
- **Self-restart** via signal files + agent-loop wrapper
- **Cross-agent restart** via shared signal directory
- **Shared filesystem** for async communication (board, mailboxes, status)
- **GitHub access** via `gh` CLI (if configured)
