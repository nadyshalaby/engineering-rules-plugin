#!/bin/bash
# Shared by the notifier and the guards: the progress log every hook here appends to, one
# line per event, `time | project | what happened`. Back from a break, `tail` it.
LOG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOG_FILE="$LOG_DIR/progress.log"

# append_log <project> <text>: one line; a log that cannot be written never fails the hook.
append_log() {
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOG_FILE" 2>/dev/null
}
