#!/bin/bash
# engineering-rules edit guard.
# Runs on PreToolUse for Edit, Write, MultiEdit and NotebookEdit. The bans in SKILL.md 1.1
# are zero tolerance in production code. This hook runs the law scout's own shell block (9.5)
# over the text an edit would write, and refuses the edit when it ADDS a finding under a rule
# a grep can judge: suppressions and coverage-ignore markers, empty catches, bare Error throws
# in domain-role files, focused and unowned skipped tests, debug artifacts, ownerless debt
# markers, removed-code comments and hardcoded secrets. What is already in the file never
# blocks: the block runs over the text being replaced too, and only a count that grows
# refuses. The judgment rows (non-null `!`, inline types, the file cap) stay with the scout,
# and 9.5 stays the one source of the patterns; this file holds none of them.
# Exempt, by the law's own definitions: prose, generated files and migrations; test files,
# except for the suppression, test-hygiene and secret rows, which bind there too; and the
# secret rows on a path git ignores. Unreadable input, a tool that is not an edit, or a 9.5
# that is missing or fails to run is nothing to judge: exit 0 with no output, plus one log
# line saying so in the last two cases.
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

LAW_SCOUT="${CLAUDE_PLUGIN_ROOT:-$(cd "$here/.." && pwd)}/skills/engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md"
HOOK_RULES='ban.suppression|ban.empty-catch|ban.bare-error|test.focused|test.skipped|clean.debug-artifact|clean.debt-marker|clean.removed-comment|sec.hardcoded-secret'
TEST_RULES='ban.suppression|test.focused|test.skipped|sec.hardcoded-secret'
EVIDENCE_CHARS=120

# domain_role <path>: yes when the file name marks domain code, where the bare-error ban applies.
domain_role() {
  case "${1##*/}" in
    *.service.*|*.use-case.*|*.usecase.*|*.repository.*|*.validator.*|*.job.*|*.worker.*) printf yes ;;
    *) printf no ;;
  esac
}

# git_ignored <path>: yes when git ignores the file, so a secret in it never reaches history.
git_ignored() {
  dir=${1%/*}
  [ "$dir" = "$1" ] && dir=.
  if git -C "$dir" check-ignore -q "$1" 2>/dev/null; then printf yes; else printf no; fi
}

# The scout's block, minus the diff line that would rebuild the path list.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$LAW_SCOUT" | grep -v '^git diff -z'
}

# The text the edit writes goes to $W/new.txt, the text it replaces to $W/old.txt. A Write
# replaces the whole file, so its old text is the file; a notebook cell has no old text here.
write_texts() {
  case "$tool" in
    Edit) hook_field '.tool_input.new_string // ""' > "$W/new.txt"; hook_field '.tool_input.old_string // ""' > "$W/old.txt" ;;
    MultiEdit) hook_field '[.tool_input.edits[]?.new_string // ""] | join("\n")' > "$W/new.txt"; hook_field '[.tool_input.edits[]?.old_string // ""] | join("\n")' > "$W/old.txt" ;;
    Write) hook_field '.tool_input.content // ""' > "$W/new.txt"; if [ -f "$path" ]; then cat "$path" > "$W/old.txt"; else : > "$W/old.txt"; fi ;;
    NotebookEdit) hook_field '.tool_input.new_source // ""' > "$W/new.txt"; : > "$W/old.txt" ;;
  esac
}

# keep_applicable: the finding lines the law enforces on this kind of file.
keep_applicable() {
  case "$kind" in
    test) grep -E "^($TEST_RULES) " | grep -v -F '@ts-expect-error' ;;
    *) cat ;;
  esac | awk -v domain="$domain" -v ignored="$ignored" '
      /^ban\.bare-error / && domain != "yes" { next }
      /^sec\.hardcoded-secret / && ignored == "yes" { next }
      { print }'
}

# scan <new|old>: the block's finding lines for that side, under the file's own relative path
# so the rows keyed to a role or a test path see the name the real file has. A block that
# fails to run judges nothing, and says so in the log rather than passing in silence.
scan() {
  side="$W/$1"
  case "$rel" in */*) mkdir -p "$side/${rel%/*}" ;; *) mkdir -p "$side" ;; esac
  cp "$W/$1.txt" "$side/$rel"
  printf '%s\0' "$rel" > "$W/$1.paths"
  (cd "$side" && SCOUT_PATHS="$W/$1.paths" bash "$W/block.sh" > "$W/$1.out" 2> "$W/$1.err")
  status=$?
  if [ "$status" -ne 0 ] || [ -s "$W/$1.err" ]; then
    append_log "$project" "guard | edit | skipped | 9.5 block failed on the $1 text (exit $status): $(head -n 1 "$W/$1.err" | cut -c1-120)"
  fi
  grep -E "^($HOOK_RULES) " "$W/$1.out" | keep_applicable
}

# why <rule>: the law's own words for the rule, quoted in the refusal.
why() {
  case "$1" in
    ban.suppression) printf 'zero lint, type or coverage suppressions; the ban holds in test files too, whose sole exception is @ts-expect-error over deliberately invalid input with a comment saying why' ;;
    ban.empty-catch) printf 'zero empty catches, a comment-only body, a promise .catch that swallows, or an except: pass included' ;;
    ban.bare-error) printf 'zero bare Error throws in domain code; throw a domain-specific exception subclass' ;;
    test.focused) printf 'zero focused tests committed; a focused test silently drops the rest of the suite' ;;
    test.skipped) printf 'a skipped test carries a ticket or an owner on the same line' ;;
    clean.debug-artifact) printf 'zero debug artifacts; no debugger, and no console.* in domain code, which logs through the project logger' ;;
    clean.debt-marker) printf 'a TODO with no owner or ticket is refused on sight' ;;
    clean.removed-comment) printf 'a comment marking deleted code is refused on sight' ;;
    sec.hardcoded-secret) printf 'zero hardcoded secrets; the matched value is redacted here and must not be written' ;;
    *) printf 'zero tolerance for %s in production code' "$1" ;;
  esac
}

# emit <decision> <reason>: the PreToolUse decision, as the JSON Claude Code reads.
emit() {
  jq -cn --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
}

# refuse <rule> <finding line>: the finding is `rule path:line:evidence`, the block's own shape.
refuse() {
  detail=${2#"$1 $rel:"}
  line_no=${detail%%:*}
  evidence=$(printf '%s' "${detail#*:}" | cut -c1-"$EVIDENCE_CHARS")
  append_log "$project" "guard | edit | deny | $1 | $path | line $line_no of the new text"
  emit deny "engineering law (SKILL.md 1.1): $(why "$1"), and this edit adds one. $1 at line $line_no of the new text: $evidence. Remove it before writing; the judgment is the law scout's (9.5), run over the edit."
}

# first_growth: reads `new <finding>` and `old <finding>` lines; prints the first new finding
# whose rule has more lines on the new side than on the old, in one pass.
first_growth() {
  awk '
    $1 == "new" { n[$2]++; if (!($2 in first)) { first[$2] = substr($0, 5); order[++k] = $2 } }
    $1 == "old" { o[$2]++ }
    END { for (i = 1; i <= k; i++) if (n[order[i]] > o[order[i]]) { print first[order[i]]; exit } }'
}

# judge: refuse on the first rule whose count grows from the old text to the new.
judge() {
  new_findings=$(scan new)
  [ -n "$new_findings" ] || return 0
  old_findings=$(scan old)
  grown=$({ printf '%s\n' "$new_findings" | sed 's/^/new /'; printf '%s\n' "$old_findings" | sed 's/^/old /'; } | first_growth)
  [ -n "$grown" ] || return 0
  refuse "${grown%% *}" "$grown"
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
tool=$(hook_field '.tool_name // empty')
case "$tool" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
rel=$(relative_path "$path" "$cwd")
kind=$(path_kind "$rel")
case "$kind" in prose|generated) exit 0 ;; esac
[ -f "$LAW_SCOUT" ] || { append_log "$project" "guard | edit | skipped | 9.5 not found at $LAW_SCOUT"; exit 0; }
W=$(mktemp -d "${TMPDIR:-/tmp}/edit-guard.XXXXXX")
trap 'rm -rf "$W"' EXIT
domain=$(domain_role "$rel")
ignored=$(git_ignored "$path")
extract_block > "$W/block.sh"
write_texts
judge
exit 0
