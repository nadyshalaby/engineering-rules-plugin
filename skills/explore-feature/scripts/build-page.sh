#!/bin/bash
# build-page.sh: inlines the page template around a verified trace. page.html carries five
# markers; each is replaced by the file or value named below, so the result is one
# self-contained HTML file with no external reference at all. The two JSON blobs are embedded
# in application/json script tags with every
# `<` written as <, which is valid JSON and inert to the HTML parser.
#   <!--TITLE-->     the trace's title, HTML-escaped, inside <title>
#   <!--CSS-->       page.css
#   <!--JS-->        page.js, page-highlight.js, then page-flow.js
#   <!--TRACE-->     trace.json
#   <!--EXCERPTS-->  excerpts.json
# Usage: build-page.sh <trace.json> <excerpts.json> <out.html> [<assets dir>]
# Needs jq and sed on PATH. Refuses an excerpts file that does not cover every hop, and one
# whose excerpt lines carry a hardcoded secret, judged by the law scout's own patterns (9.5).
set -u

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
TRACE=${1:-}
EXCERPTS=${2:-}
OUT=${3:-}
ASSETS=${4:-"$here/../assets"}
# The secret scan runs the law scout's own block over the excerpt lines; LAW_SCOUT_MD points
# it at another copy of 9.5, for a test.
LAW_SCOUT=${LAW_SCOUT_MD:-"$here/../../engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md"}

usage() { printf 'usage: build-page.sh <trace.json> <excerpts.json> <out.html> [<assets dir>]\n' >&2; exit 2; }
refuse() { printf 'build-page: %s\n' "$1" >&2; exit 1; }

# check_inputs: every input exists, parses and agrees with the others before a byte is written.
check_inputs() {
  [ -n "$TRACE" ] && [ -n "$EXCERPTS" ] && [ -n "$OUT" ] || usage
  command -v jq >/dev/null 2>&1 || refuse "jq is not on PATH"
  [ -f "$TRACE" ] || refuse "trace file does not exist: $TRACE"
  [ -f "$EXCERPTS" ] || refuse "excerpts file does not exist: $EXCERPTS"
  for part in page.html page.css page.js page-highlight.js page-flow.js; do
    [ -f "$ASSETS/$part" ] || refuse "template part is missing: $ASSETS/$part"
  done
  jq -e . "$TRACE" >/dev/null 2>&1 || refuse "trace file is not valid JSON"
  jq -e . "$EXCERPTS" >/dev/null 2>&1 || refuse "excerpts file is not valid JSON"
  missing=$(jq -r --slurpfile ex "$EXCERPTS" '[.hops[].id] - [$ex[0].excerpts[].id] | .[]' "$TRACE")
  [ -z "$missing" ] || refuse "excerpts do not cover hop(s): $(printf '%s' "$missing" | tr '\n' ' '); run verify-trace.sh again"
  for marker in TITLE CSS JS TRACE EXCERPTS; do
    n=$(grep -c "<!--$marker-->" "$ASSETS/page.html")
    [ "$n" = 1 ] || refuse "page.html must carry the marker <!--$marker--> exactly once, has it $n times"
  done
}

# html_escape: the four characters that matter inside a text node or a quoted attribute.
html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# json_for_html <file>: compact JSON with every < escaped, safe inside a script element.
json_for_html() { jq -c . "$1" | sed 's#<#\\u003c#g'; }

# extract_block: the law scout's bash block (9.5) without the git line that builds a touched
# scope; the secret patterns have one source, and this script holds none of them.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$LAW_SCOUT" | grep -v '^git diff -z'
}

# write_excerpt_files <dir>: one file per hop holding its excerpt lines byte for byte, plus
# the NUL-separated path list the block reads.
write_excerpt_files() {
  : > "$1/paths"
  for id in $(jq -r '.excerpts[].id' "$EXCERPTS"); do
    case "$id" in *[!A-Za-z0-9_-]*) refuse "excerpt id is not a plain token: $id" ;; esac
    jq -r --arg id "$id" '.excerpts[] | select(.id == $id) | .lines[]' "$EXCERPTS" > "$1/$id"
    printf '%s\0' "$id" >> "$1/paths"
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
# page is published. The rows arrive redacted from the block; a scan that cannot run refuses
# too, because a page built past a scan that never ran was not scanned.
scan_excerpts() {
  [ -f "$LAW_SCOUT" ] || refuse "law scout block not found at $LAW_SCOUT; set LAW_SCOUT_MD"
  dir=$(mktemp -d "${TMPDIR:-/tmp}/build-page-scan.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  extract_block > "$dir/block.sh"
  write_excerpt_files "$dir"
  (cd "$dir" && SCOUT_PATHS="$dir/paths" bash "$dir/block.sh" > "$dir/out" 2> "$dir/err")
  err=$(head -n 1 "$dir/err")
  hits=$(grep -c '^sec\.hardcoded-secret ' "$dir/out")
  first=$(grep '^sec\.hardcoded-secret ' "$dir/out" | head -n 1)
  [ -z "$err" ] || refuse "the secret scan did not run: $err"
  [ "$hits" -eq 0 ] || refuse "$(describe_hit "$first" "$hits")"
  rm -rf "$dir"
}

# assemble: walks page.html once and swaps each marker line for what it names.
assemble() {
  title=$(jq -r '.title // "Explore"' "$TRACE" | html_escape)
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'<!--TITLE-->'*) printf '%s\n' "${line%%<!--TITLE-->*}$title${line#*<!--TITLE-->}" ;;
      *'<!--CSS-->'*) cat "$ASSETS/page.css" ;;
      *'<!--JS-->'*) cat "$ASSETS/page.js" "$ASSETS/page-highlight.js" "$ASSETS/page-flow.js" ;;
      *'<!--TRACE-->'*) json_for_html "$TRACE" ;;
      *'<!--EXCERPTS-->'*) json_for_html "$EXCERPTS" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$ASSETS/page.html"
}

main() {
  check_inputs
  scan_excerpts
  tmp=$(mktemp "${TMPDIR:-/tmp}/build-page.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  assemble > "$tmp" || refuse "assembling the page failed"
  mv "$tmp" "$OUT"
  trap - EXIT
  printf 'wrote %s (%s bytes)\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')"
}

main "$@"
