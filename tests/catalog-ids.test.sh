#!/bin/bash
# Guard: every id cited anywhere in the skill resolves to a row. The perf.*, sec.*, test.* and
# style.* catalog schemes are the spine every finding, scout row and review prompt keys on, and
# the coarse rule ids (ban.*, cap.*, clean.* and the rest) are the audit rule catalog's (16.4);
# a renamed or mistyped id fails silently everywhere it is cited.
# Run: bash tests/catalog-ids.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILL="$ROOT/skills/engineering-rules"
CATALOGS="$SKILL/references/03-catalogs"
RULES="$SKILL/references/16-other-routes/16.4-the-audit-rule-catalog.md"

# cited_ids <dir>: every distinct <family>.<domain>.<slug> written in a markdown file under
# the directory, the catalogs themselves included, so a row citing a sibling is checked too.
cited_ids() {
  grep -rhoE '(^|[^[:alnum:]_.-])(perf|sec|test|style)\.[a-z0-9-]+\.[a-z0-9-]+' --include='*.md' "$1" \
    | sed -E 's/^[^a-z]*//' | sort -u
}

# catalog_rows: every id that heads a row in one of the four catalogs.
catalog_rows() {
  grep -hoE '^\| (perf|sec|test|style)\.[a-z0-9-]+\.[a-z0-9-]+ \|' "$CATALOGS"/3.*.md \
    | sed -E 's/^\| //; s/ \|$//' | sort -u
}

# dangling_ids <dir>: the cited ids that head no catalog row, one per line, one set difference.
dangling_ids() {
  comm -23 <(cited_ids "$1") <(catalog_rows)
}

# cited_rule_ids <dir>: every distinct two-segment <family>.<slug> written under the directory.
# A third segment, or a trailing `.*`, marks a catalog id, which the check above owns; Jest's
# own `test.only` / `test.skip` / `test.todo` / `test.each` share the prefix and are not rules.
cited_rule_ids() {
  grep -rhoE '(^|[^[:alnum:]_.-])(ban|cap|clean|scope|folder|solid|style|sec|perf|test)\.[a-z0-9-]+(\.[a-z0-9*-]+)*' --include='*.md' "$1" \
    | sed -E 's/^[^a-z]*//' | grep -vE '\..*\.' | grep -vxE 'test\.(only|skip|todo|each|concurrent|failing)' | sort -u
}

# rule_rows: every id that heads a row in the audit rule catalog.
rule_rows() {
  grep -hoE '^\| [[:punct:]][a-z]+\.[a-z0-9-]+[[:punct:]] \|' "$RULES" | sed -E 's/^\| [[:punct:]]//; s/[[:punct:]] \|$//' | sort -u
}

# dangling_rule_ids <dir>: the cited rule ids with no row in 16.4.
dangling_rule_ids() {
  comm -23 <(cited_rule_ids "$1") <(rule_rows)
}

test_every_cited_id_has_a_row() {
  count=$((count + 1))
  cited=$(cited_ids "$SKILL" | grep -c .)
  dangling=$(dangling_ids "$SKILL")
  if [ -z "$dangling" ] && [ "$cited" -gt 0 ]; then
    printf 'ok   every cited catalog id has a row (%s ids checked)\n' "$cited"; return
  fi
  printf 'FAIL dangling catalog ids (%s ids checked):\n%s\n' "$cited" "${dangling:-<none, but zero ids were cited>}"
  failures=$((failures + 1))
}

# The check has to be able to fail: a planted citation of a row that does not exist is named.
test_a_planted_dangling_id_is_named() {
  count=$((count + 1))
  mkdir -p "$WORK/planted"
  printf 'Cite style.naming.no-such-row and perf.data.n-plus-one here.\n' > "$WORK/planted/doc.md"
  found=$(dangling_ids "$WORK/planted")
  if [ "$found" = "style.naming.no-such-row" ]; then
    printf 'ok   a planted dangling id is named, and a real one is not\n'; return
  fi
  printf 'FAIL planted dangling id: wanted style.naming.no-such-row alone, got: %s\n' "$found"
  failures=$((failures + 1))
}

test_every_cited_rule_id_has_a_row() {
  count=$((count + 1))
  cited=$(cited_rule_ids "$SKILL" | grep -c .)
  dangling=$(dangling_rule_ids "$SKILL")
  if [ -z "$dangling" ] && [ "$cited" -gt 0 ]; then
    printf 'ok   every cited rule id has a row in 16.4 (%s ids checked)\n' "$cited"; return
  fi
  printf 'FAIL dangling rule ids (%s ids checked):\n%s\n' "$cited" "${dangling:-<none, but zero ids were cited>}"
  failures=$((failures + 1))
}

test_a_planted_dangling_rule_id_is_named() {
  count=$((count + 1))
  mkdir -p "$WORK/planted-rule"
  printf 'Cite ban.no-such-rule, ban.empty-catch and style.naming.magic-literal here.\n' > "$WORK/planted-rule/doc.md"
  found=$(dangling_rule_ids "$WORK/planted-rule")
  if [ "$found" = "ban.no-such-rule" ]; then
    printf 'ok   a planted dangling rule id is named, and a real one and a catalog id are not\n'; return
  fi
  printf 'FAIL planted dangling rule id: wanted ban.no-such-rule alone, got: %s\n' "$found"
  failures=$((failures + 1))
}

test_every_cited_id_has_a_row
test_a_planted_dangling_id_is_named
test_every_cited_rule_id_has_a_row
test_a_planted_dangling_rule_id_is_named
report
