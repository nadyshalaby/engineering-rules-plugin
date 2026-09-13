#!/bin/bash
# Guard: the route table in SKILL.md and the sub-command skills beside it agree (4.4). Every
# route row names a sub-command whose skill directory exists; every skill directory beside the
# main one is a route row or the helpers switch; each sub-command has the shape 4.4 promises
# (a name matching its directory, user-only invocation, a body that loads the main skill, no
# argument list, and, on the switch, the off word); and every section a route row cites is a
# file. Run: bash tests/sub-commands.test.sh
# SKILLS_DIR points the test at another skills directory, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILLS="${SKILLS_DIR:-$ROOT/skills}"
MAIN_SKILL=engineering-rules
SWITCH=helpers
REFS="$ROOT/skills/$MAIN_SKILL/references"
LINE_CAP=500

# route_rows <SKILL.md>: the route table's rows, the ones whose second column is a sub-command
# in backticks ([[:punct:]] here, so the pattern carries no backtick of its own).
route_rows() { grep -E '^\| \*\*[^|]+\*\* \| [[:punct:]]/engineering-rules:[a-z][a-z-]*[[:punct:]] \|' "$1"; }

# table_routes <SKILL.md>: the sub-command name of every route row, in table order.
table_routes() { route_rows "$1" | sed -E 's/^\| \*\*[^|]+\*\* \| [[:punct:]]\/engineering-rules:([a-z][a-z-]*)[[:punct:]].*/\1/'; }

# table_sections <SKILL.md>: the section id every route row cites, in table order.
table_sections() { route_rows "$1" | sed -E 's/.*\| ([0-9]+\.[0-9]+) \|$/\1/'; }

# skill_dirs <skills dir>: every skill directory beside the main one, sorted.
skill_dirs() { find "$1" -mindepth 1 -maxdepth 1 -type d ! -name "$MAIN_SKILL" | sed 's#.*/##' | sort; }

# front_value <SKILL.md> <key>: the frontmatter value of the key, empty when absent.
front_value() { sed -n '2,/^---$/p' "$1" | sed -n -E "s/^$2: *//p" | head -n 1; }

# shape_defects <route> <SKILL.md>: one line per departure from the shape 4.4 promises.
shape_defects() {
  [ "$(front_value "$2" name)" = "$1" ] || printf '%s: name is not %s\n' "$1" "$1"
  [ "$(front_value "$2" disable-model-invocation)" = true ] || printf '%s: model invocation is not disabled\n' "$1"
  grep -q -F "$MAIN_SKILL:$MAIN_SKILL" "$2" || printf '%s: does not load the main skill\n' "$1"
  [ -z "$(front_value "$2" arguments)" ] || printf '%s: takes an argument list\n' "$1"
  lines=$(wc -l < "$2" | tr -d ' ')
  [ "$lines" -le "$LINE_CAP" ] || printf '%s: %s lines\n' "$1" "$lines"
}

# switch_defects <skills dir>: the helpers switch's departures from the shape 4.4 promises.
switch_defects() {
  file="$1/$SWITCH/SKILL.md"
  [ -f "$file" ] || { printf '%s: no skill directory\n' "$SWITCH"; return; }
  shape_defects "$SWITCH" "$file"
  grep -q -w off "$file" || printf '%s: never reads off\n' "$SWITCH"
}

# missing_dirs <skills dir>: every table route with no skill directory.
missing_dirs() {
  for route in $(table_routes "$1/$MAIN_SKILL/SKILL.md"); do
    [ -f "$1/$route/SKILL.md" ] || printf '%s\n' "$route"
  done
}

# stray_dirs <skills dir>: every skill directory that is neither a table route nor the switch.
stray_dirs() { comm -23 <(skill_dirs "$1") <({ table_routes "$1/$MAIN_SKILL/SKILL.md"; printf '%s\n' "$SWITCH"; } | sort); }

# all_defects <skills dir>: the shape defects of every sub-command that is present.
all_defects() {
  for route in $(table_routes "$1/$MAIN_SKILL/SKILL.md"); do
    [ -f "$1/$route/SKILL.md" ] && shape_defects "$route" "$1/$route/SKILL.md"
  done
  return 0
}

# missing_sections <SKILL.md>: every cited section with no reference file.
missing_sections() {
  for section in $(table_sections "$1"); do
    ls "$REFS"/*/"$section"-*.md >/dev/null 2>&1 || printf '%s\n' "$section"
  done
}

test_every_route_has_a_sub_command() {
  routes=$(table_routes "$SKILLS/$MAIN_SKILL/SKILL.md" | grep -c .)
  missing=$(missing_dirs "$SKILLS")
  assert_contains "every route row has a skill directory ($routes routes)" "<none>" "${missing:-<none>}"
}

test_every_skill_dir_is_a_route() {
  stray=$(stray_dirs "$SKILLS")
  assert_contains "every skill directory is a route row" "<none>" "${stray:-<none>}"
}

test_every_sub_command_has_the_shape() {
  defects=$(all_defects "$SKILLS")
  assert_contains "every sub-command has the shape 4.4 promises" "<none>" "${defects:-<none>}"
}

test_every_cited_section_exists() {
  missing=$(missing_sections "$SKILLS/$MAIN_SKILL/SKILL.md")
  assert_contains "every section a route row cites is a file" "<none>" "${missing:-<none>}"
}

test_the_switch_has_the_shape() {
  defects=$(switch_defects "$SKILLS")
  assert_contains "the helpers switch has the shape 4.4 promises" "<none>" "${defects:-<none>}"
}

# The checks have to be able to fail: a route with no directory, a directory with no route, a
# sub-command that takes an argument list, a switch with no off word and a cited section with
# no file are all named.
test_planted_breaches_are_named() {
  mkdir -p "$WORK/skills/$MAIN_SKILL" "$WORK/skills/ghost" "$WORK/skills/quick" "$WORK/skills/$SWITCH"
  cp "$SKILLS/$MAIN_SKILL/SKILL.md" "$WORK/skills/$MAIN_SKILL/SKILL.md"
  printf -- '---\nname: quick\narguments: [mode]\ndisable-model-invocation: true\n---\nLoads %s:%s.\n' "$MAIN_SKILL" "$MAIN_SKILL" > "$WORK/skills/quick/SKILL.md"
  printf -- '---\nname: %s\ndisable-model-invocation: true\n---\nLoads %s:%s.\n' "$SWITCH" "$MAIN_SKILL" "$MAIN_SKILL" > "$WORK/skills/$SWITCH/SKILL.md"
  assert_contains "a route with no directory is named" "full" "$(missing_dirs "$WORK/skills")"
  assert_contains "a directory with no route is named" "ghost" "$(stray_dirs "$WORK/skills")"
  assert_missing "and the switch is not" "$SWITCH" "$(stray_dirs "$WORK/skills")"
  assert_contains "a sub-command that takes an argument list is named" "quick: takes an argument list" "$(all_defects "$WORK/skills")"
  assert_contains "a switch with no off word is named" "$SWITCH: never reads off" "$(switch_defects "$WORK/skills")"
  tick=$(printf '\140')
  printf '| **Ghost** | %s/engineering-rules:ghost%s | Nothing. | 99.9 |\n' "$tick" "$tick" > "$WORK/table.md"
  assert_contains "a cited section with no file is named" "99.9" "$(missing_sections "$WORK/table.md")"
}

test_every_route_has_a_sub_command
test_every_skill_dir_is_a_route
test_every_sub_command_has_the_shape
test_every_cited_section_exists
test_the_switch_has_the_shape
test_planted_breaches_are_named
report
