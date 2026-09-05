#!/bin/bash
# Fixture tests for statusline.sh. Run: bash hooks/tests/statusline.test.sh
# STATUSLINE_SH points the test at another copy of the script, for a watched failure.
set -u
here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
SCRIPT="${STATUSLINE_SH:-$here/../statusline.sh}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK"
T="$WORK/transcript.jsonl"
PROJECT=${WORK##*/}
failures=0
count=0

render() {
  printf '%s' "$1" | bash "$SCRIPT" | sed $'s/\e\\[[0-9;]*m//g'
}

build_status_json() {
  printf '{"cwd":"%s","transcript_path":"%s","model":{"display_name":"Fable 5.1"},"context_window":{"used_percentage":%s}}' "$WORK" "$T" "$1"
}

assert_contains() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'ok   %s\n' "$1"; return ;;
  esac
  printf 'FAIL %s\n  wanted: %s\n  in:     %s\n' "$1" "$2" "$3"
  failures=$((failures + 1))
}

assert_missing() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'FAIL %s\n  did not want: %s\n  in:           %s\n' "$1" "$2" "$3"; failures=$((failures + 1)); return ;;
  esac
  printf 'ok   %s\n' "$1"
}

test_bare_render() {
  line=$(render "{\"cwd\":\"$WORK\"}")
  assert_contains "renders the directory with nothing else available" "➜ $PROJECT" "$line"
  assert_missing "no transcript means no ledger segment" "Phase" "$line"
}

test_context_bar() {
  line=$(render "$(build_status_json 42)")
  assert_contains "context bar at 42%" "━━━━╌╌╌╌╌╌ 42%" "$line"
  assert_contains "model name" "Fable 5.1" "$line"
  line=$(render "$(build_status_json 100)")
  assert_contains "context bar at 100% is full and never negative" "━━━━━━━━━━ 100%" "$line"
}

test_ledger_position() {
  printf '%s\n' '{"timestamp":"2026-09-05T00:00:00.000Z"}' '{"type":"assistant","text":"## 0. Phase ledger  (2 of 6, Phase 3)\n- [>] 2"}' > "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "first heading is found" "(2 of 6, Phase 3)" "$line"
  assert_contains "uptime is shown" "up " "$line"
  printf '%s\n' '{"type":"assistant","text":"## 0. Phase ledger  (4 of 6, Phase 5)\n- [>] 4"}' >> "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "a heading appended after the first render is picked up" "(4 of 6, Phase 5)" "$line"
  line=$(render "$(build_status_json 10)")
  assert_contains "an unchanged transcript keeps the position" "(4 of 6, Phase 5)" "$line"
  printf '%s\n' '{"type":"user","text":"nothing new"}' >> "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "new bytes without a heading keep the position" "(4 of 6, Phase 5)" "$line"
}

test_replaced_transcript() {
  printf '%s\n' '{"timestamp":"2026-09-05T01:00:00.000Z"}' '{"type":"assistant","text":"## 0. Phase ledger  (1 of 6, Phase 1)"}' > "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "a transcript that shrank resets the cursor" "(1 of 6, Phase 1)" "$line"
  assert_missing "and forgets the old position" "(4 of 6, Phase 5)" "$line"
}

test_malformed_input() {
  line=$(printf 'not json' | bash "$SCRIPT" | sed $'s/\e\\[[0-9;]*m//g'; printf 'exit=%s' "${PIPESTATUS[1]}")
  assert_contains "malformed stdin still renders and exits 0" "➜ " "$line"
  assert_contains "malformed stdin exit code" "exit=0" "$line"
}

test_bare_render
test_context_bar
test_ledger_position
test_replaced_transcript
test_malformed_input
printf '%s\n' "$((count - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
