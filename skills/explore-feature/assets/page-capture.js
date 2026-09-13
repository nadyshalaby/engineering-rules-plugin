'use strict';
// page-capture.js: the runtime view of one real run, present only when build-page.sh embedded
// a capture.json it re-verified (16.10, "capture.json"). Registers three things through the
// seams page.js exposes: a Runtime block under every excerpt that has an anchor (each call's
// arguments in, value out or error thrown, the time it took), a chip on every anchor line and
// every branch line the run reached, and the Runtime tab (the run's record, one row per hop).
// Without a capture nothing here registers, so the page is the 2.13.1 page.
(() => {
  const api = Explore.api;
  const capture = api.capture;
  if (!capture) return;
  const h = api.h;
  const CALLS_SHOWN = 5;
  const INLINE_CHARS = 120;
  const anchorsByHop = new Map();
  const anchorsAt = new Map();
  const branchesAt = new Map();
  const key = (hop, line) => hop + ':' + line;
  const push = (map, k, value) => { if (!map.has(k)) map.set(k, []); map.get(k).push(value); };
  for (const anchor of capture.anchors) {
    push(anchorsByHop, anchor.hop, anchor);
    push(anchorsAt, key(anchor.hop, anchor.line), anchor);
    for (const branch of anchor.branches) push(branchesAt, key(anchor.hop, branch.line), branch);
  }
  const millis = api.millis;
  const total = (calls) => calls.reduce((sum, call) => sum + (call.ms || 0), 0);
  const threwCount = (calls) => calls.filter((call) => call.threw).length;
  const text = (value) => (value === undefined ? 'undefined' : JSON.stringify(value));

  // valueNode: a value inline while it is short, else a summary that opens the pretty form,
  // built the first time it is opened rather than for every value on the page.
  function valueNode(value, cls) {
    const flat = text(value);
    if (flat.length <= INLINE_CHARS) return h('span', { class: 'rt-v ' + cls, text: flat });
    const fill = () => { if (node.open && node.childElementCount === 1) node.append(h('pre', { text: JSON.stringify(value, null, 2) })); };
    const node = h('details', { class: 'rt-more', ontoggle: fill }, h('summary', { class: 'rt-v ' + cls, text: api.truncate(flat, INLINE_CHARS) }));
    return node;
  }

  function outcomeNode(call) {
    if (call.threw) return valueNode(call.threw.error + ': ' + call.threw.message, 'rt-threw');
    if (call.void) return h('span', { class: 'rt-v rt-void', text: 'returned nothing' });
    if (call.unfinished) return h('span', { class: 'rt-v rt-void', text: 'still running when the process ended' });
    return valueNode(call.out, 'rt-out');
  }

  function callRow(call) {
    const label = call.threw ? 'threw' : 'out';
    return h('div', { class: 'rt-call' },
      h('span', { class: 'rt-k', text: 'in' }), valueNode(call.in, 'rt-in'),
      h('span', { class: 'rt-k', text: label }), outcomeNode(call),
      h('span', { class: 'rt-k', text: 'took' }), h('span', { class: 'rt-ms', text: call.ms === undefined ? '' : millis(call.ms) + (call.async ? ', settled later' : '') }));
  }

  // callRows: the first calls in full; the rest behind a summary and rendered when it opens,
  // so a run with thousands of calls costs the page nothing until someone asks.
  function callRows(calls) {
    const shown = calls.slice(0, CALLS_SHOWN).map(callRow);
    if (calls.length <= CALLS_SHOWN) return shown;
    const fill = () => { if (more.open && more.childElementCount === 1) more.append(...calls.slice(CALLS_SHOWN).map(callRow)); };
    const more = h('details', { class: 'rt-more', ontoggle: fill }, h('summary', { text: (calls.length - CALLS_SHOWN) + ' more calls' }));
    return [...shown, more];
  }

  function branchChip(branch) {
    if (branch.kind === 'switch') return h('span', { class: 'linechip is-mixed', text: 'switch: ' + api.truncate(branch.values.map(text).join(', '), 40), title: 'switch at line ' + branch.line + ', seen ' + branch.seen + ' times' });
    const both = branch.true > 0 && branch.false > 0;
    const cls = both ? 'is-mixed' : branch.true > 0 ? 'is-true' : 'is-false';
    const label = both ? 'true, false' : branch.true > 0 ? 'true' : 'false';
    return h('span', { class: 'linechip ' + cls, text: label, title: 'line ' + branch.line + ': true ' + branch.true + ' times, false ' + branch.false + ' times' });
  }

  function anchorBlock(anchor) {
    const count = anchor.calls.length;
    const thrown = threwCount(anchor.calls);
    return h('div', { class: 'rt-anchor' },
      h('div', { class: 'rt-anchor-head' },
        h('span', { class: 'rt-name mono', text: anchor.name }),
        h('span', { class: 'rt-line mono', text: 'L' + anchor.line }),
        h('span', { class: 'chip tone-plain', text: count + (count === 1 ? ' call' : ' calls') + (count ? ', ' + millis(total(anchor.calls)) : '') }),
        thrown ? h('span', { class: 'chip tone-warn', text: thrown + ' threw' }) : null),
      count ? callRows(anchor.calls) : h('p', { class: 'rt-note', text: 'Loaded, never called on this run.' }),
      anchor.branches.length ? h('div', { class: 'rt-branches' }, anchor.branches.map((branch) => h('span', {}, h('span', { class: 'rt-k', text: 'L' + branch.line + ' ' }), branchChip(branch)))) : null);
  }

  // paneExtra: the Runtime block under an excerpt, for the hops the run entered.
  function paneExtra(hop) {
    const list = anchorsByHop.get(hop.id);
    if (!list) return null;
    const calls = list.flatMap((anchor) => anchor.calls);
    const thrown = threwCount(calls);
    return h('section', { class: 'runtime', 'aria-label': 'Runtime of ' + hop.title },
      h('div', { class: 'rt-head' },
        h('span', { class: 'label-caps', text: 'Runtime, one ' + capture.run.mode + ' run' }),
        h('span', { class: 'chip tone-plain', text: calls.length + (calls.length === 1 ? ' call' : ' calls') }),
        thrown ? h('span', { class: 'chip tone-warn', text: thrown + ' threw' }) : null),
      list.map(anchorBlock));
  }

  // lineMark: the chips beside a line: calls and time on an anchor line, the outcome on a
  // branch line.
  function lineMark(hop, lineNo) {
    const chips = [];
    for (const anchor of anchorsAt.get(key(hop.id, lineNo)) || []) {
      const count = anchor.calls.length;
      const thrown = threwCount(anchor.calls);
      const cls = thrown ? 'is-threw' : 'is-call';
      chips.push(h('span', { class: 'linechip ' + cls, text: count + '×' + (count ? ' ' + millis(total(anchor.calls)) : ''), title: anchor.name + ': ' + count + ' calls' + (thrown ? ', ' + thrown + ' threw' : '') }));
    }
    for (const branch of branchesAt.get(key(hop.id, lineNo)) || []) chips.push(branchChip(branch));
    return chips.length ? chips : null;
  }

  function summaryList() {
    const run = capture.run;
    const rows = [['Mode', run.mode], ['Command', run.command], ['Runtime', run.runtime], ['Started', run.started],
      ['Exit', run.exit === null ? 'stopped by --stop' : String(run.exit)], ['Events', String(run.events) + (run.truncated ? ' (the sink hit its cap; later calls are missing)' : '')]];
    return h('dl', { class: 'meta-list' }, rows.flatMap(([k, v]) => [h('dt', { text: k }), h('dd', { class: 'mono', text: v })]));
  }

  function hopTable() {
    const rows = (capture.hops || []).map((row) => {
      const hop = api.byId.get(row.hop);
      return h('tr', {}, h('td', {}, hop ? api.badges([row.hop]) : row.hop, ' ', hop ? hop.title : ''),
        h('td', { class: 'num', text: row.anchors }), h('td', { class: 'num', text: row.calls }),
        h('td', { class: 'num', text: row.threw }), h('td', { class: 'num', text: millis(row.ms || 0) }));
    });
    return h('table', { class: 'rt-table' },
      h('thead', {}, h('tr', {}, h('th', { text: 'Hop' }), h('th', { class: 'num', text: 'Anchors' }), h('th', { class: 'num', text: 'Calls' }), h('th', { class: 'num', text: 'Threw' }), h('th', { class: 'num', text: 'Time' }))),
      h('tbody', {}, rows));
  }

  function runtimePanel() {
    return h('div', {},
      h('p', { class: 'rt-note', text: 'What one real run did: the arguments each function got, what it returned or threw, and which way each condition went. Values are masked and cut before they reach disk. They describe this run, never the code’s contract.' }),
      h('h3', { class: 'label-caps', text: 'The run' }), summaryList(),
      h('h3', { class: 'label-caps', text: 'Per hop' }), hopTable());
  }

  function legendRows() {
    const legend = document.querySelector('.legend');
    if (!legend) return;
    legend.append(
      h('dt', {}, h('span', { class: 'linechip is-call', text: '3× 1.2 ms' })), h('dd', { text: 'This function ran 3 times on the captured run, 1.2 ms in all. Amber when a call threw.' }),
      h('dt', {}, h('span', { class: 'linechip is-true', text: 'true' })), h('dd', { text: 'Which way this condition went on the captured run; both when it went both ways.' }));
  }

  Explore.registerPaneExtra(paneExtra);
  Explore.registerLineMark(lineMark);
  Explore.registerPanel('runtime', { label: 'Runtime', render: runtimePanel });
  document.addEventListener('DOMContentLoaded', legendRows);
})();
