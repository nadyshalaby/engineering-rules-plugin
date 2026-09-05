#!/bin/bash
# Fixture tests for progress-notify.sh. Run: bash hooks/tests/progress-notify.test.sh
# osascript is shimmed on PATH so nothing pops and nothing runs; the shim records its argv so
# the test can prove the title and the body travel as arguments and never as AppleScript.
# PROGRESS_NOTIFY_SH points the test at another copy of the script, for a watched failure.
set -u
here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
SCRIPT="${PROGRESS_NOTIFY_SH:-$here/../progress-notify.sh}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/progress-notify-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/config"
cat > "$WORK/bin/osascript" <<'SHIM'
#!/bin/bash
printf '%s\n' "$@" >> "$OSASCRIPT_ARGV"
[ -z "${OSASCRIPT_FAIL:-}" ]
SHIM
chmod +x "$WORK/bin/osascript"
export PATH="$WORK/bin:$PATH" CLAUDE_CONFIG_DIR="$WORK/config" OSASCRIPT_ARGV="$WORK/osascript.argv"
LOG="$WORK/config/progress.log"
ARGV="$OSASCRIPT_ARGV"
SOURCE_LINE='display notification (item 1 of argv) with title (item 2 of argv)'
failures=0
count=0

run_hook() {
  printf '%s' "$1" | bash "$SCRIPT"
}

assert_eq() {
  count=$((count + 1))
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
    return
  fi
  printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  failures=$((failures + 1))
}

read_log_line() {
  sed -n "${1}p" "$LOG" | cut -d '|' -f 2-
}

count_log_lines() {
  if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else printf '0'; fi
}

test_stop_with_ledger() {
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"## 0. Phase ledger  (4 of 6, Phase 5)\n- [x] 1  Phase 1. Clarify\n- [>] 4  Phase 5. Review\n\nStage five landed, both scouts clean."}'
  assert_eq "stop with a ledger logs the position and the first prose line" " proj | stop | (4 of 6, Phase 5) | Stage five landed, both scouts clean." "$(read_log_line 1)"
  assert_eq "stop with a ledger notifies through argv, body then title" "$(printf '%s\n' "$SOURCE_LINE" '(4 of 6, Phase 5) — Stage five landed, both scouts clean.' 'Claude · proj')" "$(sed -n '4p;7p;8p' "$ARGV")"
}

test_stop_without_ledger() {
  before=$(wc -l < "$ARGV" | tr -d ' ')
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"Just a plain reply with no ledger in it."}'
  assert_eq "stop without a ledger logs the first line only" " proj | stop | Just a plain reply with no ledger in it." "$(read_log_line 2)"
  assert_eq "stop without a ledger sends no notification" "$before" "$(wc -l < "$ARGV" | tr -d ' ')"
}

test_notification_event() {
  run_hook '{"hook_event_name":"Notification","cwd":"/tmp/proj","notification_type":"permission_prompt","message":"Claude needs your permission to run git push"}'
  assert_eq "notification logs a waiting line" " proj | waiting | permission_prompt | Claude needs your permission to run git push" "$(read_log_line 3)"
  assert_eq "notification title names the project" "Claude needs you · proj" "$(tail -n 1 "$ARGV")"
}

test_quoted_directory_name() {
  run_hook '{"hook_event_name":"Notification","cwd":"/tmp/x\" & (do shell script \"id\") & \"","notification_type":"permission_prompt","message":"Claude needs permission"}'
  assert_eq "a quote in the directory name stays inside one argument" 'Claude needs you · x" & (do shell script "id") & "' "$(tail -n 1 "$ARGV")"
  assert_eq "no AppleScript source ever carries the directory name" "0" "$(grep -c 'display notification .*do shell script' "$ARGV")"
}

test_quoted_reply() {
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"## 0. Phase ledger  (1 of 6, Phase 1)\n\nSaid \"done\" and \\ moved on."}'
  assert_eq "a quote and a backslash in the reply reach the body intact" '(1 of 6, Phase 1) — Said "done" and \ moved on.' "$(tail -n 2 "$ARGV" | head -n 1)"
}

test_bad_input() {
  before=$(count_log_lines)
  err=$(printf 'not json at all' | bash "$SCRIPT" 2>&1); status=$?
  assert_eq "malformed stdin exits 0 with nothing on stderr" "0|" "$status|$err"
  printf '' | bash "$SCRIPT"; assert_eq "empty stdin exits 0" "0" "$?"
  run_hook '{"hook_event_name":"PreToolUse","cwd":"/tmp/proj"}'; assert_eq "an unhandled event exits 0" "0" "$?"
  assert_eq "none of them wrote a log line" "$before" "$(count_log_lines)"
}

test_jq_missing() {
  before=$(count_log_lines)
  printf '%s' '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"x"}' | env PATH="$WORK/bin" /bin/bash "$SCRIPT"
  assert_eq "jq missing: exit 0" "0" "$?"
  assert_eq "jq missing: no log line" "$before" "$(count_log_lines)"
}

test_notifier_failure() {
  printf '%s' '{"hook_event_name":"Notification","cwd":"/tmp/proj","notification_type":"idle_prompt","message":"waiting"}' | OSASCRIPT_FAIL=1 bash "$SCRIPT"
  assert_eq "a failing notifier is recorded on the log line" " proj | waiting | idle_prompt | waiting | notify-failed" "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
}

test_stop_with_ledger
test_stop_without_ledger
test_notification_event
test_quoted_directory_name
test_quoted_reply
test_bad_input
test_jq_missing
test_notifier_failure
printf '%s\n' "$((count - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
