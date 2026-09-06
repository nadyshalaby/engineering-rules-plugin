#!/bin/bash
# engineering-rules re-anchor.
# Runs on SessionStart when a session resumes or its context was compacted. A summary of the
# law is not the law (SKILL.md 1.7, step 7): after context loss the always-on section is read
# again from disk before anything else. This hook prints that instruction into the new
# context with the path to read, and adds the last phase-ledger position it finds in the
# transcript, so the ledger re-opens on the right item (5.1, pause and resume). Plain text on
# stdout is context for a SessionStart hook. Any other start reason, or input that cannot be
# read, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./ledger-position.sh
. "$here/ledger-position.sh"

SKILL="${CLAUDE_PLUGIN_ROOT:-$(cd "$here/.." && pwd)}/skills/engineering-rules/SKILL.md"
SCAN_BYTES=4000000

# The last ledger heading in the transcript's final bytes; empty when there is none.
last_position() {
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  tail -c "$SCAN_BYTES" "$transcript" 2>/dev/null | read_ledger_position
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = SessionStart ] || exit 0
reason=$(hook_field '.how_started // .source // empty')
case "$reason" in
  compact) happened="context was compacted" ;;
  resume) happened="session resumed" ;;
  *) exit 0 ;;
esac
transcript=$(hook_field '.transcript_path // empty')
cwd=$(hook_field '.cwd // empty')
position=$(last_position)
printf 'engineering-rules re-anchor (%s). A summary of the law is not the law: read the always-on law from disk before the next step (SKILL.md 1.7, step 7): %s\n' "$happened" "$SKILL"
if [ -n "$position" ]; then
  printf 'Last phase-ledger position printed before the loss: %s. Re-print the ledger with that item open and continue from it; nothing from before carries over as proof (5.1).\n' "$position"
else
  printf 'No phase-ledger position was found in the transcript. If a task was in flight, re-open its ledger from the last print you can see.\n'
fi
append_log "${cwd##*/}" "anchor | $reason | ${position:-no ledger position}"
exit 0
