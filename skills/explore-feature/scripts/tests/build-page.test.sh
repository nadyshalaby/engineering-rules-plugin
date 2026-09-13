#!/bin/bash
# Fixture tests for build-page.sh: the page is one self-contained file with every marker
# replaced, both JSON blobs embedded with < escaped and the title HTML-escaped; a missing
# input, a stale excerpts file, a broken template and a hardcoded secret in an excerpt are
# refused with nothing written, the secret never printed.
# Run: bash skills/explore-feature/scripts/tests/build-page.test.sh
# BUILD_PAGE_SH points the test at another copy of the script, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${BUILD_PAGE_SH:-$here/../build-page.sh}"
ASSETS="$here/../../assets"
# shellcheck source=fixtures/sample-repo.fixture.sh
. "$here/fixtures/sample-repo.fixture.sh"
build_sample_repo "$WORK/repo"
write_sample_trace "$WORK/repo" "$WORK/trace.json"
bash "$here/../verify-trace.sh" "$WORK/trace.json" "$WORK/excerpts.json" >/dev/null

# build <trace> <excerpts> <out> [assets]: both streams, then "exit N".
build() { bash "$SCRIPT" "$@" 2>&1; printf 'exit %s\n' "$?"; }

# refuses <name> <expected line> <args>...: the build fails with that line and writes nothing.
refuses() {
  name=$1; expected=$2; shift 2
  rm -f "$WORK/never.html"
  out=$(build "$@")
  assert_contains "$name: names the problem" "$expected" "$out"
  assert_contains "$name: exits 1" "exit 1" "$out"
  assert_eq "$name: writes nothing" absent "$([ -f "$WORK/never.html" ] && echo present || echo absent)"
}

test_the_page_is_self_contained() {
  out=$(build "$WORK/trace.json" "$WORK/excerpts.json" "$WORK/page.html")
  assert_contains "build: the wrote line" "wrote $WORK/page.html" "$out"
  assert_contains "build: exit 0" "exit 0" "$out"
  page=$(cat "$WORK/page.html")
  assert_missing "build: no marker left" "<!--" "$page"
  assert_contains "build: the title" "<title>Place an order</title>" "$page"
  assert_contains "build: the stylesheet is inlined" ".overlay[hidden]" "$page"
  assert_contains "build: page.js is inlined" "const Explore = " "$page"
  assert_contains "build: page-flow.js is inlined" "Explore.registerPanel('quiz'" "$page"
  assert_contains "build: the trace is embedded" '"entry":{"label":"POST /orders"' "$page"
  assert_contains "build: the excerpts are embedded with < escaped" "$(printf 'sql\x5cu003cOrder[]>')" "$page"
  assert_missing "build: no raw < inside the embedded json" 'sql<Order' "$page"
  assert_contains "build: page-highlight.js is inlined" "Explore.registerHighlighter(tokenize)" "$page"
  assert_eq "build: the svg namespace is the only url" "http://www.w3.org" \
    "$(grep -oE 'https?://[A-Za-z0-9.-]+' "$WORK/page.html" | sort -u | tr '\n' ' ' | sed 's/ $//')"
}

test_the_title_is_escaped() {
  jq '.title = "A <b>bold</b> & short"' "$WORK/trace.json" > "$WORK/t2.json"
  build "$WORK/t2.json" "$WORK/excerpts.json" "$WORK/page2.html" >/dev/null
  assert_contains "title: escaped" "<title>A &lt;b&gt;bold&lt;/b&gt; &amp; short</title>" "$(cat "$WORK/page2.html")"
}

test_bad_inputs_are_refused() {
  assert_contains "no argument prints the usage" "usage: build-page.sh" "$(build)"
  refuses "missing trace" "trace file does not exist" "$WORK/nope.json" "$WORK/excerpts.json" "$WORK/never.html"
  printf '{' > "$WORK/broken.json"
  refuses "broken trace" "trace file is not valid JSON" "$WORK/broken.json" "$WORK/excerpts.json" "$WORK/never.html"
  jq 'del(.excerpts[3])' "$WORK/excerpts.json" > "$WORK/stale.json"
  refuses "stale excerpts" "excerpts do not cover hop(s): h3" "$WORK/trace.json" "$WORK/stale.json" "$WORK/never.html"
  mkdir -p "$WORK/assets" && cp "$ASSETS"/page.html "$ASSETS"/page.js "$ASSETS"/page-highlight.js "$ASSETS"/page-flow.js "$WORK/assets/"
  refuses "missing template part" "template part is missing: $WORK/assets/page.css" "$WORK/trace.json" "$WORK/excerpts.json" "$WORK/never.html" "$WORK/assets"
  cp "$ASSETS/page.css" "$WORK/assets/" && printf '<!--CSS-->\n' >> "$WORK/assets/page.html"
  refuses "doubled marker" "must carry the marker <!--CSS--> exactly once, has it 2 times" "$WORK/trace.json" "$WORK/excerpts.json" "$WORK/never.html" "$WORK/assets"
}

# The planted key is the AWS documentation example, assembled in two pieces so this file never
# carries a secret-shaped token itself.
test_a_secret_in_an_excerpt_is_refused() {
  key=$(printf 'AKIA%s' IOSFODNN7EXAMPLE)
  jq --arg line "const awsKey = \"$key\"" '(.excerpts[] | select(.id == "h4") | .lines[2]) = $line' "$WORK/excerpts.json" > "$WORK/secret-ex.json"
  refuses "planted secret" "hop h4 (src/orders/services/orders.service.ts:10) has a hardcoded secret in its excerpt" "$WORK/trace.json" "$WORK/secret-ex.json" "$WORK/never.html"
  assert_missing "planted secret: the value is redacted" "$key" "$(build "$WORK/trace.json" "$WORK/secret-ex.json" "$WORK/never.html")"
  LAW_SCOUT_MD="$WORK/no-9.5.md" refuses "missing scout block" "law scout block not found at $WORK/no-9.5.md" "$WORK/trace.json" "$WORK/excerpts.json" "$WORK/never.html"
}

test_an_excerpt_id_that_is_not_a_token_is_refused() {
  jq '.excerpts += [{id: "../evil", start: 1, end: 1, lines: ["x"]}]' "$WORK/excerpts.json" > "$WORK/evil-ex.json"
  refuses "excerpt id with a path in it" "excerpt id is not a plain token: ../evil" "$WORK/trace.json" "$WORK/evil-ex.json" "$WORK/never.html"
}

test_the_page_is_self_contained
test_the_title_is_escaped
test_bad_inputs_are_refused
test_a_secret_in_an_excerpt_is_refused
test_an_excerpt_id_that_is_not_a_token_is_refused
report
