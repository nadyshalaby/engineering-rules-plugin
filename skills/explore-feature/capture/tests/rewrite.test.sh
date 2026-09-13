#!/bin/bash
# The rewriter and the sink over the sample fixture: rewrite.test.mjs beside this file holds
# the checks (its header says what); this wrapper gives it a directory with
# node_modules/typescript 5, installed from bun's cache the way an explored repo carries its
# own compiler (typescript 7 ships the Go compiler only, no API), and hands its exit code
# on. Needs bun and node on PATH and the install to succeed; prints a skip line and passes
# vacuously otherwise, since the loaders cannot run either.
# Run: bash skills/explore-feature/capture/tests/rewrite.test.sh
# CAPTURE_DIR points the checks at another copy of the capture modules, for a watched failure.
set -u
here=$(dirname "${BASH_SOURCE[0]}")
WORK=$(mktemp -d "${TMPDIR:-/tmp}/rewrite.test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

for tool in bun node; do
  command -v "$tool" >/dev/null 2>&1 && continue
  printf 'skip rewrite: %s is not on PATH\n0 passed, 0 failed\n' "$tool"
  exit 0
done

mkdir -p "$WORK/root"
printf '{ "name": "rewrite-test", "private": true }\n' > "$WORK/root/package.json"
if ! (cd "$WORK/root" && bun add -d typescript@5 > "$WORK/install.log" 2>&1); then
  printf 'skip rewrite: typescript 5 could not be installed into %s (no registry and no cache?): %s\n0 passed, 0 failed\n' "$WORK/root" "$(tail -n 1 "$WORK/install.log")"
  exit 0
fi
node "$here/rewrite.test.mjs" "$WORK/root"
