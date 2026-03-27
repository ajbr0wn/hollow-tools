#!/bin/bash
#
# agent-loop.sh — Restart wrapper for Claude Code agent sessions.
#
# Runs start.sh in a loop. Watches for restart signals from:
#   - ~/restart-requested (self-restart)
#   - /srv/shared/restart/$USER (cross-agent restart)
#
# Auto-accepts interactive prompts via tmux send-keys.
#
# Usage: agent-loop.sh
# Intended to be run inside tmux.
#

AGENT="$USER"
RESTART_SELF="$HOME/restart-requested"
RESTART_SHARED="/srv/shared/restart/$AGENT"
START_SCRIPT="$HOME/start.sh"

if [ ! -x "$START_SCRIPT" ]; then
  echo "Error: $START_SCRIPT not found or not executable"
  exit 1
fi

while true; do
  # Clean up any stale restart signals
  rm -f "$RESTART_SELF" "$RESTART_SHARED"

  echo "[agent-loop] Starting session for $AGENT at $(date)"

  # Background job 1: auto-accept interactive prompts via tmux
  (
    sleep 4
    tmux send-keys -t "$TMUX_PANE" Enter 2>/dev/null || tmux send-keys Enter 2>/dev/null
    sleep 3
    tmux send-keys -t "$TMUX_PANE" Enter 2>/dev/null || tmux send-keys Enter 2>/dev/null
    sleep 3
    tmux send-keys -t "$TMUX_PANE" Enter 2>/dev/null || tmux send-keys Enter 2>/dev/null
  ) &
  AUTO_PID=$!

  # Start claude in the foreground
  "$START_SCRIPT" &
  CLAUDE_PID=$!

  # Background job 2: watch for restart signals while claude is running
  (
    while kill -0 "$CLAUDE_PID" 2>/dev/null; do
      if [ -f "$RESTART_SELF" ] || [ -f "$RESTART_SHARED" ]; then
        echo "[agent-loop] Restart signal detected. Stopping session..."
        rm -f "$RESTART_SELF" "$RESTART_SHARED"
        kill "$CLAUDE_PID" 2>/dev/null
        exit 0
      fi
      sleep 2
    done
  ) &
  WATCH_PID=$!

  # Wait for claude to exit (either naturally or via signal)
  wait "$CLAUDE_PID" 2>/dev/null
  EXIT_CODE=$?

  # Clean up background jobs
  kill "$AUTO_PID" 2>/dev/null
  kill "$WATCH_PID" 2>/dev/null
  wait "$AUTO_PID" 2>/dev/null
  wait "$WATCH_PID" 2>/dev/null

  echo "[agent-loop] Session exited (code $EXIT_CODE). Restarting in 3 seconds..."
  sleep 3
done
