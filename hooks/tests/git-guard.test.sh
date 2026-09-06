#!/bin/bash
# Fixture tests for git-guard.sh. Run: bash hooks/tests/git-guard.test.sh
# Each case feeds the guard one Bash tool call and reads the decision it printed; the log
# goes to a scratch config dir. GIT_GUARD_SH points the test at another copy of the script,
# for a watched failure; the copy needs hook-input.sh and progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${GIT_GUARD_SH:-$here/../git-guard.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
last_reason=""

# decide <command> [permission mode]: the decision word, `allow` when the guard printed nothing.
decide() {
  out=$(jq -cn --arg c "$1" --arg m "${2:-auto}" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:"/tmp/proj",permission_mode:$m,tool_input:{command:$c}}' | bash "$SCRIPT")
  if [ -z "$out" ]; then last_reason=""; printf 'allow'; return; fi
  last_reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unreadable"'
}

# expect <deny|ask|allow> <label> <command> [mode]
expect() {
  assert_contains "$1: $2" "$1" "$(decide "$3" "${4:-}")"
}

test_banned_commands_are_denied() {
  expect deny 'reset --hard'                'git reset --hard'
  expect deny 'reset --hard behind &&'       'true && git reset --hard HEAD~1'
  expect deny 'checkout -- .'                'git checkout -- .'
  expect deny 'checkout ref -- path'         'git checkout HEAD~1 -- src/a.ts'
  expect deny 'checkout .'                   'git checkout .'
  expect deny 'restore, even --staged'       'git restore --staged x'
  expect deny 'stash'                        'git stash'
  expect deny 'stash push'                   'git stash push -m wip'
  expect deny 'clean -fd'                    'git clean -fd'
  expect deny 'push --force'                 'git push --force origin main'
  expect deny 'push -f'                      'git push -f'
  expect deny 'push --force-with-lease'      'git push --force-with-lease=main'
  expect deny 'push with a + refspec'        'git push origin +main'
  expect deny 'add -A'                       'git add -A'
  expect deny 'add .'                        'git add .'
  expect deny 'add --all'                    'git add --all'
  expect deny 'commit -a'                    'git commit -a -m x'
  expect deny 'commit -am'                   'git commit -am "x"'
}

test_evasions_are_seen() {
  expect deny 'inside sh -c quotes'          'sh -c "git clean -fd"'
  expect deny 'inside a subshell'            "\$(git reset --hard)"
  expect deny 'behind a pipe'                'echo x | git stash'
  expect deny 'on a second line'             $'ls\ngit reset --hard'
  expect deny 'git by absolute path'         '/usr/bin/git reset --hard'
  expect deny 'git -C dir'                   'git -C /tmp/x reset --hard'
  expect deny 'git -c key=value'             'git -c core.pager=cat stash'
  expect deny 'the heredoc line itself'      $'cat <<EOT > f; git stash\nx\nEOT'
  expect deny 'deny beats ask'               'git commit --amend -a'
}

test_safe_commands_are_allowed() {
  expect allow 'reset --soft'                'git reset --soft HEAD~1'
  expect allow 'reset a path'                'git reset -- hooks/x.sh'
  expect allow 'checkout -b'                 'git checkout -b feat/x'
  expect allow 'checkout a branch'           'git checkout main'
  expect allow 'stash list'                  'git stash list'
  expect allow 'stash show'                  'git stash show -p'
  expect allow 'clean dry run'               'git clean -fdn'
  expect allow 'push -u'                     'git push -u origin feat/x'
  expect allow 'push --follow-tags'          'git push --follow-tags'
  expect allow 'add -p'                      'git add -p hooks/x.sh'
  expect allow 'add explicit paths'          'git add hooks/a.sh hooks/b.sh'
  expect allow '-a inside a commit message'  'git commit -m "add -a flag to the cli"'
  expect allow 'commit --author'             'git commit --author="A <a@b.c>" -m x'
  expect allow 'commit -S'                   'git commit -S -m x'
  expect allow 'a heredoc body'              $'cat > f.sh <<\'EOT\'\ngit reset --hard\nEOT\necho done'
  expect allow 'branch -vv'                  'git branch -vv'
  expect allow 'worktree list'               'git worktree list'
  expect allow 'a plain command'             'ls -la && bun test'
}

test_shapes_a_model_writes_are_seen() {
  expect deny  'a line continuation'                $'git reset \\\n  --hard'
  expect deny  'a glued redirect'                   'git stash>/dev/null'
  expect deny  'a glued redirect with 2>&1'         'git reset --hard>/dev/null 2>&1'
  expect deny  'add ./'                             'git add ./'
  expect deny  'add :/'                             'git add :/'
  expect deny  'a bare add *'                       'git add *'
  expect allow 'add a glob with a suffix'           'git add *.md'
  expect allow 'a redirect on a harmless command'   'ls 2>&1'
  expect deny  'eval of a quoted string'            'eval "git reset --hard"'
  expect deny  'xargs into sh -c'                   'find . -name x | xargs -I{} sh -c "git clean -fd"'
  expect deny  'a quoted string split inside'       'sh -c "git stash; ls"'
}

test_quoted_text_asks_instead_of_refusing() {
  expect ask   'a commit message naming the ban'    'git commit -m "feat: the guard refuses git reset --hard"'
  decide 'git commit -m "feat: the guard refuses git reset --hard"' >/dev/null
  assert_contains "the ask names the quoted command" "spells \`git reset --hard\`" "$last_reason"
  expect ask   'a grep for the pattern'             "grep -rn 'git stash' hooks/"
  expect ask   'an echo of the words'               'echo "never git stash"'
  assert_contains "a quoted hit is logged with the quoted piece" " proj | guard | git | ask | stash (quoted) | never git stash" "$(tail -n 1 "$LOG")"
  expect deny  'text in one part, a run in another' 'echo "see git stash" && git reset --hard'
}

test_waivable_commands_ask() {
  expect ask 'commit --no-verify'            'git commit --no-verify -m x'
  expect ask 'commit -n'                     'git commit -n -m x'
  expect ask 'push --no-verify'              'git push --no-verify'
  expect ask 'commit --amend'                'git commit --amend --no-edit'
  expect ask 'branch -D'                     'git branch -D feat/x'
  expect ask 'worktree remove'               'git worktree remove .claude/worktrees/x'
  expect ask 'push --delete'                 'git push origin --delete feat/x'
  expect ask 'push :refspec'                 'git push origin :feat/x'
}

test_reasons_quote_the_law() {
  decide 'git reset --hard' >/dev/null
  assert_contains "a deny cites 1.7" "git safety (SKILL.md 1.7)" "$last_reason"
  assert_contains "a deny quotes the banned command" "never \`git reset --hard\`" "$last_reason"
  decide 'git commit --no-verify -m x' >/dev/null
  assert_contains "an ask says the user decides" "The user is being asked now" "$last_reason"
  decide 'git push --force https://user:hunter2@example.com/r.git' >/dev/null
  assert_contains "a credential is redacted in the reason" "user:[REDACTED]@" "$last_reason"
  assert_missing "and never shown" "hunter2" "$last_reason"
}

test_log_lines() {
  assert_contains "a deny is logged with its rule and command" " proj | guard | git | deny | reset --hard | git reset --hard" "$(cat "$LOG")"
  assert_contains "an ask is logged" " proj | guard | git | ask | no-verify | git commit --no-verify -m x" "$(cat "$LOG")"
  assert_missing "the log never carries the credential" "hunter2" "$(cat "$LOG")"
  decide 'git commit --amend' bypassPermissions >/dev/null
  assert_contains "an ask in bypass mode marks the mode" "ask | amend | git commit --amend (bypass mode)" "$(tail -n 1 "$LOG")"
  before=$(wc -l < "$LOG" | tr -d ' ')
  decide 'ls' >/dev/null
  assert_contains "an allow writes no log line" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_unreadable_input_is_no_opinion() {
  out=$(printf 'not json' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints no decision" "permissionDecision" "$out"
  out=$(printf '' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "empty stdin exits 0 with no output" "exit=0" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:"/tmp/proj",tool_input:{command:"git reset --hard"}}' | bash "$SCRIPT")
  assert_missing "another tool's event is not judged" "permissionDecision" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:"/tmp/proj",tool_input:{}}' | bash "$SCRIPT")
  assert_missing "a call with no command is not judged" "permissionDecision" "$out"
}

test_banned_commands_are_denied
test_evasions_are_seen
test_safe_commands_are_allowed
test_shapes_a_model_writes_are_seen
test_quoted_text_asks_instead_of_refusing
test_waivable_commands_ask
test_reasons_quote_the_law
test_log_lines
test_unreadable_input_is_no_opinion
report
