#!/bin/bash
# engineering-rules status line: directory, git branch and dirty state, model, context
# bar, session uptime, and the last phase-ledger position Claude printed this session.
# Receives Claude Code's status-line JSON on stdin. Plugins cannot set statusLine, so
# the README carries the one-line settings snippet that points here.
# It is re-rendered continuously, so the ledger scan keeps a cursor per transcript and
# greps only the bytes added since the last render. Runs on the bash macOS ships (3.2).

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./ledger-position.sh
. "$here/ledger-position.sh"

ESC=$'\033'
reset="${ESC}[0m"
bold_green="${ESC}[1;32m"
green="${ESC}[0;32m"
bold_cyan="${ESC}[1;36m"
bold_blue="${ESC}[1;34m"
red="${ESC}[0;31m"
yellow="${ESC}[0;33m"
bold_magenta="${ESC}[1;35m"
dim="${ESC}[2m"
bold="${ESC}[1m"
gray="${ESC}[0;90m"
CACHE_DIR="${TMPDIR:-/tmp}"
SCAN_OVERLAP=64

# One jq call for every field, one field per line, so an empty field keeps its place.
read_status_fields() {
  printf '%s' "$1" | jq -r '.cwd // .workspace.current_dir // "", .transcript_path // "", .model.display_name // "", (.context_window.used_percentage // "" | tostring)' 2>/dev/null
}

render_git_segment() {
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$branch" ] || return 0
  dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  printf '  %sgit:(%s%s%s)%s' "$bold_blue" "$red" "$branch" "$bold_blue" "$reset"
  [ -n "$dirty" ] && printf ' %s✗%s' "$yellow" "$reset"
  return 0
}

render_model_segment() {
  [ -n "$model_name" ] || return 0
  printf '  %s│%s %s%s%s' "$gray" "$reset" "$bold_magenta" "$model_name" "$reset"
}

# Ten blocks filled in proportion to the context used: green, yellow from 50%, red from 75%.
render_context_segment() {
  [ -n "$used_pct" ] || return 0
  used_int=$(printf '%.0f' "$used_pct" 2>/dev/null) || return 0
  bar_color="$green"
  [ "$used_int" -ge 50 ] && bar_color="$yellow"
  [ "$used_int" -ge 75 ] && bar_color="$red"
  filled=$(( used_int * 10 / 100 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  filled_str=$(printf '%*s' "$filled" '' | sed 's/ /━/g')
  empty_str=$(printf '%*s' $(( 10 - filled )) '' | sed 's/ /╌/g')
  printf '  %s|%s %s%s%s%s%s %s%s%%%s' "$gray" "$reset" "$bar_color" "$filled_str" "$gray" "$empty_str" "$reset" "$dim" "$used_int" "$reset"
}

# BSD date first (macOS), GNU date second (Linux); empty when neither can parse it.
read_epoch() {
  clean_ts=$(printf '%s' "$1" | sed -E 's/\.[0-9]+Z$/Z/')
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$clean_ts" "+%s" 2>/dev/null || date -u -d "$clean_ts" +%s 2>/dev/null
}

format_duration() {
  elapsed=$1
  [ "$elapsed" -lt 0 ] && elapsed=0
  days=$(( elapsed / 86400 ))
  hrs=$(( (elapsed % 86400) / 3600 ))
  mins=$(( (elapsed % 3600) / 60 ))
  secs=$(( elapsed % 60 ))
  if [ "$days" -gt 0 ]; then printf '%dd %dh %dm' "$days" "$hrs" "$mins"
  elif [ "$hrs" -gt 0 ]; then printf '%dh %dm' "$hrs" "$mins"
  elif [ "$mins" -gt 0 ]; then printf '%dm %ds' "$mins" "$secs"
  else printf '%ds' "$secs"
  fi
}

# Elapsed wall time since the first timestamp in the transcript.
render_session_segment() {
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || return 0
  start_ts=$(head -n 200 "$transcript_path" 2>/dev/null | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | head -n 1)
  [ -n "$start_ts" ] || return 0
  start_epoch=$(read_epoch "$start_ts")
  [ -n "$start_epoch" ] || return 0
  printf '  %s│%s %sup %s%s' "$gray" "$reset" "$dim" "$(format_duration $(( $(date -u +%s) - start_epoch )))" "$reset"
}

# The last ledger heading Claude printed. The cursor file holds "<bytes scanned> <position>";
# each render greps only the bytes added since, with an overlap so a heading that straddles
# the cursor is still seen. A transcript that shrank was replaced, so the cursor resets.
render_phase_segment() {
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || return 0
  cache="$CACHE_DIR/engineering-rules-statusline-$(printf '%s' "$transcript_path" | cksum | cut -d ' ' -f 1)"
  size=$(wc -c < "$transcript_path" | tr -d ' ')
  offset=0
  position=""
  [ -f "$cache" ] && IFS=' ' read -r offset position < "$cache"
  case "$offset" in ''|*[!0-9]*) offset=0 ;; esac
  [ "$size" -lt "$offset" ] && { offset=0; position=""; }
  if [ "$size" -gt "$offset" ]; then
    from=$(( offset > SCAN_OVERLAP ? offset - SCAN_OVERLAP + 1 : 1 ))
    found=$(tail -c "+$from" "$transcript_path" 2>/dev/null | read_ledger_position)
    [ -n "$found" ] && position="$found"
    printf '%s %s\n' "$size" "$position" > "$cache" 2>/dev/null
  fi
  [ -n "$position" ] && printf '  %s│%s %s%s%s' "$gray" "$reset" "$bold" "$position" "$reset"
  return 0
}

input=$(cat)
{ IFS= read -r cwd; IFS= read -r transcript_path; IFS= read -r model_name; IFS= read -r used_pct; } <<< "$(read_status_fields "$input")"
[ -n "$cwd" ] || cwd=$(pwd)
project_name=${cwd##*/}
printf '%s➜%s %s%s%s%s%s%s%s%s\n' "$bold_green" "$reset" "$bold_cyan" "$project_name" "$reset" "$(render_git_segment)" "$(render_model_segment)" "$(render_context_segment)" "$(render_session_segment)" "$(render_phase_segment)"
