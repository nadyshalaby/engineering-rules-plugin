#!/bin/bash
# secret-scan.sh: the law scout's own secret patterns (9.5) over the given files. Prints every
# hit as the block prints it, `sec.hardcoded-secret <file>:<line>:<redacted>`, the value
# never shown. Exits 0 when clean, 1 on a hit, and 2 when the scan could not run (the block
# missing or failing), because a scan that never ran is not a clean result. build-page.sh
# runs it over the excerpt lines and capture-run.sh over capture.json; neither holds a
# pattern of its own, so the patterns have one source.
# Usage: secret-scan.sh <law-scout.md> <file>...   (paths as the caller wants them printed)
# Needs bash, awk, grep, sed and xargs on PATH.
set -u

LAW_SCOUT=${1:-}
[ -n "$LAW_SCOUT" ] && [ $# -ge 2 ] || { printf 'usage: secret-scan.sh <law-scout.md> <file>...\n' >&2; exit 2; }
shift
[ -f "$LAW_SCOUT" ] || { printf 'law scout block not found at %s\n' "$LAW_SCOUT" >&2; exit 2; }

# extract_block: the law scout's bash block without the git line that builds a touched scope.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$LAW_SCOUT" | grep -v '^git diff -z'
}

dir=$(mktemp -d "${TMPDIR:-/tmp}/secret-scan.XXXXXX")
trap 'rm -rf "$dir"' EXIT
extract_block > "$dir/block.sh"
[ -s "$dir/block.sh" ] || { printf 'law scout block is empty in %s\n' "$LAW_SCOUT" >&2; exit 2; }
: > "$dir/paths"
for path in "$@"; do
  [ -r "$path" ] || { printf 'file is not readable: %s\n' "$path" >&2; exit 2; }
  printf '%s\0' "$path" >> "$dir/paths"
done
SCOUT_PATHS="$dir/paths" bash "$dir/block.sh" > "$dir/out" 2> "$dir/err"
err=$(head -n 1 "$dir/err")
[ -z "$err" ] || { printf 'the secret scan did not run: %s\n' "$err" >&2; exit 2; }
grep '^sec\.hardcoded-secret ' "$dir/out"
[ "$(grep -c '^sec\.hardcoded-secret ' "$dir/out")" -eq 0 ]
