#!/bin/bash
# generate-pseudocode: serve a finished page over localhost for the one look, without writing
# anything into the repository being documented.
# Usage: bash serve.sh <page.html>   starts a server in the background and prints the URL
#        bash serve.sh --stop        stops it
# The browser pane cannot act on a file:// page, and a preview launch config would have to be
# written into the project being read, so this serves the page's own directory from a
# throwaway python http.server on the first free port from 8765 upwards.
set -u
pidfile="${TMPDIR:-/tmp}/generate-pseudocode-serve.pid"
if [ "${1:-}" = "--stop" ]; then
  if [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null; then rm -f "$pidfile"; echo "stopped"; else echo "nothing to stop"; fi
  exit 0
fi
page=${1:?usage: serve.sh <page.html> | --stop}
[ -f "$page" ] || { printf 'no such file: %s\n' "$page"; exit 1; }
dir=$(cd "$(dirname "$page")" && pwd -P)
name=$(basename "$page")
port=8765
if command -v lsof >/dev/null 2>&1; then
  while lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do port=$((port + 1)); done
fi
nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >/dev/null 2>&1 &
printf '%s\n' "$!" > "$pidfile"
sleep 1
printf 'http://127.0.0.1:%s/%s\n' "$port" "$name"
