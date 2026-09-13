'use strict';
// page-highlight.js: self-contained syntax highlighting for the code panes. No external
// library — the page stays one portable file, and tests/explore-feature-page.test.sh asserts
// the font stylesheet is the only external host it reaches. One line is tokenized at a time
// with a small state object threaded down a pane (paneFor in page.js), so a block comment or a
// template literal that spans lines keeps its colour. It registers through
// Explore.registerHighlighter, the seam page-flow.js also uses; page.js renders plain text when
// nothing registers. The pure tokenizer is exported for a node test and so avoids the DOM.
(function () {
  const words = (s) => new Set(s.split(' '));
  const TS_KW = words('const let var function return if else for while do switch case break continue new class extends implements interface type enum import export from as async await yield try catch finally throw typeof instanceof in of void delete super namespace declare abstract is keyof infer satisfies readonly public private protected static get set default');
  const SQL_KW = words('select insert update delete from where join left right inner outer full on group by order having limit offset values into set returning and or not null is as distinct union all case when then end');
  const SH_KW = words('if then elif else fi for while until do done case esac in function return local export readonly set echo printf cd exit trap source');
  const PY_KW = words('def class return if elif else for while import from as try except finally raise with pass lambda yield await async in is not and or global nonlocal del assert');
  const LITERALS = words('true false null undefined NaN Infinity None True False');

  // spec per flavour: kw set, line-comment opener (or null), block comments, template strings,
  // the quote characters, and ci for a case-insensitive keyword match (SQL).
  const SPECS = {
    ts:   { kw: TS_KW,  line: '//', block: true,  tmpl: true,  quotes: '"\'', ci: false },
    json: { kw: new Set(), line: null, block: false, tmpl: false, quotes: '"', ci: false },
    css:  { kw: new Set(), line: null, block: true,  tmpl: false, quotes: '"\'', ci: false },
    sql:  { kw: SQL_KW, line: '--', block: true,  tmpl: false, quotes: '\'"', ci: true },
    sh:   { kw: SH_KW,  line: '#',  block: false, tmpl: false, quotes: '"\'', ci: false },
    py:   { kw: PY_KW,  line: '#',  block: false, tmpl: false, quotes: '"\'', ci: false },
  };
  const EXT = { ts: 'ts', tsx: 'ts', mts: 'ts', cts: 'ts', js: 'ts', jsx: 'ts', mjs: 'ts', cjs: 'ts',
    json: 'json', css: 'css', scss: 'css', less: 'css', sql: 'sql', sh: 'sh', bash: 'sh', zsh: 'sh', py: 'py' };
  const flavor = (path) => EXT[(String(path).split('.').pop() || '').toLowerCase()] || '';

  const readWord = (line, i) => { let j = i; while (j < line.length && /[A-Za-z0-9_$]/.test(line[j])) j++; return j; };
  const readNumber = (line, i) => { let j = i; while (j < line.length && /[0-9a-fA-FxXoObBeE_.]/.test(line[j])) j++; return j; };
  const nextNonSpace = (line, i) => { let j = i; while (j < line.length && line[j] === ' ') j++; return line[j]; };

  // readString: from the opening quote to the matching one, honouring backslash escapes; runs
  // to the end of the line when the quote never closes.
  function readString(line, i, quote) {
    let j = i + 1;
    while (j < line.length) { if (line[j] === '\\') { j += 2; continue; } if (line[j] === quote) return j + 1; j++; }
    return line.length;
  }
  // readPair: the end index of a block comment or template body and whether it is still open at
  // end of line. `close` is the closing token ('*/') or the backtick.
  function readPair(line, i, close) {
    const k = close === '*/' ? line.indexOf('*/', i) : indexOfBacktick(line, i);
    if (k < 0) return [line.length, true];
    return [k + close.length, false];
  }
  function indexOfBacktick(line, i) {
    let j = i;
    while (j < line.length) { if (line[j] === '\\') { j += 2; continue; } if (line[j] === '`') return j; j++; }
    return -1;
  }
  function classify(word, ctx, end) {
    if (LITERALS.has(word)) return 'tok-number';
    if (ctx.spec.kw.has(ctx.spec.ci ? word.toLowerCase() : word)) return 'tok-keyword';
    if (nextNonSpace(ctx.line, end) === '(') return 'tok-fn';
    if (/^[A-Z]/.test(word)) return 'tok-type';
    return null;
  }
  // resume: a block comment or template carried in from the previous line. Returns the index to
  // scan from, or -1 when the whole line stayed inside it.
  function resume(ctx) {
    const { line, state, out } = ctx;
    if (state.block) { const [e, open] = readPair(line, 0, '*/'); out.push({ text: line.slice(0, e), cls: 'tok-comment' }); state.block = open; return open ? -1 : e; }
    if (state.tmpl) { const [e, open] = readPair(line, 0, '`'); out.push({ text: line.slice(0, e), cls: 'tok-string' }); state.tmpl = open; return open ? -1 : e; }
    return 0;
  }
  function step(ctx, i) {
    const { line, spec, state, out } = ctx;
    const c = line[i];
    if (spec.block && c === '/' && line[i + 1] === '*') { const [e, open] = readPair(line, i + 2, '*/'); out.push({ text: line.slice(i, e), cls: 'tok-comment' }); state.block = open; return e; }
    if (spec.line && line.startsWith(spec.line, i)) { out.push({ text: line.slice(i), cls: 'tok-comment' }); return line.length; }
    if (spec.tmpl && c === '`') { const [e, open] = readPair(line, i + 1, '`'); out.push({ text: line.slice(i, e), cls: 'tok-string' }); state.tmpl = open; return e; }
    if (spec.quotes.indexOf(c) >= 0) { const e = readString(line, i, c); out.push({ text: line.slice(i, e), cls: 'tok-string' }); return e; }
    if (c >= '0' && c <= '9') { const e = readNumber(line, i); out.push({ text: line.slice(i, e), cls: 'tok-number' }); return e; }
    if (/[A-Za-z_$]/.test(c)) { const e = readWord(line, i); out.push({ text: line.slice(i, e), cls: classify(line.slice(i, e), ctx, e) }); return e; }
    out.push({ text: c, cls: null }); return i + 1;
  }
  // merge: fold neighbouring tokens of the same class into one run, so a line of punctuation is
  // one text node, not twenty.
  function merge(tokens) {
    const out = [];
    for (const t of tokens) { const prev = out[out.length - 1]; if (prev && prev.cls === t.cls) prev.text += t.text; else out.push({ text: t.text, cls: t.cls }); }
    return out;
  }
  // tokenize: one line to a list of { text, cls } runs, cls null for plain text. state carries
  // block/template across lines; the caller threads the returned state into the next line.
  function tokenize(line, file, state) {
    const st = state || {};
    const spec = SPECS[flavor(file)];
    const out = [];
    if (!spec) { out.push({ text: line, cls: null }); return { tokens: out, state: st }; }
    const ctx = { line, spec, state: st, out };
    let i = resume(ctx);
    while (i >= 0 && i < line.length) i = step(ctx, i);
    return { tokens: merge(out), state: st };
  }

  if (typeof Explore !== 'undefined' && Explore.registerHighlighter) Explore.registerHighlighter(tokenize);
  if (typeof module !== 'undefined' && module.exports) module.exports = { tokenize, flavor };
})();
