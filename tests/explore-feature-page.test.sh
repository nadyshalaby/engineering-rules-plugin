#!/bin/bash
# Guard: the explore-feature page template stays one self-contained, theme-aware page under
# the law's caps. The six markers build-page.sh replaces are each there once, no host is
# reached but the svg namespace, the scripts carry no console call, debugger, empty catch
# or innerHTML write, the stylesheet has the three theme blocks and paints the body, the skipped
# lines are explained (legend, tooltip, count, band), the capture is optional (its script
# registers nothing without one), and no template file is over 500 lines.
# Run: bash tests/explore-feature-page.test.sh
# ASSETS_DIR points the test at another copy of the template, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
ASSETS="${ASSETS_DIR:-$ROOT/skills/explore-feature/assets}"
FILE_CAP=500

# marker_counts <page.html>: "MARKER n" for each of the six markers.
marker_counts() { for m in TITLE CSS JS TRACE EXCERPTS CAPTURE; do printf '%s %s\n' "$m" "$(grep -c "<!--$m-->" "$1")"; done; }
# external_hosts <files>...: every host an http(s) url in the files names, sorted, on one line.
external_hosts() { grep -ohE 'https?://[A-Za-z0-9.-]+' "$@" | sort -u | tr '\n' ' ' | sed 's/ $//'; }
# debug_artifacts <files>...: console calls, debugger statements, empty catches, innerHTML writes.
debug_artifacts() { grep -nE 'console\.|debugger|\.catch\(\(\) => \{\}\)|innerHTML|document\.write\(' "$@" || true; }
# theme_blocks <page.css>: each block the artifact host needs, present or absent.
theme_blocks() {
  for needle in ':root {' '@media (prefers-color-scheme: dark)' ':root:not([data-theme="light"])' ':root[data-theme="dark"]'; do
    if grep -qF "$needle" "$1"; then printf 'present %s\n' "$needle"; else printf 'absent %s\n' "$needle"; fi
  done
}
# long_files <files>...: "file: N lines" for every file over the cap.
long_files() { wc -l "$@" | awk -v cap="$FILE_CAP" '$2 != "total" && $1 > cap { print $2 ": " $1 " lines" }'; }
template() { printf '%s\n' "$ASSETS/page.html" "$ASSETS/page.css" "$ASSETS/page.js" "$ASSETS/page-highlight.js" "$ASSETS/page-flow.js" "$ASSETS/page-capture.js"; }

test_markers_once() {
  assert_eq "each marker exactly once" "TITLE 1
CSS 1
JS 1
TRACE 1
EXCERPTS 1
CAPTURE 1" "$(marker_counts "$ASSETS/page.html")"
}
test_nothing_is_external() {
  assert_eq "the svg namespace is the only url" "http://www.w3.org" "$(template | xargs grep -ohE 'https?://[A-Za-z0-9.-]+' | sort -u | tr '\n' ' ' | sed 's/ $//')"
}
test_no_debug_artifacts() {
  assert_eq "no console, debugger, empty catch, innerHTML or document.write" "" "$(debug_artifacts "$ASSETS"/page.js "$ASSETS"/page-highlight.js "$ASSETS"/page-flow.js "$ASSETS"/page-capture.js)"
}
test_theme_blocks_and_body_ground() {
  assert_missing "the three theme blocks are present" "absent" "$(theme_blocks "$ASSETS/page.css")"
  assert_contains "the body paints its own ground" "body { margin: 0; background: var(--ground)" "$(cat "$ASSETS/page.css")"
}
test_files_under_the_cap() {
  assert_eq "no template file over $FILE_CAP lines" "" "$(template | xargs wc -l | awk -v cap="$FILE_CAP" '$2 != "total" && $1 > cap { print $2 ": " $1 " lines" }')"
}
test_scripts_parse() {
  if command -v node >/dev/null 2>&1; then
    assert_eq "the four scripts parse" "" "$(node --check "$ASSETS/page.js" 2>&1; node --check "$ASSETS/page-highlight.js" 2>&1; node --check "$ASSETS/page-flow.js" 2>&1; node --check "$ASSETS/page-capture.js" 2>&1)"
  else printf 'skip both scripts parse: node is not on PATH\n'; fi
}
# The checks have to be able to fail: a copy with a doubled marker, a second host, a console
# call, a missing dark block and a 501-line file is named on every count.
test_planted_defects_are_named() {
  mkdir -p "$WORK/assets" && template | xargs -I {} cp {} "$WORK/assets/"
  printf '<!--JS-->\n<script src="https://cdn.example.com/x.js"></script>\n' >> "$WORK/assets/page.html"
  printf 'console.log(1);\n' >> "$WORK/assets/page.js"
  grep -v 'data-theme="dark"' "$WORK/assets/page.css" > "$WORK/assets/css2" && mv "$WORK/assets/css2" "$WORK/assets/page.css"
  seq 1 501 > "$WORK/assets/big.css"
  assert_contains "planted doubled marker" "JS 2" "$(marker_counts "$WORK/assets/page.html")"
  assert_contains "planted second host" "https://cdn.example.com" "$(external_hosts "$WORK/assets/page.html")"
  assert_contains "planted console call" "console.log" "$(debug_artifacts "$WORK/assets/page.js")"
  assert_contains "planted missing dark block" 'absent :root[data-theme="dark"]' "$(theme_blocks "$WORK/assets/page.css")"
  assert_contains "planted long file" "big.css: 501 lines" "$(long_files "$WORK/assets/big.css")"
}

test_markers_once
test_nothing_is_external
test_no_debug_artifacts
test_theme_blocks_and_body_ground
test_files_under_the_cap
test_the_skipped_lines_are_explained() {
  assert_eq "the help overlay carries the legend" 1 "$(grep -c 'legend-skipped' "$ASSETS/page.html")"
  assert_eq "each skipped line carries the tooltip" 1 "$(grep -c "SKIPPED_TITLE = 'In the file, not run on this path'" "$ASSETS/page.js")"
  assert_eq "the pane head counts the skipped lines" 1 "$(grep -c "' not on this path'" "$ASSETS/page.js")"
  assert_eq "skipped lines sit on a band with a rail" 1 "$(grep -c 'ln.dimmed .marks { border-left: 3px dotted' "$ASSETS/page.css")"
}

test_the_theme_switch_is_wired() {
  assert_contains "the theme button is in the page" 'id="theme"' "$(cat "$ASSETS/page.html")"
  assert_contains "the script sets data-theme on the root" "setAttribute('data-theme'" "$(cat "$ASSETS/page.js")"
  assert_contains "the choice is remembered" "explore-theme" "$(cat "$ASSETS/page.js")"
  assert_missing "the choice is not swallowed on a storage error" "catch (err) {}" "$(cat "$ASSETS/page.js")"
}

test_the_capture_is_optional() {
  assert_eq "page-capture.js registers nothing without a capture" 1 "$(grep -c 'if (!capture) return;' "$ASSETS/page-capture.js")"
  assert_eq "the template carries the capture blob" 1 "$(grep -c 'id="capture-data"' "$ASSETS/page.html")"
  assert_eq "page.js exposes the two seams" 2 "$(grep -c 'const registerPaneExtra = \|const registerLineMark = ' "$ASSETS/page.js")"
  assert_eq "the keys legend reaches the ninth tab" 1 "$(grep -c '<kbd>1</kbd> to <kbd>9</kbd>' "$ASSETS/page.html")"
}

test_scripts_parse
test_planted_defects_are_named
test_the_skipped_lines_are_explained
test_the_theme_switch_is_wired
test_the_capture_is_optional
report
