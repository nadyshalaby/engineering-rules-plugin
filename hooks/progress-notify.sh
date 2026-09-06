#!/bin/bash
# engineering-rules progress notifier.
# Runs on Stop (Claude finished a turn), on Notification (Claude is waiting on you), on
# StopFailure (the turn died on an API error) and on SubagentStart and SubagentStop (a helper
# was sent, or came back). Appends one line per event to the progress log, and raises a
# desktop notification when the turn ended on a phase-ledger re-print, when Claude is blocked
# on input, and when a turn died on an error.
# Every exit is 0: a notifier must never fail the hook that called it. A notifier that could
# not deliver says so on its own log line instead of failing silently.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./ledger-position.sh
. "$here/ledger-position.sh"

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

# First line of prose in the message: skips blank lines, headings, ledger rows and fences.
read_first_prose_line() {
  printf '%s\n' "$1" | grep -v -E '^[[:space:]]*($|#|-[[:space:]]*\[|```)' | head -n 1 | cut -c1-"$BODY_CHARS"
}

on_stop() {
  message=$(hook_field '.last_assistant_message // empty')
  position=$(printf '%s\n' "$message" | read_ledger_position)
  summary=$(read_first_prose_line "$message")
  if [ -z "$position" ]; then
    append_log "$project" "stop | $summary"
    return
  fi
  outcome=""
  notify_desktop "Claude · $project" "$position — $summary" || outcome=" | notify-failed"
  append_log "$project" "stop | $position | $summary$outcome"
}

on_notification() {
  kind=$(hook_field '.notification_type // "notification"')
  text=$(hook_field '.message // .title // empty' | cut -c1-"$BODY_CHARS")
  outcome=""
  notify_desktop "Claude needs you · $project" "$text" || outcome=" | notify-failed"
  append_log "$project" "waiting | $kind | $text$outcome"
}

on_stop_failure() {
  kind=$(hook_field '.error_type // "unknown"')
  text=$(hook_field '.error_message // empty' | cut -c1-"$BODY_CHARS")
  outcome=""
  notify_desktop "Claude stopped on an error · $project" "$kind: $text" || outcome=" | notify-failed"
  append_log "$project" "error | $kind | $text$outcome"
}

on_subagent_start() {
  agent=$(hook_field '.agent_type // "agent"')
  text=$(hook_field '.task_description // empty' | cut -c1-"$BODY_CHARS")
  append_log "$project" "helper | start | $agent | $text"
}

on_subagent_stop() {
  agent=$(hook_field '.agent_type // "agent"')
  text=$(read_first_prose_line "$(hook_field '.last_assistant_message // empty')")
  append_log "$project" "helper | stop | $agent | $text"
}

read_hook_input || exit 0
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
event=$(hook_field '.hook_event_name // empty')
case "$event" in
  Stop) on_stop ;;
  Notification) on_notification ;;
  StopFailure) on_stop_failure ;;
  SubagentStart) on_subagent_start ;;
  SubagentStop) on_subagent_stop ;;
esac
exit 0
