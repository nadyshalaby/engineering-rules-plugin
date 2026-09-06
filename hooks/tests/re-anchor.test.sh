#!/bin/bash
# Fixture tests for re-anchor.sh. Run: bash hooks/tests/re-anchor.test.sh
# RE_ANCHOR_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh, progress-log.sh and ledger-position.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${RE_ANCHOR_SH:-$here/../re-anchor.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
T="$WORK/transcript.jsonl"

# start <how_started> <transcript path>: what the hook prints for that session start.
start() {
  jq -cn --arg h "$1" --arg t "$2" '{hook_event_name:"SessionStart",how_started:$h,cwd:"/tmp/proj",transcript_path:$t}' | bash "$SCRIPT"
}

# skill_path <output>: the path the first line tells Claude to read.
skill_path() {
  printf '%s\n' "$1" | head -n 1 | sed -E 's/.*step 7\): //'
}

test_compact_carries_the_last_position() {
  printf '%s\n' '{"type":"assistant","text":"## 0. Phase ledger  (2 of 6, Phase 3)\n- [>] 2"}' '{"type":"user","text":"more"}' '{"type":"assistant","text":"## 0. Phase ledger  (3 of 6, Phase 4)\n- [>] 3"}' > "$T"
  out=$(start compact "$T")
  assert_contains "names the event" "engineering-rules re-anchor (context was compacted)" "$out"
  assert_contains "cites the re-read rule" "read the always-on law from disk before the next step (SKILL.md 1.7, step 7)" "$out"
  assert_contains "carries the last position, not the first" "Last phase-ledger position printed before the loss: (3 of 6, Phase 4)" "$out"
  assert_missing "and not the earlier one" "(2 of 6, Phase 3)" "$out"
  path=$(skill_path "$out")
  if [ -f "$path" ]; then found=exists; else found="missing: $path"; fi
  assert_contains "the path it names is a real file" "exists" "$found"
  case "$path" in /*) shape=absolute ;; *) shape="relative: $path" ;; esac
  assert_contains "and an absolute one" "absolute" "$shape"
  assert_contains "is logged with the position" " proj | anchor | compact | (3 of 6, Phase 4)" "$(cat "$LOG")"
}

test_resume_without_a_position() {
  printf '%s\n' '{"type":"assistant","text":"no ledger here"}' > "$T"
  out=$(start resume "$T")
  assert_contains "names the event" "engineering-rules re-anchor (session resumed)" "$out"
  assert_contains "says no position was found" "No phase-ledger position was found in the transcript" "$out"
  assert_contains "is logged without a position" " proj | anchor | resume | no ledger position" "$(tail -n 1 "$LOG")"
  out=$(start compact "$WORK/not-there.jsonl")
  assert_contains "a missing transcript still re-anchors" "(context was compacted)" "$out"
  assert_contains "and says no position was found" "No phase-ledger position" "$out"
}

test_other_starts_and_bad_input_print_nothing() {
  assert_eq "a fresh start prints nothing" "" "$(start startup "$T")"
  assert_eq "a cleared session prints nothing" "" "$(start clear "$T")"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "re-anchor" "$out"
  out=$(jq -cn '{hook_event_name:"Stop",cwd:"/tmp/proj"}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
}

test_source_field_and_plugin_root() {
  out=$(jq -cn --arg t "$T" '{hook_event_name:"SessionStart",source:"resume",cwd:"/tmp/proj",transcript_path:$t}' | bash "$SCRIPT")
  assert_contains "the older source field still starts it" "(session resumed)" "$out"
  out=$(jq -cn --arg t "$T" '{hook_event_name:"SessionStart",how_started:"compact",cwd:"/tmp/proj",transcript_path:$t}' | CLAUDE_PLUGIN_ROOT=/opt/plugins/er bash "$SCRIPT")
  assert_contains "the plugin root decides the path" "/opt/plugins/er/skills/engineering-rules/SKILL.md" "$out"
}

test_compact_carries_the_last_position
test_resume_without_a_position
test_other_starts_and_bad_input_print_nothing
test_source_field_and_plugin_root
report
