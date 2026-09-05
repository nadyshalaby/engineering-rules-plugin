#!/bin/bash
# engineering-rules progress notifier.
# Runs on Stop (Claude finished a turn) and on Notification (Claude is waiting on you).
# Appends one line per event to the progress log, and raises a desktop notification when
# the turn ended on a phase-ledger re-print or when Claude is blocked on input.
# Every exit is 0: a notifier must never fail the hook that called it. A notifier that could
# not deliver says so on its own log line instead of failing silently.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./ledger-position.sh
. "$here/ledger-position.sh"

LOG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOG_FILE="$LOG_DIR/progress.log"
BODY_CHARS=200

# Title and body travel as arguments, never as AppleScript source, so a quote in a directory
# name or in a reply cannot end the string early or run as code. Returns the notifier's own
# status; no notifier on this machine is not a failure.
notify_desktop() {
  title="$1"
  body="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title (item 2 of argv)' -e 'end run' "$body" "$title" >/dev/null 2>&1
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -- "$title" "$body" >/dev/null 2>&1
  fi
}

append_log() {
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$project" "$1" >> "$LOG_FILE" 2>/dev/null
}

# First line of prose in the message: skips blank lines, headings, ledger rows and fences.
read_first_prose_line() {
  printf '%s\n' "$1" | grep -v -E '^[[:space:]]*($|#|-[[:space:]]*\[|```)' | head -n 1 | cut -c1-"$BODY_CHARS"
}

on_stop() {
  message=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')
  position=$(printf '%s\n' "$message" | read_ledger_position)
  summary=$(read_first_prose_line "$message")
  if [ -z "$position" ]; then
    append_log "stop | $summary"
    return
  fi
  outcome=""
  notify_desktop "Claude · $project" "$position — $summary" || outcome=" | notify-failed"
  append_log "stop | $position | $summary$outcome"
}

on_notification() {
  kind=$(printf '%s' "$input" | jq -r '.notification_type // "notification"')
  text=$(printf '%s' "$input" | jq -r '.message // .title // empty' | cut -c1-"$BODY_CHARS")
  outcome=""
  notify_desktop "Claude needs you · $project" "$text" || outcome=" | notify-failed"
  append_log "waiting | $kind | $text$outcome"
}

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
project="${cwd##*/}"
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
case "$event" in
  Stop) on_stop ;;
  Notification) on_notification ;;
esac
exit 0
