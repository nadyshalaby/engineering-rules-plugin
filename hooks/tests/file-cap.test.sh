#!/bin/bash
# Fixture tests for file-cap.sh. Run: bash hooks/tests/file-cap.test.sh
# FILE_CAP_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh, progress-log.sh and path-kind.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${FILE_CAP_SH:-$here/../file-cap.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"

# after_write <tool> <path>: what the hook prints once that tool wrote the file.
after_write() {
  jq -cn --arg t "$1" --arg p "$2" --arg c "$WORK" '{hook_event_name:"PostToolUse",tool_name:$t,cwd:$c,tool_input:{file_path:$p},tool_response:{}}' | bash "$SCRIPT"
}

test_over_the_cap_is_reported() {
  seq 1 501 > "$WORK/big.ts"
  out=$(after_write Write "$WORK/big.ts")
  assert_contains "names the file and the count" "cap.file-lines $WORK/big.ts: 501 lines" "$out"
  assert_contains "cites the law" "SKILL.md 1.1 caps a file at 500 lines" "$out"
  assert_contains "is PostToolUse context" '"hookEventName":"PostToolUse"' "$out"
  assert_missing "never a permission decision" "permissionDecision" "$out"
  assert_contains "is logged" " ${WORK##*/} | cap | file-lines | $WORK/big.ts | 501 lines" "$(cat "$LOG" 2>/dev/null)"
  seq 1 501 > "$WORK/big.test.ts"
  assert_contains "a test file is counted too, the cap binds every code file" "501 lines" "$(after_write Edit "$WORK/big.test.ts")"
}

test_at_or_under_the_cap_is_silent() {
  seq 1 500 > "$WORK/at-cap.ts"
  assert_eq "a file exactly at the cap prints nothing" "" "$(after_write Edit "$WORK/at-cap.ts")"
  printf 'x\n' > "$WORK/tiny.ts"
  assert_eq "a small file prints nothing" "" "$(after_write MultiEdit "$WORK/tiny.ts")"
}

test_prose_and_generated_are_not_counted() {
  seq 1 600 > "$WORK/big.md"
  assert_eq "markdown is not code" "" "$(after_write Write "$WORK/big.md")"
  mkdir -p "$WORK/dist" && seq 1 600 > "$WORK/dist/bundle.js"
  assert_eq "a build output is not counted" "" "$(after_write Write "$WORK/dist/bundle.js")"
}

# The cap judges the path as the project knows it, as the edit guard does, so a project that
# lives under a directory called docs/ or build/ is still counted.
test_a_project_under_a_docs_directory_is_still_counted() {
  mkdir -p "$WORK/docs/proj/src" && seq 1 501 > "$WORK/docs/proj/src/big.ts"
  out=$(jq -cn --arg p "$WORK/docs/proj/src/big.ts" --arg c "$WORK/docs/proj" '{hook_event_name:"PostToolUse",tool_name:"Write",cwd:$c,tool_input:{file_path:$p},tool_response:{}}' | bash "$SCRIPT")
  assert_contains "the path is judged relative to the project" "cap.file-lines $WORK/docs/proj/src/big.ts: 501 lines" "$out"
}

test_nothing_to_count_prints_nothing() {
  assert_eq "a file that is not there" "" "$(after_write Write "$WORK/missing.ts")"
  out=$(jq -cn --arg p "$WORK/big.ts" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:"/tmp/proj",tool_input:{file_path:$p}}' | bash "$SCRIPT")
  assert_eq "another tool's event" "" "$out"
  out=$(jq -cn --arg p "$WORK/big.ts" '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:"/tmp/proj",tool_input:{file_path:$p}}' | bash "$SCRIPT")
  assert_eq "a PreToolUse event" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints no context" "hookSpecificOutput" "$out"
}

test_over_the_cap_is_reported
test_at_or_under_the_cap_is_silent
test_prose_and_generated_are_not_counted
test_a_project_under_a_docs_directory_is_still_counted
test_nothing_to_count_prints_nothing
report
