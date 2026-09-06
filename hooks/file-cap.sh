#!/bin/bash
# engineering-rules file cap.
# Runs on PostToolUse for Edit, Write, MultiEdit and NotebookEdit. SKILL.md 1.1 caps a file
# at 500 lines, and the cap binds every code file, tests included. After an edit lands, this
# hook counts the file and, when it is over the cap, hands Claude one line of context naming
# the file and the count, so the split happens before the stage ends instead of at the
# review. It never blocks: a PostToolUse hook cannot, and a file over the cap is a finding,
# not a refusal. Prose and generated files are not code and are not counted. Unreadable
# input, or a file that is not there, is nothing to count: exit 0, no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./path-kind.sh
. "$here/path-kind.sh"

CAP=500

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PostToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] && [ -f "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
case "$(path_kind "$(relative_path "$path" "$cwd")")" in prose|generated) exit 0 ;; esac
lines=$(wc -l < "$path" | tr -d ' ')
[ "$lines" -gt "$CAP" ] || exit 0
append_log "${cwd##*/}" "cap | file-lines | $path | $lines lines"
jq -cn --arg c "cap.file-lines $path: $lines lines. SKILL.md 1.1 caps a file at $CAP lines; split it by responsibility before this stage ends." \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
