#!/bin/bash
# Guard: no raw control byte in any tracked file. A NUL, a backspace or an escape byte inside
# a reference is an escape sequence that lost its backslash on the way in, and a shell
# snippet carrying one fails silently. Run: bash tests/no-control-bytes.test.sh
# Needs git and perl. Tab, newline and carriage return are the only control bytes allowed.
set -u
set -o pipefail
here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
cd "$(git -C "$here" rev-parse --show-toplevel)" || exit 1
command -v perl >/dev/null || { printf 'FAIL perl not found, nothing was scanned\n'; exit 1; }
failures=0
count=0

# Runs once over every tracked file and prints "path<TAB>line" for each offending line;
# a file perl cannot open is a scan failure, never a pass.
read -r -d '' FIND_CONTROL_BYTES <<'PERL'
print "$ARGV\t$.\n" if /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;
close ARGV if eof;
PERL

test_no_control_bytes_in_tracked_files() {
  local hits
  count=$(git ls-files | wc -l | tr -d ' ')
  hits=$(git ls-files -z | xargs -0 perl -ne "$FIND_CONTROL_BYTES" 2>&1) || { printf 'FAIL the scan itself failed\n'; failures=1; return; }
  [ -z "$hits" ] && return
  printf '%s\n' "$hits" | awk -F '\t' 'NF == 2 { print "FAIL control byte in " $1 " line " $2; next } { print "FAIL scan: " $0 }'
  failures=$(printf '%s\n' "$hits" | awk -F '\t' 'NF == 2 { print $1; next } { print "scan-error" }' | sort -u | wc -l | tr -d ' ')
}

test_no_control_bytes_in_tracked_files
printf '%s\n' "$((count - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
