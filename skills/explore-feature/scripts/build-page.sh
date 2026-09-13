#!/bin/bash
# build-page.sh: inlines the page template around a verified trace. page.html carries six
# markers; each is replaced by the file or value named below, so the result is one
# self-contained HTML file with no external reference at all. The JSON blobs are embedded in
# application/json script tags with every `<` written as <, which is valid JSON and
# inert to the HTML parser.
#   <!--TITLE-->     the trace's title, HTML-escaped, inside <title>
#   <!--CSS-->       page.css
#   <!--JS-->        page.js, page-highlight.js, page-flow.js, then page-capture.js
#   <!--TRACE-->     trace.json
#   <!--EXCERPTS-->  excerpts.json
#   <!--CAPTURE-->   capture.json when --capture names one, else null
# Usage: build-page.sh <trace.json> <excerpts.json> <out.html> [<assets dir>] [--capture <capture.json>]
# Needs jq and sed on PATH. Refuses an excerpts file that does not cover every hop, one whose
# excerpt lines carry a hardcoded secret, judged by the law scout's own patterns (9.5) through
# secret-scan.sh beside this script, and a capture that fails capture-verify.jq against the
# trace or carries a secret: the checks capture-run.sh already ran (16.10), run again here
# because the page is what gets published.
set -u

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
here=$(cd "$here" && pwd)
TRACE=''
EXCERPTS=''
OUT=''
ASSETS="$here/../assets"
CAPTURE=''
POSITIONAL=()
SCAN_SH="$here/secret-scan.sh"
VERIFY_JQ="$here/capture-verify.jq"
# The secret scan runs the law scout's own block over the excerpt lines; LAW_SCOUT_MD points
# it at another copy of 9.5, for a test.
LAW_SCOUT=${LAW_SCOUT_MD:-"$here/../../engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md"}
EXCERPT_IDS=()

usage() { printf 'usage: build-page.sh <trace.json> <excerpts.json> <out.html> [<assets dir>] [--capture <capture.json>]\n' >&2; exit 2; }
refuse() { printf 'build-page: %s\n' "$1" >&2; exit 1; }

# parse_args: three positionals, an optional assets dir, and --capture anywhere among them.
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --capture) [ $# -ge 2 ] || usage; CAPTURE=$2; shift 2 ;;
      --capture=*) CAPTURE=${1#--capture=}; shift ;;
      -*) usage ;;
      *) POSITIONAL+=("$1"); shift ;;
    esac
  done
  TRACE=${POSITIONAL[0]:-}
  EXCERPTS=${POSITIONAL[1]:-}
  OUT=${POSITIONAL[2]:-}
  [ -z "${POSITIONAL[3]:-}" ] || ASSETS=${POSITIONAL[3]}
}

# check_inputs: every input exists, parses and agrees with the others before a byte is written.
check_inputs() {
  [ -n "$TRACE" ] && [ -n "$EXCERPTS" ] && [ -n "$OUT" ] || usage
  command -v jq >/dev/null 2>&1 || refuse "jq is not on PATH"
  [ -f "$TRACE" ] || refuse "trace file does not exist: $TRACE"
  [ -f "$EXCERPTS" ] || refuse "excerpts file does not exist: $EXCERPTS"
  for part in page.html page.css page.js page-highlight.js page-flow.js page-capture.js; do
    [ -f "$ASSETS/$part" ] || refuse "template part is missing: $ASSETS/$part"
  done
  jq -e . "$TRACE" >/dev/null 2>&1 || refuse "trace file is not valid JSON"
  jq -e . "$EXCERPTS" >/dev/null 2>&1 || refuse "excerpts file is not valid JSON"
  missing=$(jq -r --slurpfile ex "$EXCERPTS" '[.hops[].id] - [$ex[0].excerpts[].id] | .[]' "$TRACE")
  [ -z "$missing" ] || refuse "excerpts do not cover hop(s): $(printf '%s' "$missing" | tr '\n' ' '); run verify-trace.sh again"
  for marker in TITLE CSS JS TRACE EXCERPTS CAPTURE; do
    n=$(grep -c "<!--$marker-->" "$ASSETS/page.html")
    [ "$n" = 1 ] || refuse "page.html must carry the marker <!--$marker--> exactly once, has it $n times"
  done
}

# check_capture: a capture is embedded only when it parses and agrees with the trace under
# capture-verify.jq, the check capture-run.sh already ran (16.10, check 4). It runs again here
# because the page is what gets published, and a hand-edited file would otherwise slip in.
check_capture() {
  [ -n "$CAPTURE" ] || return 0
  [ -f "$CAPTURE" ] || refuse "capture file does not exist: $CAPTURE"
  jq -e . "$CAPTURE" >/dev/null 2>&1 || refuse "capture file is not valid JSON"
  [ -f "$VERIFY_JQ" ] || refuse "capture-verify.jq is missing beside this script"
  problems=$(jq -r --slurpfile trace "$TRACE" -f "$VERIFY_JQ" "$CAPTURE" 2>&1) || refuse "capture-verify.jq could not read $CAPTURE: $(printf '%s' "$problems" | head -n 1)"
  [ -z "$problems" ] || refuse "capture does not match the trace: $(printf '%s' "$problems" | head -n 1)"
}

# html_escape: the four characters that matter inside a text node or a quoted attribute.
html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# json_for_html <file>: compact JSON with every < escaped, safe inside a script element.
json_for_html() { jq -c . "$1" | sed 's#<#\\u003c#g'; }

# write_excerpt_files <dir>: one file per hop holding its excerpt lines byte for byte, named
# by the hop id, which EXCERPT_IDS collects for the scan.
write_excerpt_files() {
  for id in $(jq -r '.excerpts[].id' "$EXCERPTS"); do
    case "$id" in *[!A-Za-z0-9_-]*) refuse "excerpt id is not a plain token: $id" ;; esac
    jq -r --arg id "$id" '.excerpts[] | select(.id == $id) | .lines[]' "$EXCERPTS" > "$1/$id"
    EXCERPT_IDS+=("$id")
  done
}

# describe_hit <row> <count>: the block's first row (rule, hop:line:redacted text) as one line
# naming the hop and the source line. Only the position is printed, never the text, since a
# line can carry a second secret the first rule's redaction did not touch.
describe_hit() {
  row=${1#sec.hardcoded-secret }
  id=${row%%:*}; rest=${row#*:}; n=${rest%%:*}
  file=$(jq -r --arg id "$id" '.hops[] | select(.id == $id) | .file' "$TRACE")
  start=$(jq -r --arg id "$id" '.excerpts[] | select(.id == $id) | .start' "$EXCERPTS")
  more=''; [ "$2" -gt 1 ] && more=" ($(($2 - 1)) more excerpt lines match)"
  printf 'hop %s (%s:%s) has a hardcoded secret in its excerpt%s; move it out of source and rotate it, or narrow the range' "$id" "$file" "$((start + n - 1))" "$more"
}

# scan_excerpts: refuses the build when an excerpt line carries a hardcoded secret, since the
# page is published. The rows arrive redacted from secret-scan.sh, which is run inside the
# excerpt folder so a row names the hop; a scan that cannot run refuses too, because a page
# built past a scan that never ran was not scanned.
scan_excerpts() {
  [ -f "$LAW_SCOUT" ] || refuse "law scout block not found at $LAW_SCOUT; set LAW_SCOUT_MD"
  [ -f "$SCAN_SH" ] || refuse "secret-scan.sh is missing beside this script"
  LAW_SCOUT=$(cd "$(dirname "$LAW_SCOUT")" && pwd)/$(basename "$LAW_SCOUT")
  dir=$(mktemp -d "${TMPDIR:-/tmp}/build-page-scan.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  write_excerpt_files "$dir"
  rows=$( (cd "$dir" && bash "$SCAN_SH" "$LAW_SCOUT" "${EXCERPT_IDS[@]}") 2> "$dir/err")
  status=$?
  [ "$status" -ne 2 ] || refuse "the secret scan did not run: $(head -n 1 "$dir/err")"
  hits=$(printf '%s\n' "$rows" | grep -c '^sec\.hardcoded-secret ')
  first=$(printf '%s\n' "$rows" | grep '^sec\.hardcoded-secret ' | head -n 1)
  [ "$hits" -eq 0 ] || refuse "$(describe_hit "$first" "$hits")"
  rm -rf "$dir"
}

# scan_capture: the same secret scan over the capture file. The sink masks secrets before
# they reach disk and capture-run.sh refuses a capture that still carries one, so a hit here
# means the file was edited or assembled by hand.
scan_capture() {
  [ -n "$CAPTURE" ] || return 0
  rows=$(bash "$SCAN_SH" "$LAW_SCOUT" "$CAPTURE" 2>&1)
  status=$?
  [ "$status" -ne 2 ] || refuse "the secret scan did not run on the capture: $(printf '%s' "$rows" | head -n 1)"
  [ "$status" -eq 0 ] || refuse "the capture carries a hardcoded secret; rerun capture-run.sh, which masks values and refuses a capture that still carries one"
}

# capture_json: the capture blob, or null, so the page can tell "no capture" from "empty".
capture_json() { if [ -n "$CAPTURE" ]; then json_for_html "$CAPTURE"; else printf 'null\n'; fi; }

# assemble: walks page.html once and swaps each marker line for what it names.
assemble() {
  title=$(jq -r '.title // "Explore"' "$TRACE" | html_escape)
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'<!--TITLE-->'*) printf '%s\n' "${line%%<!--TITLE-->*}$title${line#*<!--TITLE-->}" ;;
      *'<!--CSS-->'*) cat "$ASSETS/page.css" ;;
      *'<!--JS-->'*) cat "$ASSETS/page.js" "$ASSETS/page-highlight.js" "$ASSETS/page-flow.js" "$ASSETS/page-capture.js" ;;
      *'<!--TRACE-->'*) json_for_html "$TRACE" ;;
      *'<!--EXCERPTS-->'*) json_for_html "$EXCERPTS" ;;
      *'<!--CAPTURE-->'*) capture_json ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$ASSETS/page.html"
}

main() {
  parse_args "$@"
  check_inputs
  check_capture
  scan_excerpts
  scan_capture
  tmp=$(mktemp "${TMPDIR:-/tmp}/build-page.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  assemble > "$tmp" || refuse "assembling the page failed"
  mv "$tmp" "$OUT"
  trap - EXIT
  printf 'wrote %s (%s bytes%s)\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')" "${CAPTURE:+, capture embedded}"
}

main "$@"
