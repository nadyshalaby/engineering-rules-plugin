#!/bin/bash
# engineering-rules git guard.
# Runs on PreToolUse for the Bash tool. The git safety law (SKILL.md 1.7) names the commands
# that discard uncommitted work or rewrite shared history. This hook refuses them at the tool
# boundary with the law's own words as the reason, and asks you before the ones the law
# leaves to your say-so. Every refusal and every ask is one progress.log line.
# A command is read as its parts: every `;`, `&&`, `||`, `|`, `&`, `<`, `>`, newline,
# parenthesis and backtick outside quotes starts a new part, a `\` line continuation is joined
# first, and the body of a heredoc is skipped. The inside of a quoted string is judged too: it
# refuses when the part runs it (`sh -c`, `eval`, `xargs`, `ssh` and their kin) and asks when
# it is only text (a commit message, a grep pattern, an `echo`), so `true && git reset --hard`
# and `sh -c "git stash"` refuse, `git commit -m "see git stash"` asks, and `git commit -m
# "add -a"` and a file written with `cat <<EOF` pass. Unreadable input is no command to
# judge: exit 0, no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

# One invocation of git: an optional directory, `git`, then any global options that take a
# value (`-C dir`, `-c k=v`, `--git-dir=x`) or none (`--no-pager`), then the subcommand.
GIT='(^|[[:space:]])([^[:space:]]*/)?git[[:space:]]+((-C|-c|--git-dir|--work-tree|--namespace)(=|[[:space:]]+)[^[:space:]]+[[:space:]]+|-[^[:space:]]+[[:space:]]+)*'
ARGS='([[:space:]]+[^[:space:]]+)*[[:space:]]+'
END='([[:space:]]|$)'
SHOWN_CHARS=160

# Drops every heredoc body: from the line after `<<TAG` to the line that is the tag.
strip_heredocs() {
  awk '
    tag != "" { if ($0 == tag || (dash && $0 ~ ("^\t*" tag "$"))) tag = ""; next }
    match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
      t = substr($0, RSTART, RLENGTH); dash = (t ~ /^<<-/); sub(/^<<-?[[:space:]]*["'"'"']?/, "", t); tag = t
    }
    { print }'
}

# Joins a line that ends in a backslash with the line after it.
join_continuations() {
  awk '{ while (sub(/\\$/, "")) { if ((getline nxt) > 0) $0 = $0 " " nxt; else break } print }'
}

# One part per line, split at every separator that sits outside quotes; quotes stay in place.
split_outside_quotes() {
  awk '{
    s = $0; n = length(s); part = ""; q = ""
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (q != "") {
        part = part c
        if (c == "\\" && q == "\"") { i++; part = part substr(s, i, 1); continue }
        if (c == q) q = ""
        continue
      }
      if (c == "\"" || c == "\047") { q = c; part = part c; continue }
      if (c == "\\") { part = part c substr(s, i + 1, 1); i++; continue }
      if (index(";|&()`<>", c) > 0) { print part; part = ""; continue }
      part = part c
    }
    print part
  }'
}

# runs_quoted <part>: `run` when the part hands its quoted strings to something that executes
# them, `text` otherwise.
runs_quoted() {
  if printf '%s' "$1" | grep -qE '(^|[^[:alnum:]_./-])(sh|bash|zsh|dash|ksh|fish|eval|exec|xargs|env|sudo|doas|nohup|time|timeout|command|nice|ionice|ssh|su|script|python[0-9.]*|node|perl|ruby|php)([^[:alnum:]_./-]|$)'; then printf run; else printf text; fi
}

# segments <command>: one line per part, tab-separated: `plain`, `-` and the text outside
# quotes; or `quoted`, `run` or `text`, and one separator-split piece of a quoted string.
segments() {
  printf '%s\n' "$1" | join_continuations | strip_heredocs | split_outside_quotes | while IFS= read -r raw; do
    plain=$(printf '%s' "$raw" | sed -E "s/\"[^\"]*\"|'[^']*'/ /g")
    printf 'plain\t-\t%s\n' "$plain"
    how=$(runs_quoted "$plain")
    printf '%s' "$raw" | grep -o -E "\"[^\"]*\"|'[^']*'" | sed -E "s/^[\"']//; s/[\"']$//" | tr ';|()&`<>' '\n' \
      | while IFS= read -r piece; do printf 'quoted\t%s\t%s\n' "$how" "$piece"; done
  done
}

# A credential inside a URL or after a secret-shaped key never reaches the log or the reason.
redact() {
  sed -E 's#(://[^/:@[:space:]"'"'"']+):[^@/[:space:]"'"'"']+@#\1:[REDACTED]@#g; s#((token|password|passwd|secret|api[_-]?key|TOKEN|PASSWORD|SECRET|API_KEY)[=:])[^[:space:]]+#\1[REDACTED]#g'
}

# deny_rule <part>: prints the command the law bans outright when the part runs one.
deny_rule() {
  [[ $1 =~ ${GIT}reset${ARGS}--hard${END} ]] && { printf 'reset --hard'; return; }
  [[ $1 =~ ${GIT}checkout${ARGS}(--|[.]|[.]/[^[:space:]]*)${END} ]] && { printf 'checkout -- <path>'; return; }
  [[ $1 =~ ${GIT}restore${END} ]] && { printf 'restore'; return; }
  [[ $1 =~ ${GIT}stash${END} ]] && ! [[ $1 =~ ${GIT}stash[[:space:]]+(list|show)${END} ]] && { printf 'stash'; return; }
  [[ $1 =~ ${GIT}clean${END} ]] && ! [[ $1 =~ ${GIT}clean${ARGS}(--dry-run|-[a-zA-Z]*n[a-zA-Z]*)${END} ]] && { printf 'clean'; return; }
  [[ $1 =~ ${GIT}push${ARGS}(--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|-[a-zA-Z]*f[a-zA-Z]*|[+][^[:space:]]+)${END} ]] && { printf 'push --force'; return; }
  [[ $1 =~ ${GIT}add${ARGS}(-A|--all|[.]/?|:/|[*]|-[a-zA-Z]*A[a-zA-Z]*)${END} ]] && { printf 'add -A'; return; }
  [[ $1 =~ ${GIT}commit${ARGS}(--all|-[a-zA-Z]*a[a-zA-Z]*)${END} ]] && { printf 'commit -a'; return; }
  return 1
}

# ask_rule <part>: prints the command the law leaves to the user's say-so when the part runs one.
ask_rule() {
  [[ $1 =~ ${GIT}(commit|push|merge)${ARGS}--no-verify${END} ]] && { printf 'no-verify'; return; }
  [[ $1 =~ ${GIT}commit${ARGS}-[a-zA-Z]*n[a-zA-Z]*${END} ]] && { printf 'no-verify'; return; }
  [[ $1 =~ ${GIT}commit${ARGS}--amend${END} ]] && { printf 'amend'; return; }
  [[ $1 =~ ${GIT}branch${ARGS}(--delete|-[a-zA-Z]*[dD][a-zA-Z]*)${END} ]] && { printf 'branch delete'; return; }
  [[ $1 =~ ${GIT}worktree[[:space:]]+remove${END} ]] && { printf 'worktree remove'; return; }
  [[ $1 =~ ${GIT}push${ARGS}(--delete|-d|:[^[:space:]]+)${END} ]] && { printf 'push --delete'; return; }
  return 1
}

# emit <decision> <reason>: the PreToolUse decision, as the JSON Claude Code reads.
emit() {
  jq -cn --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
}

refuse() {
  shown=$(printf '%s' "$2" | redact | cut -c1-"$SHOWN_CHARS")
  case "$1" in
    'push --force') why="never \`git push --force\` or anything else that rewrites shared history" ;;
    'add -A'|'commit -a') why="never \`git add -A\`, \`git add .\` or \`git commit -a\`; stage explicit paths, so an .env, a secret or a large binary cannot ride along" ;;
    *) why="never \`git $1\`, nor \`stash\`, \`restore\`, \`checkout --\`, \`clean\` or \`reset --hard\`, nothing that discards uncommitted work; copy a file if you need a backup, and restore a line by editing it back" ;;
  esac
  append_log "$project" "guard | git | deny | $1 | $shown"
  emit deny "git safety (SKILL.md 1.7): $why. Refused: $shown"
}

ask() {
  shown=$(printf '%s' "$2" | redact | cut -c1-"$SHOWN_CHARS")
  case "$1" in
    no-verify) why="\`--no-verify\` only when the user explicitly said so; a hook failure points at a real issue" ;;
    amend) why="never \`--amend\` after a hook failed; the commit did not happen, so re-stage and make a new one" ;;
    *' (quoted)') why="a quoted string here spells \`git ${1% (quoted)}\`, which the law bans when it runs; yes if it is only text (a message, a pattern, a note), no if a shell will run it" ;;
    *) why='branch deletion and worktree removal happen only in Phase 6, on the option the user chose, never with --force over uncommitted changes' ;;
  esac
  note=""
  [ "$mode" = bypassPermissions ] && note=" (bypass mode)"
  append_log "$project" "guard | git | ask | $1 | $shown$note"
  emit ask "git safety (SKILL.md 1.7): $why. The user is being asked now; do not retry without their yes. Command: $shown"
}

# judge <command>: the first banned part that runs refuses; otherwise the first waivable part,
# or the first banned command that is only quoted text, asks.
judge() {
  ask_id=""
  ask_part=""
  while IFS=$'\t' read -r kind how part; do
    [ -n "${part// /}" ] || continue
    if rule=$(deny_rule "$part"); then
      if [ "$kind" = plain ] || [ "$how" = run ]; then refuse "$rule" "$part"; return; fi
      [ -n "$ask_id" ] || { ask_id="$rule (quoted)"; ask_part=$part; }
      continue
    fi
    [ -n "$ask_id" ] && continue
    rule=$(ask_rule "$part") && { ask_id=$rule; ask_part=$part; }
  done <<< "$(segments "$1")"
  [ -n "$ask_id" ] && ask "$ask_id" "$ask_part"
  return 0
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
[ "$(hook_field '.tool_name // empty')" = Bash ] || exit 0
command_text=$(hook_field '.tool_input.command // empty')
[ -n "$command_text" ] || exit 0
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
mode=$(hook_field '.permission_mode // empty')
judge "$command_text"
exit 0
