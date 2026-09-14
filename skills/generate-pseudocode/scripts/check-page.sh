#!/bin/bash
# generate-pseudocode: the pre-publish check over one finished page.
# Usage: bash check-page.sh <page.html>
# Names each defect on its own DEFECT line and exits 1 when there is one; prints the counts
# either way. Everything here is a grep over the file, so it runs anywhere bash 3.2 does.
set -u

page=${1:?usage: check-page.sh <page.html>}
[ -f "$page" ] || { printf 'no such file: %s\n' "$page"; exit 1; }
fail=0
defect() { fail=1; printf 'DEFECT %s\n' "$*"; }
note() { printf 'note   %s\n' "$*"; }
count() { printf 'count  %s\n' "$*"; }
# lines <text>: the text's lines, or nothing when the text is empty.
lines() { printf '%s\n' "$1" | grep . || true; }
# attr_values <attribute> <pattern>: the sorted unique values of the attribute in the page.
attr_values() { grep -o "$1=\"$2\"" "$page" | sed "s/^$1=\"//; s/\"\$//" | sort -u; }

# 1. every href="#x" resolves to an id="x" on the page
refs=$(attr_values href '#[A-Za-z0-9_-]*' | sed 's/^#//')
ids=$(attr_values id '[A-Za-z0-9_-]*')
dangling=$(comm -23 <(lines "$refs") <(lines "$ids"))
[ -z "$dangling" ] || defect "links to ids that do not exist: $(printf '%s' "$dangling" | tr '\n' ' ')"

# 2. every shaded phrase has a note, and every note has a phrase
used=$(attr_values data-i '[A-Za-z0-9_-]*')
defined=$(awk '/^const ANN = \{/ { on = 1; next } on && /^\};/ { exit } on' "$page" \
  | grep -oE '^ *"?[A-Za-z0-9_-]+"? *: *\{' | sed -E 's/^ *"?([A-Za-z0-9_-]+)"? *: *\{/\1/' | sort -u)
missing=$(comm -23 <(lines "$used") <(lines "$defined"))
unused=$(comm -13 <(lines "$used") <(lines "$defined"))
[ -z "$missing" ] || defect "shaded phrases with no note in ANN: $(printf '%s' "$missing" | tr '\n' ' ')"
[ -z "$unused" ] || note "notes with no phrase (harmless, but check the key): $(printf '%s' "$unused" | tr '\n' ' ')"
printf '%s\n' "$used" | grep -qx demo || defect "the demo note is not wired to the masthead button"

# 3. the file is page content, not a document
! grep -qiE '<!DOCTYPE|<html[ >]|<head[ >]|<body[ >]' "$page" || defect "the file carries a doctype, html, head or body tag; the host wraps the page"
head -c 8192 "$page" | grep -q '<title>' || defect "no <title> in the first 8KB"

# 4. the only resource loaded from outside is the Google Fonts stylesheet
foreign=$(grep -oE '(src|href)="https?://[^"]+"' "$page" | grep -vE '^href="https://fonts\.(googleapis|gstatic)\.com(/[^"]*)?"$' || true)
[ -z "$foreign" ] || defect "resources loaded from outside the page: $(printf '%s' "$foreign" | tr '\n' ' ')"

# 5. the three theme blocks and the painted body ground
for needle in ':root {' '@media (prefers-color-scheme: dark)' ':root:not([data-theme="light"])' ':root[data-theme="dark"]' 'background: var(--ground)'; do
  grep -qF "$needle" "$page" || defect "theme: missing $needle"
done

# 6. every routine cites its source, every part has a lede, every finding rests on a link
routines=$(grep -c 'class="routine"' "$page")
sources=$(grep -c 'class="src"' "$page")
[ "$routines" -eq "$sources" ] || defect "$routines routines but $sources .src citations"
parts=$(grep -c 'class="part"' "$page")
ledes=$(grep -c 'class="lede"' "$page")
[ "$parts" -eq "$ledes" ] || defect "$parts part sections but $ledes ledes"
unlinked=$(awk '/<article class="fin">/ { n++; inb = 1; has = 0 } inb && /class="ref"/ { has = 1 } inb && /<\/article>/ { if (!has) print n; inb = 0 }' "$page")
[ -z "$unlinked" ] || defect "findings with no link to the line they rest on (by position): $(printf '%s' "$unlinked" | tr '\n' ' ')"
grep -q 'data-i="demo"' "$page" || defect "the masthead demo button is gone"

# 7. the script parses, when node is here to say so
if command -v node >/dev/null 2>&1; then
  work=$(mktemp -d "${TMPDIR:-/tmp}/check-page.XXXXXX")
  awk '/^<script>$/ { on = 1; next } /^<\/script>$/ { on = 0 } on' "$page" > "$work/page.js"
  node --check "$work/page.js" 2>/dev/null || defect "the page script does not parse (node --check)"
  rm -rf "$work"
fi

# 8. the counts, for the density rule and the line-length rule (Step 3 asks for lines under 78)
count "routines: $routines"
count "shaded phrases (notes): $(grep -o 'class="an"' "$page" | wc -l | tr -d ' ')"
count "findings: $(grep -c '<article class="fin">' "$page")"
count "cross-reference links: $(grep -o 'class="ref"' "$page" | wc -l | tr -d ' ')"
count "listing lines over 78 characters: $(awk '/<pre>/ { p = 1 } p { line = $0; gsub(/<[^>]*>/, "", line); gsub(/&[#A-Za-z0-9]+;/, "x", line); if (length(line) > 78) c++ } /<\/pre>/ { p = 0 } END { print c + 0 }' "$page")"
count "file lines: $(wc -l < "$page" | tr -d ' ') (a finished page is over 500; that is the deliberate shape)"

# 9. the mechanics are the kit's, verbatim: a page built from a kit that has since changed
#    differs here. A \uXXXX escape and the character it names read the same.
kit="$(cd "$(dirname "$0")/.." && pwd)/references/page-kit.html"
mech() {
  awk '/keep verbatim from here/ { on = 1 } on && /^<\/script>$/ { exit } on' "$1" \
    | python3 -c 'import re, sys; sys.stdout.write(re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), sys.stdin.read()))'
}
if [ -f "$kit" ] && command -v python3 >/dev/null 2>&1; then
  changed=$(diff <(mech "$kit") <(mech "$page") | grep -c '^[<>]' || true)
  [ "$changed" -eq 0 ] || defect "the mechanics block differs from the kit's on $changed lines; if the kit changed after it was copied, rebuild from the current one"
fi

[ "$fail" -eq 0 ] && printf 'ok     no defects\n'
exit "$fail"
