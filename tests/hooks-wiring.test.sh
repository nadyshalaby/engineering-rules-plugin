#!/bin/bash
# Guard: every hook hooks.json runs is a script that exists beside it, every command reaches
# it through CLAUDE_PLUGIN_ROOT, and every hook script that reads Claude Code's event input
# is wired to an event (the status line is wired from settings.json, by design, so it does
# not read events). Run: bash tests/hooks-wiring.test.sh
# HOOKS_JSON points the test at another manifest, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
HOOKS_JSON="${HOOKS_JSON:-$ROOT/hooks/hooks.json}"

# wired_commands <manifest>: every command string in it, one per line.
wired_commands() { jq -r '.hooks[][] | .hooks[].command' "$1"; }

# wired_scripts <manifest>: the script names those commands run, sorted, once each.
wired_scripts() { wired_commands "$1" | sed -E 's#.*/hooks/([^"]+)".*#\1#' | sort -u; }

# event_scripts: the hook scripts that read an event on stdin, sorted.
event_scripts() { grep -l 'read_hook_input ||' "$ROOT"/hooks/*.sh | sed 's#.*/##' | sort -u; }

test_every_wired_script_exists() {
  for script in $(wired_scripts "$HOOKS_JSON"); do
    if [ -f "$ROOT/hooks/$script" ]; then present=present; else present=missing; fi
    assert_contains "wired script exists: $script" present "$present"
  done
}

test_every_event_script_is_wired() {
  missing=$(comm -23 <(event_scripts) <(wired_scripts "$HOOKS_JSON"))
  assert_contains "every event-reading script is wired" "<none>" "${missing:-<none>}"
}

test_every_command_goes_through_the_plugin_root() {
  stray=$(wired_commands "$HOOKS_JSON" | grep -v -F "bash \"\${CLAUDE_PLUGIN_ROOT}/hooks/")
  assert_contains "every command runs bash on a plugin-root path" "<none>" "${stray:-<none>}"
}

test_the_eight_events_are_wired() {
  events=$(jq -r '.hooks | keys[]' "$HOOKS_JSON" | sort | tr '\n' ' ')
  assert_contains "the eight events" "Notification PostToolUse PreToolUse SessionStart Stop StopFailure SubagentStart SubagentStop " "$events"
}

# The checks have to be able to fail: a missing script and an unwired script are both named.
test_a_planted_missing_script_is_named() {
  jq '.hooks.Stop[0].hooks[0].command = "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/no-such-hook.sh\""' "$HOOKS_JSON" > "$WORK/planted.json"
  named=$(for script in $(wired_scripts "$WORK/planted.json"); do [ -f "$ROOT/hooks/$script" ] || printf '%s' "$script"; done)
  assert_contains "a planted missing script is named" "no-such-hook.sh" "$named"
  ghost=$(comm -23 <(printf 'ghost-hook.sh\n') <(wired_scripts "$HOOKS_JSON"))
  assert_contains "a planted unwired script is named" "ghost-hook.sh" "$ghost"
}

test_every_wired_script_exists
test_every_event_script_is_wired
test_every_command_goes_through_the_plugin_root
test_the_eight_events_are_wired
test_a_planted_missing_script_is_named
report
