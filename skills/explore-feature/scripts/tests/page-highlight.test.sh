#!/bin/bash
# Behaviour test for the page's syntax highlighter (assets/page-highlight.js), run in node with
# no DOM and no dependency: the tokenizer is pure. Each line below is one claim; node prints
# "name<TAB>expected<TAB>actual" and the harness judges it. Skips with a line when node is absent.
# Run: bash skills/explore-feature/scripts/tests/page-highlight.test.sh
# PAGE_HIGHLIGHT_JS points the test at another copy of the script, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
HL="${PAGE_HIGHLIGHT_JS:-$here/../../assets/page-highlight.js}"

if ! command -v node >/dev/null 2>&1; then printf 'skip: node is not on PATH\n'; report; exit; fi
node - "$HL" > "$WORK/rows.tsv" 2> "$WORK/node.err" <<'JS'
const { tokenize, flavor } = require(require('path').resolve(process.argv[process.argv.length - 1]));
const runs = (line, file, state) => tokenize(line, file, state || {});
const show = (r) => r.tokens.map((t) => (t.cls ? t.cls.slice(4) : '.') + ':' + t.text).join('|');
const row = (name, expected, actual) => process.stdout.write(name + '\t' + expected + '\t' + actual + '\n');
row('flavor: ts, tsx, js, sql, json, unknown', 'ts ts ts sql json -', [flavor('a.ts'), flavor('b.tsx'), flavor('c.js'), flavor('q.sql'), flavor('d.json'), flavor('x.rb') || '-'].join(' '));
row('ts: keyword, call, await', '.:  |keyword:const|.: order = |keyword:await|.: |fn:insertOrder|.:({ ...input })', show(runs('  const order = await insertOrder({ ...input })', 'orders.service.ts')));
row('ts: method call and a type-cased constant', '.:tenantApp.|fn:use|.:(|type:ROUTE_WILDCARD|.:)', show(runs('tenantApp.use(ROUTE_WILDCARD)', 'app.ts')));
row('ts: line comment swallows the rest', 'keyword:import|.: x |comment:// note = "no string"', show(runs('import x // note = "no string"', 'a.ts')));
row('ts: string with an escaped quote', '.:x = |string:"a \\" b"|.: + |number:2', show(runs('x = "a \\" b" + 2', 'a.ts')));
const first = runs('const x = 1 /* opens', 'a.ts');
row('ts: block comment stays open at end of line', 'true', String(first.state.block));
const second = runs('still comment */ const y = 2', 'a.ts', first.state);
row('ts: the next line closes it and colours the rest', 'comment:still comment */|.: |keyword:const|.: y = |number:2 false', show(second) + ' ' + String(second.state.block));
const tmpl = runs('const s = `hello ${name}', 'a.ts');
row('ts: template literal spans lines', 'keyword:const|.: s = |string:`hello ${name} true', show(tmpl) + ' ' + String(tmpl.state.tmpl));
row('sql: keywords are case-insensitive', 'keyword:select|.: id |keyword:FROM|.: t', show(runs('select id FROM t', 'q.sql')));
row('json: strings, number, literal', '.:{ |string:"n"|.:: |number:42|.:, |string:"ok"|.:: |number:true|.: }', show(runs('{ "n": 42, "ok": true }', 'd.json')));
row('sh: hash comment', '.:x=|number:1|.: |comment:# note', show(runs('x=1 # note', 'run.sh')));
row('unknown extension: one plain run', '.:anything at all', show(runs('anything at all', 'notes.rb')));
row('plain runs are merged into one node', '1', String(runs('a b c d', 'x.ts').tokens.length));
JS
while IFS=$'\t' read -r name expected actual; do assert_eq "$name" "$expected" "$actual"; done < "$WORK/rows.tsv"
assert_eq "the node run produced rows" 13 "$(wc -l < "$WORK/rows.tsv" | tr -d ' ')"
assert_eq "the node run wrote nothing to stderr" "" "$(cat "$WORK/node.err")"
report
