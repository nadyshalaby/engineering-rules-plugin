#!/bin/bash
# Guard: the law's size caps bind this plugin's own scripts (SKILL.md 1.1): every shell file
# under hooks/ and tests/ stays under 500 lines and every function in them under 40. A
# function is a `name() {` or `name() (` line down to the first line that is only `}` or `)`,
# counted between.
# Run: bash tests/hook-caps.test.sh
# CAP_DIR points the test at another directory of shell files, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
FILE_CAP=500
FUNCTION_CAP=40

# long_functions <files>...: "file:function:lines" for every function over the cap.
long_functions() {
  awk -v cap="$FUNCTION_CAP" '
    FNR == 1 { name = "" }
    name != "" && ($0 == "}" || $0 == ")") { if (FNR - start - 1 > cap) print FILENAME ":" name ":" FNR - start - 1; name = ""; next }
    name == "" && match($0, /^[a-z_][a-z0-9_]*\(\)[[:space:]]*[{(][[:space:]]*$/) { name = substr($0, 1, index($0, "(") - 1); start = FNR }
  ' "$@"
}

# long_files <files>...: "file: N lines" for every file over the cap.
long_files() {
  wc -l "$@" | awk -v cap="$FILE_CAP" '$2 != "total" && $1 > cap { print $2 ": " $1 " lines" }'
}

# audited <command>: runs the command over every audited shell file, or over CAP_DIR's files.
audited() {
  if [ -n "${CAP_DIR:-}" ]; then "$@" "$CAP_DIR"/*.sh
  else "$@" "$ROOT"/hooks/*.sh "$ROOT"/hooks/tests/*.sh "$ROOT"/tests/*.sh; fi
}

count_args() { printf '%s' "$#"; }

test_no_function_over_the_cap() {
  over=$(audited long_functions)
  assert_contains "no function over $FUNCTION_CAP lines in $(audited count_args) files" "<none>" "${over:-<none>}"
}

test_no_file_over_the_cap() {
  over=$(audited long_files)
  assert_contains "no file over $FILE_CAP lines" "<none>" "${over:-<none>}"
}

# The check has to be able to fail: a planted 41-line function and a 501-line file are named.
test_planted_breaches_are_named() {
  { printf 'long_one() {\n'; seq 1 41 | sed 's/^/  x=/'; printf '}\n'; } > "$WORK/planted.sh"
  assert_contains "a planted long function is named" "planted.sh:long_one:41" "$(long_functions "$WORK/planted.sh")"
  { printf 'sub_one() (\n'; seq 1 41 | sed 's/^/  x=/'; printf ')\n'; } > "$WORK/planted-sub.sh"
  assert_contains "a planted long subshell function is named" "planted-sub.sh:sub_one:41" "$(long_functions "$WORK/planted-sub.sh")"
  seq 1 501 > "$WORK/big.sh"
  assert_contains "a planted long file is named" "big.sh: 501 lines" "$(long_files "$WORK/big.sh")"
}

test_no_function_over_the_cap
test_no_file_over_the_cap
test_planted_breaches_are_named
report
