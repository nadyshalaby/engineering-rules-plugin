'use strict';
// page.js: the core of the explore-feature page. Reads the two JSON blobs build-page.sh
// embedded, draws the call stack, the file list and the code panes, and keeps every view
// keyed to one selected hop. page-flow.js registers the flow-rail panels and the sequence
// diagram through Explore.registerPanel, and page-highlight.js the syntax highlighter through
// Explore.registerHighlighter, before the page boots.
const Explore = (() => {
  const trace = readJson('trace-data');
  const bundle = readJson('excerpts-data');
  const hops = trace.hops;
  const byId = new Map(hops.map((hop) => [hop.id, hop]));
  const position = new Map(hops.map((hop, i) => [hop.id, i]));
  const excerpts = new Map(bundle.excerpts.map((entry) => [entry.id, entry]));
  const fileMetaByPath = new Map((trace.files || []).map((file) => [file.path, file]));
  const children = new Map();
  const badgesAt = new Map();
  const invokedSets = new Map();
  const panels = new Map();
  // highlight(text, file, state): one line to { tokens, state }; plain text until a highlighter registers.
  let highlight = (text, file, state) => ({ tokens: [{ text, cls: null }], state: state || {} });

  // Theme: the page follows the OS by default; the switch writes data-theme on the root (the CSS
  // carries both explicit blocks) and remembers the choice per viewer. Storage throws in a
  // private window, so both sides report the failure instead of swallowing it.
  function readStore(key) { try { return localStorage.getItem(key); } catch (err) { return null; } }
  function writeStore(key, value) { try { localStorage.setItem(key, value); return true; } catch (err) { return false; } }
  const osTheme = () => (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  const currentTheme = () => document.documentElement.getAttribute('data-theme') || osTheme();
  function applyStoredTheme() {
    const stored = readStore('explore-theme');
    if (stored === 'light' || stored === 'dark') document.documentElement.setAttribute('data-theme', stored);
  }
  function labelTheme() {
    const dark = currentTheme() === 'dark';
    const btn = document.getElementById('theme');
    btn.textContent = String.fromCharCode(dark ? 0x2600 : 0x263d);
    btn.setAttribute('aria-label', dark ? 'Switch to light theme' : 'Switch to dark theme');
    btn.setAttribute('title', dark ? 'Light theme' : 'Dark theme');
  }
  function toggleTheme() {
    const next = currentTheme() === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    writeStore('explore-theme', next);
    labelTheme();
  }
  const state = { selected: hops[0].id, tab: 'overview', query: '' };

  function readJson(id) {
    return JSON.parse(document.getElementById(id).textContent);
  }

  // h: a small element builder; text always goes through textContent, never through markup.
  function h(tag, attrs, ...kids) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class') node.className = value;
      else if (key === 'text') node.textContent = value;
      else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value);
    }
    for (const kid of kids.flat()) {
      if (kid === null || kid === undefined || kid === false) continue;
      node.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
    }
    return node;
  }

  const num = (id) => position.get(id) + 1;
  const basename = (path) => path.slice(path.lastIndexOf('/') + 1);
  const ELLIPSIS = String.fromCharCode(0x2026);
  const truncate = (text, max) => (text.length > max ? text.slice(0, max - 1) + ELLIPSIS : text);
  const motion = () => (window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth');
  const fileMeta = (path) => fileMetaByPath.get(path) || { path, layer: 'other', role: '' };

  function indexHops() {
    for (const hop of hops) {
      if (hop.invoked && hop.invoked.length) invokedSets.set(hop.id, new Set(hop.invoked));
      if (!hop.from) continue;
      if (!children.has(hop.from)) children.set(hop.from, []);
      children.get(hop.from).push(hop);
      if (!hop.call) continue;
      const key = hop.from + ':' + hop.call.line;
      if (!badgesAt.has(key)) badgesAt.set(key, []);
      badgesAt.get(key).push(hop);
    }
  }

  function onHopClick(event) {
    event.preventDefault();
    selectHop(event.currentTarget.getAttribute('data-hop'), {});
  }

  function badge(hop, extraClass) {
    const classes = ['badge', extraClass || '', hop.status === 'unresolved' ? 'unresolved' : ''].join(' ').trim();
    return h('a', { class: classes, href: '#hop-' + hop.id, 'data-hop': hop.id, title: hop.title, onclick: onHopClick }, num(hop.id));
  }

  function badges(ids) {
    const found = (ids || []).map((id) => byId.get(id)).filter(Boolean);
    return h('span', { class: 'badges' }, found.map((hop) => badge(hop)));
  }

  function layerChip(layer) {
    return h('span', { class: 'chip', style: '--layer: var(--layer-' + layer + ')', text: layer });
  }

  function stackItem(hop) {
    const kids = children.get(hop.id) || [];
    const classes = ['stack-item', hop.status === 'unresolved' ? 'unresolved' : ''].join(' ').trim();
    const link = h('a', { class: 'stack-link', href: '#hop-' + hop.id, 'data-hop': hop.id, onclick: onHopClick },
      badge(hop),
      h('span', { class: 'stack-title', text: hop.title }),
      h('span', { class: 'stack-file mono', text: basename(hop.file) + ':' + hop.line }));
    const item = h('li', { class: classes, 'data-hop': hop.id, 'data-stack': hop.id }, link);
    if (kids.length) item.append(h('ol', { class: 'stack' }, kids.map(stackItem)));
    return item;
  }

  function renderStack() {
    document.getElementById('stack').replaceChildren(stackItem(hops[0]));
  }

  function filesInOrder() {
    const seen = [];
    for (const hop of hops) if (!seen.includes(hop.file)) seen.push(hop.file);
    return seen;
  }

  function scrollToFile(path) {
    const first = hops.find((hop) => hop.file === path);
    if (first) selectHop(first.id, {});
  }

  function renderFiles() {
    const items = filesInOrder().map((path) => {
      const meta = fileMeta(path);
      return h('li', { class: 'file-item', 'data-file': path, tabindex: '0', onclick: () => scrollToFile(path),
        onkeydown: (event) => { if (event.key === 'Enter') scrollToFile(path); } },
        h('span', { class: 'file-path mono', text: path }), layerChip(meta.layer),
        meta.role ? h('span', { class: 'file-role', text: meta.role }) : null);
    });
    document.getElementById('files').replaceChildren(...items);
  }

  function lineRow(hop, lineNo, tokens) {
    const set = invokedSets.get(hop.id);
    const invoked = !set || set.has(lineNo);
    const marks = badgesAt.get(hop.id + ':' + lineNo) || [];
    const classes = ['ln', invoked ? 'invoked' : 'dimmed', lineNo === hop.line ? 'entry-line' : ''].join(' ').trim();
    const runs = tokens.map((run) => (run.cls ? h('span', { class: run.cls, text: run.text }) : run.text));
    return h('tr', { class: classes, 'data-line': lineNo },
      h('td', { class: 'gutter', text: lineNo }),
      h('td', { class: 'marks' }, marks.map((kid) => badge(kid, 'callbadge'))),
      h('td', { class: 'src' }, h('pre', {}, runs)));
  }

  function candidateLine(candidate) {
    return h('span', { class: 'candidate mono' }, candidate.file + ':' + candidate.line + '  ', h('code', { text: candidate.evidence }));
  }

  function paneExtras(hop) {
    const rows = [];
    if (hop.returns) rows.push(h('div', {}, 'Returns ', h('code', { text: hop.returns })));
    for (const thrown of hop.throws || []) rows.push(h('div', {}, 'Throws ', h('code', { text: thrown.error }), ' when ' + thrown.when));
    if (hop.author_says) rows.push(h('blockquote', { class: 'author-says' }, "Author's comment, checked against the code: " + hop.author_says));
    if (hop.status === 'unresolved') {
      rows.push(h('div', { class: 'unresolved-note' }, 'Unresolved from the code: ' + hop.reason));
      rows.push(h('div', {}, 'Candidates: ', ...(hop.candidates || []).map(candidateLine)));
    }
    return rows.length ? h('div', { class: 'pane-extras' }, rows) : null;
  }

  function paneFor(hop) {
    const excerpt = excerpts.get(hop.id);
    const meta = fileMeta(hop.file);
    const head = h('header', { class: 'pane-head' }, badge(hop),
      h('span', { class: 'pane-path mono', text: hop.file }), layerChip(meta.layer),
      h('span', { class: 'pane-sym mono', text: hop.symbol }),
      hop.status === 'unresolved' ? h('span', { class: 'chip tone-warn', text: 'unresolved' }) : null,
      h('span', { class: 'pane-lines mono', text: 'L' + excerpt.start + '-' + excerpt.end }));
    const why = h('p', { class: 'pane-why' }, h('strong', { text: hop.title + '. ' }), hop.why);
    let state = {};
    const rows = excerpt.lines.map((text, i) => {
      const run = highlight(text, hop.file, state);
      state = run.state;
      return lineRow(hop, excerpt.start + i, run.tokens);
    });
    const code = h('div', { class: 'code', tabindex: '0', 'aria-label': 'Excerpt of ' + hop.file }, h('table', { class: 'hunk' }, h('tbody', {}, rows)));
    return h('article', { class: 'pane', id: 'pane-' + hop.id, 'data-hop': hop.id }, head, why, paneExtras(hop), code);
  }

  function renderPanes() {
    document.getElementById('panes').replaceChildren(...hops.map(paneFor));
  }

  function renderHeader() {
    document.getElementById('page-title').textContent = trace.title;
    document.getElementById('entry-label').textContent = trace.entry.label;
    const chips = [];
    for (const repo of bundle.repos || []) chips.push(h('span', { class: 'chip tone-plain mono', text: repo.path + ' @' + (repo.commit || 'no commit') }));
    const dirty = (bundle.repos || []).reduce((count, repo) => count + repo.dirty.length, 0);
    if (dirty) chips.push(h('span', { class: 'chip tone-warn', text: dirty + ' cited file' + (dirty === 1 ? '' : 's') + ' with uncommitted changes' }));
    chips.push(h('span', { class: 'chip tone-good', text: hops.length + ' hops verified' }));
    chips.push(h('span', { class: 'chip tone-plain', text: filesInOrder().length + ' files' }));
    document.getElementById('meta').replaceChildren(...chips);
  }

  function renderTabs() {
    const tabs = [...panels.entries()].map(([name, panel]) => h('button', {
      type: 'button', class: 'tab', role: 'tab', 'data-tab': name, 'aria-selected': String(name === state.tab), onclick: () => switchTab(name) }, panel.label));
    document.getElementById('tabs').replaceChildren(...tabs);
  }

  function renderPanel() {
    const panel = panels.get(state.tab);
    if (!panel) return;
    document.getElementById('panel').replaceChildren(panel.render(api));
    for (const tab of document.querySelectorAll('.tab')) tab.setAttribute('aria-selected', String(tab.getAttribute('data-tab') === state.tab));
  }

  function switchTab(name) {
    if (!panels.has(name)) return;
    state.tab = name;
    renderPanel();
  }

  function selectHop(id, opts) {
    if (!byId.has(id)) return;
    state.selected = id;
    for (const node of document.querySelectorAll('.selected')) node.classList.remove('selected');
    for (const node of document.querySelectorAll('[data-hop="' + id + '"]')) node.classList.add('selected');
    const pane = document.getElementById('pane-' + id);
    if (pane && !opts.noScroll) pane.scrollIntoView({ block: 'start', behavior: motion() });
    document.getElementById('hopcount').textContent = num(id) + ' / ' + hops.length;
    if (location.hash !== '#hop-' + id) history.replaceState(null, '', '#hop-' + id);
    renderPanel();
  }

  function step(delta) {
    const next = Math.min(hops.length - 1, Math.max(0, position.get(state.selected) + delta));
    selectHop(hops[next].id, {});
  }

  const matches = (hop) => {
    if (!state.query) return true;
    return [hop.title, hop.file, hop.symbol, hop.why].join(' ').toLowerCase().includes(state.query);
  };

  function visibleInStack(hop, visible) {
    const own = matches(hop);
    let any = own;
    for (const kid of children.get(hop.id) || []) any = visibleInStack(kid, visible) || any;
    if (any) visible.add(hop.id);
    return any;
  }

  function applyQuery(raw) {
    state.query = raw.trim().toLowerCase();
    const visible = new Set();
    visibleInStack(hops[0], visible);
    for (const item of document.querySelectorAll('[data-stack]')) item.classList.toggle('hidden-by-search', !visible.has(item.getAttribute('data-stack')));
    for (const pane of document.querySelectorAll('.pane')) pane.classList.toggle('faded', !matches(byId.get(pane.getAttribute('data-hop'))));
    const fileHasMatch = (path) => hops.some((hop) => hop.file === path && matches(hop));
    for (const item of document.querySelectorAll('.file-item')) item.classList.toggle('hidden-by-search', !fileHasMatch(item.getAttribute('data-file')));
    renderPanel();
  }

  function selectFirstMatch() {
    const first = hops.find(matches);
    if (first) selectHop(first.id, {});
  }

  function clearSearch() {
    const box = document.getElementById('search');
    if (!box.value) return;
    box.value = '';
    applyQuery('');
  }

  function toggleHelp(force) {
    const overlay = document.getElementById('help-overlay');
    overlay.hidden = force === undefined ? !overlay.hidden : !force;
  }

  function onKey(event) {
    const typing = event.target && ['INPUT', 'TEXTAREA'].includes(event.target.tagName);
    if (event.key === 'Escape') { toggleHelp(false); clearSearch(); return; }
    if (typing) { if (event.key === 'Enter') selectFirstMatch(); return; }
    if (event.key === 'j') step(1);
    else if (event.key === 'k') step(-1);
    else if (event.key === '/') { event.preventDefault(); document.getElementById('search').focus(); }
    else if (event.key === '?') toggleHelp();
    else if (event.key >= '1' && event.key <= '8') switchTab([...panels.keys()][Number(event.key) - 1]);
  }

  const idFromHash = () => (location.hash.startsWith('#hop-') ? location.hash.slice(5) : hops[0].id);

  function bind() {
    document.getElementById('prev').addEventListener('click', () => step(-1));
    document.getElementById('next').addEventListener('click', () => step(1));
    document.getElementById('help').addEventListener('click', () => toggleHelp());
    document.getElementById('help-close').addEventListener('click', () => toggleHelp(false));
    document.getElementById('help-overlay').addEventListener('click', (event) => { if (event.target.id === 'help-overlay') toggleHelp(false); });
    document.getElementById('search').addEventListener('input', (event) => applyQuery(event.target.value));
    document.getElementById('theme').addEventListener('click', toggleTheme);
    document.addEventListener('keydown', onKey);
    window.addEventListener('hashchange', () => selectHop(idFromHash(), {}));
  }

  function boot() {
    indexHops();
    renderHeader();
    renderStack();
    renderFiles();
    renderPanes();
    renderTabs();
    bind();
    labelTheme();
    selectHop(idFromHash(), { noScroll: location.hash === '' });
  }

  const api = { trace, bundle, hops, byId, state, h, badges, num, basename, truncate, fileMeta, selectHop, matches };
  const registerPanel = (name, panel) => panels.set(name, panel);
  const registerHighlighter = (fn) => { highlight = fn; };
  applyStoredTheme();
  document.addEventListener('DOMContentLoaded', boot);
  return { registerPanel, registerHighlighter, api };
})();
