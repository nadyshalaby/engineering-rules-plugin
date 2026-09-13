#!/bin/bash
# Fixture tests for capture-run.sh: over a small Bun project and its Node twin, test mode
# records every call, branch and throw with the email masked and the repo untouched, Bun and
# Node record the same, the bun test runner flushes through afterAll and the override can
# silence it, a command that reaches no anchor and a value the masks miss are refused with
# nothing left behind, and live mode captures a real request and stops on --stop. Needs bun,
# node, jq and curl on PATH; prints a skip line and passes vacuously without them, since the
# runner cannot run either. Run: bash skills/explore-feature/scripts/tests/capture-run.test.sh
# CAPTURE_RUN_SH points the test at another copy of the script, for a watched failure; the
# copy needs the two jq files, secret-scan.sh and ../capture beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../../tests/harness.sh"
# The runner prints the trace directory as cd sees it; a TMPDIR ending in a slash would
# otherwise leave a double slash in the expected lines.
WORK=$(cd "$WORK" && pwd)
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${CAPTURE_RUN_SH:-$here/../capture-run.sh}"
# The runner is called from inside the fixture repos, so its path has to survive a cd.
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
# shellcheck source=fixtures/capture-bun.fixture.sh
. "$here/fixtures/capture-bun.fixture.sh"
# shellcheck source=fixtures/capture-node.fixture.sh
. "$here/fixtures/capture-node.fixture.sh"
BUN="$WORK/bun"; TD="$WORK/bun-trace"; T="$TD/trace.json"
NODE="$WORK/node"; TND="$WORK/node-trace"; TN="$TND/trace.json"

# run <repo> <args>...: the runner from inside the fixture repo, both streams, then "exit N".
run() { (cd "$1" && bash "$SCRIPT" "${@:2}" 2>&1); printf 'exit %s\n' "$?"; }
# field <capture.json> <jq filter>: one value out of a capture, compact.
field() { jq -c "$2" "$1"; }
# untouched <repo>: what git sees changed in a fixture repo; empty is the claim.
untouched() { git -C "$1" status --porcelain; }
# present <file>...: "present" or "absent" per file, on one line.
present() { for f in "$@"; do [ -f "$f" ] && printf 'present ' || printf 'absent '; done; }

missing_tools() { for tool in bun node jq curl; do command -v "$tool" >/dev/null 2>&1 || printf '%s ' "$tool"; done; }

test_usage_and_missing_inputs() {
  out=$(run "$BUN")
  assert_contains "no argument prints the usage" "usage: capture-run.sh" "$out"
  assert_contains "no argument exits 2" "exit 2" "$out"
  assert_contains "a bare --stop prints the usage" "usage: capture-run.sh" "$(run "$BUN" --stop)"
  assert_contains "an unknown mode prints the usage" "usage: capture-run.sh" "$(run "$BUN" "$T" --dry x)"
  out=$(run "$BUN" "$WORK/nowhere.json" --test bun main.ts)
  assert_contains "a missing trace is named" "trace file does not exist" "$out"
  assert_contains "a missing trace exits 1" "exit 1" "$out"
}

test_bun_test_mode_records_calls_branches_and_a_throw() {
  out=$(run "$BUN" "$T" --test bun main.ts)
  assert_contains "bun: the program's output is untouched" "hi nady x2 hi x@y.io 4 2" "$out"
  assert_contains "bun: the wrote line" "wrote $TD/capture.json: 3 anchors, 5 calls, 2 branches, 1 threw, exit 0" "$out"
  assert_contains "bun: exit 0" "exit 0" "$out"
  c="$TD/capture.json"
  assert_eq "bun: anchors in source order" '["greet","check","arrow"]' "$(field "$c" '[.anchors[].name]')"
  assert_eq "bun: the email is masked in the argument and the value" '[["<email>",{"n":1}],"hi <email>"]' "$(field "$c" '[.anchors[0].calls[1].in, .anchors[0].calls[1].out]')"
  assert_eq "bun: an async function is recorded at its return, with the resolved value" '["hi nady x2",null]' "$(field "$c" '[.anchors[0].calls[0].out, .anchors[0].calls[0].async]')"
  assert_eq "bun: a promise handed back is recorded when it settles" '[2,true]' "$(field "$c" '[.anchors[2].calls[0].out, .anchors[2].calls[0].async]')"
  assert_eq "bun: the throw is recorded" '{"error":"RangeError","message":"negative"}' "$(field "$c" '.anchors[1].calls[1].threw')"
  assert_eq "bun: greet went both ways" '[2,[true,false]]' "$(field "$c" '[.anchors[0].branches[0].line, .anchors[0].branches[0].outcomes]')"
  assert_eq "bun: check went false, then true" '[6,[false,true]]' "$(field "$c" '[.anchors[1].branches[0].line, .anchors[1].branches[0].outcomes]')"
  assert_eq "bun: the run record" '["test","bun","bun main.ts",0]' "$(field "$c" '[.run.mode, .run.runtime, .run.command, .run.exit]')"
  assert_eq "bun: the repo is untouched" "" "$(untouched "$BUN")"
  cp "$c" "$WORK/bun-main.json"
}

test_node_test_mode_records_the_same() {
  out=$(run "$NODE" "$TN" --test node main.ts)
  assert_contains "node: the program's output is untouched" "hi nady x2 hi x@y.io 4 2" "$out"
  assert_contains "node: the wrote line" "wrote $TND/capture.json: 3 anchors, 5 calls, 2 branches, 1 threw, exit 0" "$out"
  assert_eq "node: the runtime is node" '"node"' "$(field "$TND/capture.json" '.run.runtime')"
  shape='[.anchors[] | { name, calls: [.calls[] | { in, out, threw, async }], branches: [.branches[] | { line, outcomes }] }]'
  assert_eq "node and bun record the same calls, values, throws and branches" "$(field "$WORK/bun-main.json" "$shape")" "$(field "$TND/capture.json" "$shape")"
  assert_eq "node: the repo is untouched" "" "$(untouched "$NODE")"
}

test_the_bun_test_runner_flushes_and_the_override_silences_it() {
  out=$(run "$BUN" "$T" --test bun test lib.test.ts)
  assert_contains "bun test: the test passes" " 1 pass" "$out"
  assert_contains "bun test: the wrote line" "wrote $TD/capture.json: 3 anchors, 1 calls, 1 branches, 0 threw, exit 0" "$out"
  out=$(run "$BUN" "$T" --test bun run t)
  assert_contains "package script: the child bun test is captured" "1 calls, 1 branches, 0 threw, exit 0" "$out"
  rm -f "$TD/capture.json"
  out=$(EXPLORE_CAPTURE_BUN_TEST=0 run "$BUN" "$T" --test bun test lib.test.ts)
  assert_contains "override 0: nothing is flushed" "no event was recorded" "$out"
  assert_contains "override 0: exit 1" "exit 1" "$out"
  assert_eq "override 0: no capture.json" "absent " "$(present "$TD/capture.json")"
}

test_a_command_that_reaches_no_anchor_is_refused() {
  rm -f "$TD/capture.json"
  out=$(run "$BUN" "$T" --test bun -e "console.log(1)")
  assert_contains "no anchor: named" "no event was recorded: the command did not run any traced function" "$out"
  assert_contains "no anchor: exit 1" "exit 1" "$out"
  assert_eq "no anchor: no capture.json" "absent " "$(present "$TD/capture.json")"
}

test_a_value_the_masks_miss_is_refused_and_deleted() {
  rm -f "$TD/capture.json"
  out=$(run "$BUN" "$T" --test bun leak.ts)
  assert_contains "leak: the program ran" "hi AKIA" "$out"
  assert_contains "leak: refused with the line" "the aggregate carried a hardcoded secret at its line" "$out"
  assert_contains "leak: exit 1" "exit 1" "$out"
  assert_eq "leak: the aggregate and the events are gone" "absent absent " "$(present "$TD/capture.json" "$TD/capture.jsonl")"
  assert_eq "leak: the repo is untouched" "" "$(untouched "$BUN")"
}

test_live_mode_captures_a_request_and_stops() {
  rm -f "$TD/capture.json" "$WORK/port"
  out=$(PORT_FILE="$WORK/port" run "$BUN" "$T" --live bun server.ts)
  assert_contains "live: started" "started pid" "$out"
  assert_contains "live: says how to stop" "capture-run.sh --stop $TD" "$out"
  for _ in $(seq 1 50); do [ -s "$WORK/port" ] && break; sleep 0.2; done
  port=$(cat "$WORK/port" 2>/dev/null)
  assert_eq "live: the app answers under the capture" "hi nady" "$(curl -s "http://127.0.0.1:$port/?name=nady")"
  assert_eq "live: a second request" "hi x@y.io" "$(curl -s "http://127.0.0.1:$port/?name=x@y.io")"
  out=$(run "$BUN" --stop "$TD")
  assert_contains "stop: the wrote line" "wrote $TD/capture.json: 3 anchors, 2 calls, 1 branches, 0 threw, stopped" "$out"
  assert_eq "stop: the email is masked in the argument and the value" '[["nady","hi nady"],["<email>","hi <email>"]]' "$(field "$TD/capture.json" '[.anchors[0].calls[] | [.in[0], .out]]')"
  assert_eq "stop: a stopped run has no exit code" "null" "$(field "$TD/capture.json" '.run.exit')"
  assert_eq "stop: the pid file is gone" "absent " "$(present "$TD/capture.pid")"
  assert_contains "stop twice: refused" "no capture.pid in $TD" "$(run "$BUN" --stop "$TD")"
  printf 'abc\n' > "$TD/capture.pid"
  assert_contains "stop with a pid file holding no pid: refused" "does not hold a pid" "$(run "$BUN" --stop "$TD")"
  printf '1\n' > "$TD/capture.pid"
  assert_contains "stop with pid 1: refused before any signal" "which no capture started" "$(run "$BUN" --stop "$TD")"
  rm -f "$TD/capture.pid"
  assert_eq "live: the repo is untouched" "" "$(untouched "$BUN")"
}

missing=$(missing_tools)
if [ -n "$missing" ]; then
  printf 'skip capture-run: %snot on PATH\n' "$missing"
  report
  exit
fi
build_capture_bun_repo "$BUN" || { printf 'FAIL the bun fixture could not be built\n1 passed, 1 failed\n'; exit 1; }
build_capture_node_repo "$NODE" || { printf 'FAIL the node fixture could not be built\n1 passed, 1 failed\n'; exit 1; }
write_capture_trace "$BUN" "$T"
write_capture_trace "$NODE" "$TN"
test_usage_and_missing_inputs
test_bun_test_mode_records_calls_branches_and_a_throw
test_node_test_mode_records_the_same
test_the_bun_test_runner_flushes_and_the_override_silences_it
test_a_command_that_reaches_no_anchor_is_refused
test_a_value_the_masks_miss_is_refused_and_deleted
test_live_mode_captures_a_request_and_stops
report
