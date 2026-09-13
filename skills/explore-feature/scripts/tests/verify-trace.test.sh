#!/bin/bash
# Fixture tests for verify-trace.sh: the sample trace passes, one mutation per check is
# refused with its own line and nothing written, excerpts are copied from disk, and an
# uncommitted change to a cited file is named.
# Run: bash skills/explore-feature/scripts/tests/verify-trace.test.sh
# VERIFY_TRACE_SH points the test at another copy of the script, for a watched failure; the
# copy needs verify-trace.jq beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${VERIFY_TRACE_SH:-$here/../verify-trace.sh}"
# shellcheck source=fixtures/sample-repo.fixture.sh
. "$here/fixtures/sample-repo.fixture.sh"
build_sample_repo "$WORK/repo"
write_sample_trace "$WORK/repo" "$WORK/trace.json"

# verify <trace> <excerpts>: both streams, then "exit N".
verify() { bash "$SCRIPT" "$1" "$2" 2>&1; printf 'exit %s\n' "$?"; }

# refused <name> <jq mutation> <expected line>: the mutated trace is refused with that line
# and no excerpts file appears.
refused() {
  jq "$2" "$WORK/trace.json" > "$WORK/mut.json"
  rm -f "$WORK/mut-ex.json"
  out=$(verify "$WORK/mut.json" "$WORK/mut-ex.json")
  assert_contains "$1: names the problem" "$3" "$out"
  assert_contains "$1: exits 1" "exit 1" "$out"
  assert_eq "$1: writes nothing" absent "$([ -f "$WORK/mut-ex.json" ] && echo present || echo absent)"
}

test_the_sample_trace_passes() {
  out=$(verify "$WORK/trace.json" "$WORK/excerpts.json")
  assert_contains "sample trace: the verified line" "verified 8 hops across 8 files; wrote $WORK/excerpts.json" "$out"
  assert_contains "sample trace: exit 0" "exit 0" "$out"
  assert_eq "sample trace: one excerpt per hop" 8 "$(jq '.excerpts | length' "$WORK/excerpts.json")"
  assert_eq "sample trace: the repository is the root and clean" '[{"path":".","dirty":[]}]' "$(jq -c '[.repos[] | {path, dirty}]' "$WORK/excerpts.json")"
  assert_eq "sample trace: a short commit is named" 7 "$(jq -r '.repos[0].commit | length' "$WORK/excerpts.json")"
}

test_excerpt_lines_are_copied_from_disk() {
  want=$(sed -n '8,16p' "$WORK/repo/src/orders/services/orders.service.ts")
  got=$(jq -r '.excerpts[] | select(.id == "h4") | .lines[]' "$WORK/excerpts.json")
  assert_eq "excerpt h4 is lines 8 to 16 of the service, byte for byte" "$want" "$got"
}

test_the_default_output_lands_beside_the_trace() {
  mkdir -p "$WORK/beside" && cp "$WORK/trace.json" "$WORK/beside/trace.json"
  out=$(bash "$SCRIPT" "$WORK/beside/trace.json" 2>&1)
  assert_contains "default output path" "wrote $WORK/beside/excerpts.json" "$out"
}

test_bad_files_are_refused() {
  printf '{' > "$WORK/broken.json"
  assert_contains "broken json is named" "is not valid JSON" "$(verify "$WORK/broken.json" "$WORK/broken-ex.json")"
  assert_contains "a missing trace is named" "trace: file does not exist" "$(verify "$WORK/nope.json" "$WORK/nope-ex.json")"
  assert_contains "no argument prints the usage" "usage: verify-trace.sh" "$(bash "$SCRIPT" 2>&1)"
}

test_every_check_refuses_its_mutation() {
  seq -f 'line %g' 1 250 > "$WORK/repo/src/big.ts"
  refused "version 1" '.version = 1' "trace: version must be 2"
  refused "root missing" '.root = "/nonexistent/dir"' "trace: root is not a directory"
  refused "41 hops" '.hops += [range(33) | {id: "x\(.)", title: "t", file: "src/orders/orders.routes.ts", symbol: "s", line: 7, evidence: "ordersRoutes", range: [5, 7], kind: "call", from: "h0", call: {file: "src/orders/orders.routes.ts", line: 7, evidence: "ordersRoutes"}, why: "w", invoked: [7], returns: "", throws: [], status: "verified", author_says: ""}]' "trace: hops must have 1 to 40 entries, has 41"
  refused "entry hop with a call" '.hops[0].call = {file: "src/orders/orders.routes.ts", line: 7, evidence: "post"}' "hop h0: call must be null on the entry hop"
  refused "from is not earlier" 'del(.hops[1]) | .hops[1].from = "h1"' "hop h2: from h1 is not an earlier hop"
  refused "title over the cap" '.title = "A title that runs on well past the forty character cap"' "trace: title is over 40 characters"
  refused "hop title over the cap" '.hops[0].title = "A hop title that keeps going and going and going past sixty characters"' "hop h0: title is over 60 characters"
  refused "entry kind off the enum" '.entry.kind = "webhook"' "trace: entry.kind webhook is not one of http, cli, job, ui, event, other"
  refused "hop kind off the enum" '.hops[3].kind = "schema"' "hop h3: kind schema is not one of"
  refused "unresolved with no reason" '.hops[7].reason = ""' "hop h7: an unresolved hop needs a reason"
  refused "unresolved with no candidates" '.hops[7].candidates = []' "hop h7: an unresolved hop needs at least one candidate"
  refused "file outside the root" '.hops[1].file = "../outside.ts" | .files[1].path = "../outside.ts"' "hop h1: file must be a relative path inside root"
  refused "file that does not exist" '.hops[1].file = "src/gone.ts" | .files[1].path = "src/gone.ts"' "hop h1: file does not exist under root: src/gone.ts"
  refused "line past the end of the file" '.hops[0].line = 99 | .hops[0].range = [5, 99] | .hops[0].invoked = [5, 7, 99]' "hop h0: line 99 is outside src/orders/orders.routes.ts (7 lines)"
  refused "evidence typed from memory" '.hops[2].evidence = "export function createOrder"' "hop h2: evidence not found on src/orders/controllers/orders.controller.ts:6"
  refused "range not around the line" '.hops[1].range = [5, 11]' "hop h1: range 5-11 does not contain line 4"
  refused "excerpt over the cap" '.hops[6].file = "src/big.ts" | .hops[6].line = 1 | .hops[6].evidence = "line 1" | .hops[6].range = [1, 201] | .hops[6].invoked = [] | (.files[] | select(.path == "src/platform/email/email.service.ts") | .path) = "src/big.ts"' "hop h6: excerpt is 201 lines, the cap is 200"
  refused "call line outside the parent excerpt" '.hops[2].range = [6, 7]' "hop h4: call line 8 is outside the parent hop h2's range 6-7"
  refused "call site in the wrong file" '.hops[4].call = {file: "src/orders/orders.routes.ts", line: 7, evidence: "createOrder"}' "hop h4: call site is in src/orders/orders.routes.ts but the parent hop h2 is a frame in src/orders/controllers/orders.controller.ts"
  refused "invoked outside the range" '.hops[0].range = [1, 7] | .hops[0].invoked = [5, 7, 9]' "hop h0: invoked line 9 is outside the range 1-7"
  refused "file listed, cited by no hop" '.files += [{path: "src/x.ts", layer: "lib", role: ""}]' "trace: files entry src/x.ts is cited by no hop"
  refused "hop file not listed" 'del(.files[7])' "trace: hop file src/platform/notify/notify.ts is not listed in files"
  refused "dangling step" '.pseudocode[0].hops = ["h9"]' "trace: pseudocode step 1 points at unknown hop h9"
  refused "dangling branch" '.branches[0].at = "h9"' "trace: branch no session is at unknown hop h9"
  refused "too many steps" '.pseudocode = [range(13) | {step: (. + 1), text: "s", hops: ["h0"]}]' "trace: pseudocode must have 1 to 12 steps, has 13"
  refused "too few questions" '.questions = .questions[:2]' "trace: questions must have 3 to 5 entries, has 2"
  refused "candidate typed from memory" '.hops[7].candidates[0].evidence = "order: pushToTeams"' "hop h7 candidate 1: evidence not found on src/platform/notify/handlers.ts:4"
  refused "invoked without the frame line" '.hops[4].invoked = [9, 10, 13, 14, 15, 16]' "hop h4: invoked leaves out the frame line 8"
  refused "call line missing from the parent's invoked" '.hops[2].invoked = [6, 7, 9, 10]' "hop h4: call line 8 is not in the parent hop h2's invoked lines"
  refused "invoked blank line" '.hops[0].invoked = [5, 6, 7]' "hop h0: invoked line 6 is blank"
  printf '// a note\nexport const x = 1\n' > "$WORK/repo/src/note.ts"
  refused "invoked comment line" '.hops[7].file = "src/note.ts" | .hops[7].line = 2 | .hops[7].evidence = "export const x" | .hops[7].range = [1, 2] | .hops[7].invoked = [1, 2] | (.files[] | select(.path == "src/platform/notify/notify.ts") | .path) = "src/note.ts"' "hop h7: invoked line 1 is a comment"
}

test_a_trace_that_dims_nothing_passes_with_a_note() {
  jq 'del(.hops[].invoked)' "$WORK/trace.json" > "$WORK/flat.json"
  out=$(verify "$WORK/flat.json" "$WORK/flat-ex.json")
  assert_contains "no invoked anywhere: still verified" "verified 8 hops across 8 files" "$out"
  assert_contains "no invoked anywhere: the note" "note: no hop carries invoked, so the page dims nothing" "$out"
  assert_missing "one hop with invoked: no note" "note: no hop carries invoked" "$(verify "$WORK/trace.json" "$WORK/noted-ex.json")"
}

test_dirty_files_are_reported() {
  printf '\n' >> "$WORK/repo/src/orders/orders.routes.ts"
  bash "$SCRIPT" "$WORK/trace.json" "$WORK/dirty-ex.json" >/dev/null 2>&1
  assert_eq "an uncommitted change to a cited file is named" '["src/orders/orders.routes.ts"]' "$(jq -c '.repos[0].dirty' "$WORK/dirty-ex.json")"
}

test_an_unwritable_output_is_refused() {
  out=$(verify "$WORK/trace.json" "$WORK/missing-dir/excerpts.json")
  assert_contains "unwritable output: names the problem" "trace: could not write $WORK/missing-dir/excerpts.json" "$out"
  assert_contains "unwritable output: exits 1" "exit 1" "$out"
  assert_missing "unwritable output: no verified line" "verified 8 hops" "$out"
}

test_the_sample_trace_passes
test_excerpt_lines_are_copied_from_disk
test_the_default_output_lands_beside_the_trace
test_bad_files_are_refused
test_every_check_refuses_its_mutation
test_a_trace_that_dims_nothing_passes_with_a_note
test_dirty_files_are_reported
test_an_unwritable_output_is_refused
report
