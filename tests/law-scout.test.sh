#!/bin/bash
# Runs the law scout's shell block straight out of 9.5 against a throwaway git repo with one
# planted instance per construct ban, and expects every hit and an equal coverage pair.
# Run: bash tests/law-scout.test.sh
# LAW_SCOUT_MD points the test at another copy of 9.5, for a watched failure.
set -u
here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
ROOT=$(git -C "$here" rev-parse --show-toplevel) || exit 1
DOC="${LAW_SCOUT_MD:-$ROOT/skills/engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/law-scout-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
failures=0
count=0

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

# The HOW block, with its <base>..HEAD placeholder pointed at the fixture's base commit.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$DOC" \
    | sed "s/\"<base>..HEAD\"/\"$1..HEAD\"/"
}

# A repo whose second commit plants one instance per ban, a clean file, a path with a space,
# a path that starts with a dash, and a path that would run as code if it were ever spliced
# into shell text.
build_fixture() (
  git init -q "$WORK/repo" && cd "$WORK/repo" || return 1
  git -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
  mkdir src
  printf 'const ok = 1\n' > src/clean.ts
  printf '// @ts-ignore\nconst a = 1\n' > 'src/my file.ts'
  printf 'try { x() } catch (e) {}\n' > src/empty-catch.ts
  printf 'throw new Error("x")\n' > src/bare.ts
  printf '// TODO fix me\n' > src/todo.ts
  printf '// @ts-ignore\n' > -dash.ts
  printf 'const quiet = 1\n' > 'src/a";echo INJECTED;".ts'
  git add -- src/clean.ts 'src/my file.ts' src/empty-catch.ts src/bare.ts src/todo.ts -dash.ts 'src/a";echo INJECTED;".ts'
  git -c user.name=t -c user.email=t@example.com commit -q -m planted
)

run_block() (
  cd "$WORK/repo" || return 1
  extract_block "$(git rev-parse HEAD~1)" > "$WORK/block.sh"
  SCOUT_PATHS="$WORK/paths" PROJECT_BAN_PATTERNS="$WORK/no-such-file" bash "$WORK/block.sh" 2>&1
)

test_finds_every_planted_ban() {
  out=$(run_block)
  assert_contains "suppression in a path with a space" "src/my file.ts:1:// @ts-ignore" "$out"
  assert_contains "suppression in a path that starts with a dash" "-dash.ts:1:// @ts-ignore" "$out"
  assert_contains "empty catch" "src/empty-catch.ts:1:" "$out"
  assert_contains "bare throw" "src/bare.ts:1:" "$out"
  assert_contains "debt marker" "src/todo.ts:1:" "$out"
  assert_missing "the clean file stays silent" "src/clean.ts" "$out"
  assert_missing "no path text ever runs as code" "INJECTED" "$out"
  pair=$(printf '%s\n' "$out" | tail -n 2 | tr -d ' ' | tr '\n' '/')
  assert_contains "coverage pair: seven handed in, seven readable" "7/7/" "$pair"
}

test_refuses_a_list_without_nul() {
  printf 'src/clean.ts\nsrc/todo.ts\n' > "$WORK/newline-paths"
  guard=$(grep -F 'not NUL-separated' "$WORK/block.sh")
  out=$(SCOUT_PATHS="$WORK/newline-paths" bash -c "$guard" 2>&1; echo "exit=$?")
  assert_contains "a list built without -z is refused" "SCOUT_PATHS is not NUL-separated" "$out"
  assert_contains "and the block stops" "exit=1" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_finds_every_planted_ban
test_refuses_a_list_without_nul
printf '%s\n' "$((count - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
