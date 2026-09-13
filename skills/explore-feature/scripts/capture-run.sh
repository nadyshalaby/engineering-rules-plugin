#!/bin/bash
# capture-run.sh: runs the traced code once for real and writes capture.json beside the trace,
# the contract in 16.10 ("capture.json, written by capture-run.sh"). The command is run as
# given, in the current directory, with the loaders handed to both runtimes through the
# environment: BUN_OPTIONS carries the Bun preload and NODE_OPTIONS the Node loader, so a
# package script that spawns either runtime is instrumented too. Nothing is written inside
# the explored repository: the loaders rewrite in memory and every file lands in the trace's
# folder. Test mode waits for the command; live mode backgrounds it and --stop signals it,
# waits for the sink's last flush, then aggregates, scans and verifies the same way.
# Usage: capture-run.sh <trace.json> --test <command...>
#        capture-run.sh <trace.json> --live <command...>
#        capture-run.sh --stop <dir>
# Needs jq on PATH, and bash for the live process group. LAW_SCOUT_MD points the secret scan
# at another copy of 9.5, for a test; CAPTURE_STOP_WAIT is the seconds --stop waits.
set -u

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
here=$(cd "$here" && pwd)
CAPTURE="$here/../capture"
AGGREGATE_JQ="$here/capture-aggregate.jq"
VERIFY_JQ="$here/capture-verify.jq"
SCAN_SH="$here/secret-scan.sh"
LAW_SCOUT=${LAW_SCOUT_MD:-"$here/../../engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md"}
STOP_WAIT=${CAPTURE_STOP_WAIT:-10}
TRACE=
DIR=
MODE=

usage() {
  printf 'usage: capture-run.sh <trace.json> --test <command...>\n       capture-run.sh <trace.json> --live <command...>\n       capture-run.sh --stop <dir>\n' >&2
  exit 2
}
refuse() { printf 'capture-run: %s\n' "$1" >&2; exit 1; }
say() { printf 'capture-run: %s\n' "$1"; }
meta() { jq -r ".$1" "$DIR/capture.meta.json"; }

# check_tools: everything the run needs exists before the command starts.
check_tools() {
  local f
  command -v jq >/dev/null 2>&1 || refuse "jq is not on PATH"
  for f in "$AGGREGATE_JQ" "$VERIFY_JQ" "$SCAN_SH" "$CAPTURE/preload.bun.ts" "$CAPTURE/register.node.mjs"; do
    [ -f "$f" ] || refuse "missing beside this script: $f"
  done
  [ -f "$LAW_SCOUT" ] || refuse "law scout block not found at $LAW_SCOUT; set LAW_SCOUT_MD"
  case "$CAPTURE" in *' '*) refuse "the plugin path has a space, which BUN_OPTIONS and NODE_OPTIONS cannot carry: $CAPTURE" ;; esac
}

# check_trace: the trace parses, is version 2 and names a root that exists; DIR is its folder.
check_trace() {
  [ -f "$TRACE" ] || refuse "trace file does not exist: $TRACE"
  jq -e . "$TRACE" >/dev/null 2>&1 || refuse "trace file is not valid JSON: $TRACE"
  [ "$(jq -r '.version' "$TRACE")" = 2 ] || refuse "trace version must be 2"
  [ -d "$(jq -r '.root' "$TRACE")" ] || refuse "trace root is not a directory: $(jq -r '.root' "$TRACE")"
  DIR=$(cd "$(dirname "$TRACE")" && pwd)
  TRACE="$DIR/$(basename "$TRACE")"
}

# runtime_label <word>: the family of the command's first word, for the run record.
runtime_label() {
  case "$1" in
    bun|bunx) printf 'bun' ;;
    node|npm|npx|pnpm|yarn|tsx) printf 'node' ;;
    *) printf 'other' ;;
  esac
}

# write_meta <command...>: what the aggregate needs to know about the run, written at start
# so --stop can read it back in another process.
write_meta() {
  jq -n --arg trace "$TRACE" --arg mode "$MODE" --arg command "$*" --arg runtime "$(runtime_label "$1")" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{ tracePath: $trace, mode: $mode, command: $command, runtime: $runtime, started: $started }' > "$DIR/capture.meta.json"
}

# export_capture_env: the sink's two paths and the loader flags for both runtimes, appended
# to whatever the user already had in the two option variables. EXPLORE_CAPTURE_BUN_TEST
# passes through untouched: the preload decides from the entry file unless it is set.
export_capture_env() {
  rm -f "$DIR/capture.jsonl"
  export EXPLORE_CAPTURE_TRACE="$TRACE"
  export EXPLORE_CAPTURE_OUT="$DIR/capture.jsonl"
  export BUN_OPTIONS="${BUN_OPTIONS:+$BUN_OPTIONS }--preload=$CAPTURE/preload.bun.ts"
  export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--import $CAPTURE/register.node.mjs"
}

# run_test <command...>: run it, wait, then finish with its exit code.
run_test() {
  write_meta "$@"
  export_capture_env
  "$@"
  finish "$?"
}

# run_live <command...>: run it in its own process group, in the background, and leave the
# pid behind for --stop.
run_live() {
  local pid
  write_meta "$@"
  export_capture_env
  set -m
  "$@" < /dev/null > "$DIR/capture.log" 2>&1 &
  pid=$!
  set +m
  printf '%s\n' "$pid" > "$DIR/capture.pid"
  say "started pid $pid in the background, output in $DIR/capture.log"
  say "fire the request, then run: capture-run.sh --stop $DIR"
}

# stop_live <dir>: SIGTERM the process group, wait for the sink's last flush, then finish.
stop_live() {
  local pid waited=0
  DIR=$(cd "$1" 2>/dev/null && pwd) || refuse "not a directory: $1"
  [ -f "$DIR/capture.pid" ] || refuse "no capture.pid in $DIR; was --live run there?"
  pid=$(cat "$DIR/capture.pid")
  # A pid that is not a number above 1 never came from --live, and kill -- -1 would reach every process.
  case "$pid" in ''|*[!0-9]*) refuse "capture.pid in $DIR does not hold a pid: $pid" ;; esac
  [ "$pid" -gt 1 ] || refuse "capture.pid in $DIR holds pid $pid, which no capture started"
  kill -TERM -- -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || refuse "pid $pid is not running; its output is in $DIR/capture.log"
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$((STOP_WAIT * 5))" ]; do
    sleep 0.2
    waited=$((waited + 1))
  done
  kill -0 "$pid" 2>/dev/null && say "pid $pid is still running after ${STOP_WAIT}s; aggregating what the sink flushed so far"
  rm -f "$DIR/capture.pid"
  TRACE=$(meta tracePath)
  [ -f "$TRACE" ] || refuse "capture.meta.json in $DIR does not name the trace; was --live run there?"
  finish ""
}

# aggregate <exit> <out>: the JSON lines into the contract shape.
aggregate() {
  jq -s --arg root "$(jq -r '.root' "$TRACE")" --arg exit "$1" --arg mode "$(meta mode)" \
    --arg command "$(meta command)" --arg runtime "$(meta runtime)" --arg started "$(meta started)" \
    -f "$AGGREGATE_JQ" "$DIR/capture.jsonl" > "$2" || refuse "aggregating $DIR/capture.jsonl failed; is every line an event the sink wrote?"
}

# scan <file>: a hardcoded secret the masks did not catch deletes everything that carries it.
scan() {
  local rows status line
  rows=$(bash "$SCAN_SH" "$LAW_SCOUT" "$1" 2> "$DIR/capture.scan.err")
  status=$?
  [ "$status" -ne 2 ] || refuse "the secret scan did not run: $(head -n 1 "$DIR/capture.scan.err")"
  rm -f "$DIR/capture.scan.err"
  [ "$status" -eq 0 ] && return 0
  line=$(printf '%s\n' "$rows" | head -n 1 | cut -d: -f2)
  rm -f "$1" "$DIR/capture.jsonl"
  refuse "the aggregate carried a hardcoded secret at its line $line that the masks did not catch; the aggregate and the events were deleted. Add the key to the sink's mask list or narrow the trace, then run again"
}

# verify <file>: capture-verify.jq against the trace; problems keep the file as rejected.
verify() {
  local problems
  problems=$(jq -r --slurpfile trace "$TRACE" -f "$VERIFY_JQ" "$1") || refuse "capture-verify.jq failed to run"
  [ -z "$problems" ] && return 0
  printf '%s\n' "$problems" >&2
  mv "$1" "$DIR/capture.rejected.json"
  refuse "capture refused ($(printf '%s\n' "$problems" | wc -l | tr -d ' ') problem(s) above); kept as $DIR/capture.rejected.json, nothing embeds it"
}

# finish <exit or empty>: aggregate, scan, verify, then the one line the route hands on.
finish() {
  local tmp="$DIR/capture.json.tmp"
  [ -s "$DIR/capture.jsonl" ] || refuse "no event was recorded: the command did not run any traced function (16.9, step 6b)"
  aggregate "$1" "$tmp"
  scan "$tmp"
  verify "$tmp"
  mv "$tmp" "$DIR/capture.json"
  jq -r --arg dir "$DIR" '"wrote \($dir)/capture.json: \(.anchors | length) anchors, \([.anchors[].calls[]] | length) calls, \([.anchors[].branches[]] | length) branches, \([.anchors[].calls[] | select(has("threw"))] | length) threw, " + (if .run.exit == null then "stopped" else "exit \(.run.exit)" end)' "$DIR/capture.json"
}

main() {
  [ $# -ge 2 ] || usage
  if [ "$1" = --stop ]; then
    [ $# -eq 2 ] || usage
    check_tools
    stop_live "$2"
    return
  fi
  [ $# -ge 3 ] || usage
  TRACE=$1
  MODE=${2#--}
  case "$MODE" in test|live) ;; *) usage ;; esac
  check_tools
  check_trace
  case "$MODE" in
    test) run_test "${@:3}" ;;
    live) run_live "${@:3}" ;;
  esac
}

main "$@"
