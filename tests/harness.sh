#!/bin/bash
# Shared by the tests beside it: strict mode, the repo root, a scratch dir removed on exit, the
# pass and fail counters, the two assertions and the closing report line. Source it first:
#   . "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
set -u
WORK=$(mktemp -d "${TMPDIR:-/tmp}/$(basename "${BASH_SOURCE[1]:-plugin-test}" .sh).XXXXXX")
trap 'rm -rf "$WORK"' EXIT
failures=0
count=0

# repo_root: the repository this harness lives in, whatever directory the test was run from.
repo_root() { git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel; }

# assert_contains <name> <needle> <haystack>: the needle is a fixed string, never a pattern.
assert_contains() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'ok   %s\n' "$1"; return ;;
  esac
  printf 'FAIL %s\n  wanted: %s\n  in:     %s\n' "$1" "$2" "$3"
  failures=$((failures + 1))
}

# assert_missing <name> <needle> <haystack>
assert_missing() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'FAIL %s\n  did not want: %s\n  in:           %s\n' "$1" "$2" "$3"; failures=$((failures + 1)); return ;;
  esac
  printf 'ok   %s\n' "$1"
}

# report: the closing line every test prints, and its exit status.
report() {
  printf '%s\n' "$((count - failures)) passed, $failures failed"
  [ "$failures" -eq 0 ]
}
