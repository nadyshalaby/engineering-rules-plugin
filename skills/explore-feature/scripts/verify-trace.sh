#!/bin/bash
# verify-trace.sh: refuses a trace.json the working tree disagrees with, then writes
# excerpts.json beside it. The checks are the numbered list in 16.10 ("What verify-trace.sh
# checks, in order"). verify-trace.jq settles the ones jq answers without opening a cited
# file: 2, 3, 4, 9, 10 and the shape of every range and citation. This file opens every
# cited file for the rest, 1, 5, 6, 7 and 8, and writes the excerpts last, 11. Every failure
# prints one line on stderr, `hop <id>: <what is wrong>` or `trace: <what is wrong>`, and the
# script exits 1 having written nothing. There is no flag to skip a check.
# Usage: verify-trace.sh <trace.json> [<excerpts.json>]   (default: excerpts.json beside the trace)
# Needs jq, sed, awk and git on PATH.
set -u

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
SHAPE_JQ="$here/verify-trace.jq"
TRACE=${1:-}
OUT=${2:-}
MAX_HOPS=40
MAX_EXCERPT=200
MAX_TITLE=40
MAX_HOP_TITLE=60
MAX_STEPS=12
MIN_QUESTIONS=3
MAX_QUESTIONS=5
ROOT=
HOP_INDEX=0
failures=0

fail() { printf '%s\n' "$1" >&2; failures=$((failures + 1)); }
tq() { jq -r "$1" "$TRACE"; }
hop_field() { jq -r --argjson i "$HOP_INDEX" ".hops[\$i] | $1" "$TRACE"; }
line_count() { awk 'END { print NR }' "$1"; }
is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; }
usage() { printf 'usage: verify-trace.sh <trace.json> [<excerpts.json>]\n' >&2; exit 2; }

# check_parse: check 1. A trace that does not parse stops everything else.
check_parse() {
  [ -n "$TRACE" ] || usage
  command -v jq >/dev/null 2>&1 || { fail "trace: jq is not on PATH"; return 1; }
  [ -f "$SHAPE_JQ" ] || { fail "trace: verify-trace.jq is missing beside this script"; return 1; }
  [ -f "$TRACE" ] || { fail "trace: file does not exist: $TRACE"; return 1; }
  jq -e . "$TRACE" >/dev/null 2>&1 || { fail "trace: $TRACE is not valid JSON"; return 1; }
  [ "$(tq '.version')" = 2 ] || { fail "trace: version must be 2"; return 1; }
  [ "$(tq '.hops | type')" = array ] || { fail "trace: hops must be an array"; return 1; }
  root=$(tq '.root')
  [ -d "$root" ] || { fail "trace: root is not a directory: $root"; return 1; }
  ROOT=$(cd "$root" && pwd -P)
}

# check_shape: checks 2, 3, 4, 9 and 10, plus the shape of every range and citation.
check_shape() {
  problems=$(jq -r -f "$SHAPE_JQ" --argjson maxHops "$MAX_HOPS" --argjson maxTitle "$MAX_TITLE" \
    --argjson maxHopTitle "$MAX_HOP_TITLE" --argjson maxSteps "$MAX_STEPS" \
    --argjson minQuestions "$MIN_QUESTIONS" --argjson maxQuestions "$MAX_QUESTIONS" "$TRACE" 2>&1) \
    || { fail "trace: the structural check could not run: $problems"; return 1; }
  [ -z "$problems" ] || { printf '%s\n' "$problems" >&2; failures=$((failures + 1)); return 1; }
}

# load_hop <index>: one jq read per hop. The fields land in HOP_* and CALL_*, the shell's way
# of handing one record to the checks below instead of eleven arguments.
load_hop() {
  HOP_INDEX=$1
  { IFS= read -r HOP_ID; IFS= read -r HOP_FILE; IFS= read -r HOP_LINE; IFS= read -r HOP_EVIDENCE
    IFS= read -r HOP_START; IFS= read -r HOP_END; IFS= read -r HOP_FROM; IFS= read -r HOP_STATUS
    IFS= read -r CALL_FILE; IFS= read -r CALL_LINE; IFS= read -r CALL_EVIDENCE; } < <(hop_field \
    '.id, .file, .line, .evidence, .range[0], .range[1], (.from // ""), .status, (.call.file // ""), (.call.line // ""), (.call.evidence // "")')
}

site_of_hop() { SITE_FILE=$HOP_FILE; SITE_LINE=$HOP_LINE; SITE_EVIDENCE=$HOP_EVIDENCE; }
site_of_call() { SITE_FILE=$CALL_FILE; SITE_LINE=$CALL_LINE; SITE_EVIDENCE=$CALL_EVIDENCE; }

# load_candidate <c>: the c-th candidate of the loaded hop, into SITE_*.
load_candidate() {
  { IFS= read -r SITE_FILE; IFS= read -r SITE_LINE; IFS= read -r SITE_EVIDENCE; } \
    < <(hop_field ".candidates[$1] | (.file // \"\"), (.line // \"\"), (.evidence // \"\")")
}

# check_site <label>: checks 5 and 6 for the citation in SITE_*. Returns 1 after a failure so
# the caller stops reading a file that is not there.
check_site() {
  case "$SITE_FILE" in ''|/*|../*|*/../*|..|*/..) fail "$1: file must be a relative path inside root: '$SITE_FILE'"; return 1 ;; esac
  [ -f "$ROOT/$SITE_FILE" ] || { fail "$1: file does not exist under root: $SITE_FILE"; return 1; }
  is_int "$SITE_LINE" || { fail "$1: line must be a positive integer, is '$SITE_LINE'"; return 1; }
  total=$(line_count "$ROOT/$SITE_FILE")
  [ "$SITE_LINE" -ge 1 ] && [ "$SITE_LINE" -le "$total" ] || { fail "$1: line $SITE_LINE is outside $SITE_FILE ($total lines)"; return 1; }
  [ -n "$SITE_EVIDENCE" ] || { fail "$1: evidence is empty"; return 1; }
  text=$(sed -n "${SITE_LINE}p" "$ROOT/$SITE_FILE")
  case "$text" in *"$SITE_EVIDENCE"*) return 0 ;; esac
  fail "$1: evidence not found on $SITE_FILE:$SITE_LINE; the line reads: $(printf '%s' "$text" | cut -c1-120)"
  return 1
}

# check_range: check 7, first half: the excerpt is in bounds, under the cap and around the frame line.
check_range() {
  total=$(line_count "$ROOT/$HOP_FILE")
  [ "$HOP_START" -ge 1 ] && [ "$HOP_END" -le "$total" ] || { fail "hop $HOP_ID: range $HOP_START-$HOP_END is outside $HOP_FILE ($total lines)"; return 1; }
  [ "$HOP_START" -le "$HOP_LINE" ] && [ "$HOP_LINE" -le "$HOP_END" ] || { fail "hop $HOP_ID: range $HOP_START-$HOP_END does not contain line $HOP_LINE"; return 1; }
  [ $((HOP_END - HOP_START + 1)) -le "$MAX_EXCERPT" ] || fail "hop $HOP_ID: excerpt is $((HOP_END - HOP_START + 1)) lines, the cap is $MAX_EXCERPT"
}

# check_call: check 7, second half: the call site sits in the parent's file, inside its excerpt.
check_call() {
  { IFS= read -r pfile; IFS= read -r pstart; IFS= read -r pend; } \
    < <(jq -r --arg id "$HOP_FROM" '.hops[] | select(.id == $id) | .file, .range[0], .range[1]' "$TRACE")
  [ "$CALL_FILE" = "$pfile" ] || { fail "hop $HOP_ID: call site is in $CALL_FILE but the parent hop $HOP_FROM is a frame in $pfile"; return 1; }
  [ "$pstart" -le "$CALL_LINE" ] && [ "$CALL_LINE" -le "$pend" ] || fail "hop $HOP_ID: call line $CALL_LINE is outside the parent hop $HOP_FROM's range $pstart-$pend"
}

# check_invoked: check 8, every invoked line is inside the loaded hop's range.
check_invoked() {
  problems=$(jq -r --argjson i "$HOP_INDEX" --argjson a "$HOP_START" --argjson b "$HOP_END" \
    '.hops[$i] | .id as $id | (.invoked // [])[] | select((type != "number") or . < $a or . > $b) | "hop \($id): invoked line \(.) is outside the range \($a)-\($b)"' "$TRACE")
  [ -z "$problems" ] || { printf '%s\n' "$problems" >&2; failures=$((failures + 1)); }
}

# check_candidates: every candidate of an unresolved hop is a real citation, checks 5 and 6 again.
check_candidates() {
  count=$(hop_field '.candidates // [] | length')
  c=0
  while [ "$c" -lt "$count" ]; do
    load_candidate "$c"
    check_site "hop $HOP_ID candidate $((c + 1))" || true
    c=$((c + 1))
  done
}

# check_hop <index>: checks 5 to 8 for one hop, its call site and its candidates.
check_hop() {
  load_hop "$1"
  site_of_hop
  check_site "hop $HOP_ID" || return 1
  check_range || return 1
  if [ -n "$HOP_FROM" ]; then
    site_of_call
    check_site "hop $HOP_ID call site" && check_call
  fi
  check_invoked
  [ "$HOP_STATUS" = unresolved ] && check_candidates
  return 0
}

# excerpt: one excerpt object for the loaded hop; its lines are copied by sed and encoded by
# jq, never typed.
excerpt() {
  sed -n "${HOP_START},${HOP_END}p" "$ROOT/$HOP_FILE" | jq -R . | jq -s --arg id "$HOP_ID" --arg file "$HOP_FILE" \
    --argjson start "$HOP_START" --argjson end "$HOP_END" '{ id: $id, file: $file, start: $start, end: $end, lines: . }'
}

# repo_entry <file>: which repository the file sits in, at which commit, and whether the file
# carries uncommitted changes, so the page can say which tree its lines describe.
repo_entry() {
  d=${1%/*}; [ "$d" = "$1" ] && d=.
  dir=$(cd "$ROOT/$d" && pwd -P)
  if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    commit=$(git -C "$top" rev-parse --short HEAD 2>/dev/null) || commit=""
    dirty=false
    [ -z "$(git -C "$top" status --porcelain -- "$ROOT/$1" 2>/dev/null)" ] || dirty=true
    case "$ROOT/" in "$top"/*) rel=. ;; *) rel=${top#"$ROOT"/} ;; esac
  else
    rel="(no repository)"; commit=""; dirty=false
  fi
  jq -n --arg r "$rel" --arg c "$commit" --arg f "$1" --argjson d "$dirty" \
    '{ repo: $r, commit: (if $c == "" then null else $c end), file: $f, dirty: $d }'
}

# write_excerpts: check 11, the only write, after every check passed.
write_excerpts() {
  W=$(mktemp -d "${TMPDIR:-/tmp}/verify-trace.XXXXXX")
  trap 'rm -rf "$W"' EXIT
  n=$(tq '.hops | length'); i=0
  while [ "$i" -lt "$n" ]; do load_hop "$i"; excerpt >> "$W/excerpts.ndjson"; i=$((i + 1)); done
  jq -s . "$W/excerpts.ndjson" > "$W/excerpts.json"
  tq '[.hops[].file] | unique | .[]' | while IFS= read -r f; do repo_entry "$f"; done | jq -s \
    'group_by(.repo) | map({ path: .[0].repo, commit: .[0].commit, dirty: [.[] | select(.dirty) | .file] })' > "$W/repos.json"
  jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg root "$ROOT" --slurpfile ex "$W/excerpts.json" --slurpfile rp "$W/repos.json" \
    '{ verified_at: $at, root: $root, repos: $rp[0], excerpts: $ex[0] }' > "$OUT" || { fail "trace: could not write $OUT"; exit 1; }
  printf 'verified %s hops across %s files; wrote %s\n' "$n" "$(tq '[.hops[].file] | unique | length')" "$OUT"
}

main() {
  check_parse || exit 1
  if [ -z "$OUT" ]; then dir=${TRACE%/*}; [ "$dir" = "$TRACE" ] && dir=.; OUT="$dir/excerpts.json"; fi
  check_shape || exit 1
  n=$(tq '.hops | length'); i=0
  while [ "$i" -lt "$n" ]; do check_hop "$i"; i=$((i + 1)); done
  [ "$failures" -eq 0 ] || exit 1
  write_excerpts
}

main
