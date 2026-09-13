'use strict';
// page-flow.js: the flow rail. Registers the eight panels (overview, sequence, steps,
// branches, failure, shapes, decisions, quiz) with Explore.registerPanel; each render gets
// the api page.js exposes and returns one element. The sequence diagram is drawn as SVG
// here so every arrow is a real link into the same selected-hop state as the other views.
(() => {
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const LANE_W = 150;
  const PAD = 24;
  const HEAD_H = 64;
  const ROW_H = 46;

  function svgEl(tag, attrs, ...kids) {
    const node = document.createElementNS(SVG_NS, tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (key === 'text') node.textContent = value;
      else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value);
    }
    for (const kid of kids.flat()) if (kid) node.append(kid);
    return node;
  }

  // lanesOf: one lane per file an arrow starts or ends in. A type hop is a reference, not a
  // call, so it draws no arrow and earns no lane of its own.
  const lanesOf = (api, rows) => {
    const lanes = [api.hops[0].file];
    for (const hop of rows) {
      for (const file of [api.byId.get(hop.from).file, hop.file]) if (!lanes.includes(file)) lanes.push(file);
    }
    return lanes;
  };

  // laneHead: one lane header; lane is { file, x, height }.
  function laneHead(api, lane) {
    const { file, x, height } = lane;
    const meta = api.fileMeta(file);
    return svgEl('g', {},
      svgEl('line', { class: 'lane-line', x1: x, y1: HEAD_H - 8, x2: x, y2: height - PAD }),
      svgEl('rect', { class: 'lane-box', x: x - LANE_W / 2 + 6, y: 8, width: LANE_W - 12, height: 40, rx: 6 }),
      svgEl('text', { class: 'lane-name', x, y: 26, 'text-anchor': 'middle', text: api.truncate(api.basename(file), 20) }),
      svgEl('text', { class: 'lane-layer', x, y: 41, 'text-anchor': 'middle', text: meta.layer }));
  }

  function arrowPath(x1, x2, y) {
    if (x1 !== x2) return 'M ' + x1 + ' ' + y + ' L ' + x2 + ' ' + y;
    return 'M ' + x1 + ' ' + (y - 6) + ' h 34 v 14 h -34';
  }

  // backArrow: the dashed return or throw arrow; geo is { x1, x2, y }.
  function backArrow(hop, geo) {
    const { x1, x2, y } = geo;
    const thrown = (hop.throws || []).map((entry) => entry.error).join(', ');
    if (!hop.returns && !thrown) return [];
    const label = thrown ? 'throws ' + thrown : 'returns ' + hop.returns;
    const path = x1 === x2 ? 'M ' + (x1 + 34) + ' ' + (y + 20) + ' h -34' : 'M ' + x2 + ' ' + (y + 18) + ' L ' + x1 + ' ' + (y + 18);
    return [
      svgEl('path', { class: 'arrow-back' + (thrown ? ' arrow-throw' : ''), d: path, 'marker-end': 'url(#head-back)' }),
      svgEl('text', { class: 'seq-back-label' + (thrown ? ' seq-throw-label' : ''), x: Math.min(x1, x2) + 14, y: y + 32, text: label.slice(0, 40) })];
  }

  // arrow: one clickable call arrow; geo is { laneX, y }.
  function arrow(api, hop, geo) {
    const parent = api.byId.get(hop.from);
    const y = geo.y;
    const x1 = geo.laneX.get(parent.file);
    const x2 = geo.laneX.get(hop.file);
    const labelX = x1 === x2 ? x1 + 40 : Math.min(x1, x2) + Math.abs(x2 - x1) / 2;
    const select = () => api.selectHop(hop.id, {});
    const classes = 'seq-hop' + (hop.status === 'unresolved' ? ' unresolved' : '');
    return svgEl('g', { class: classes, 'data-hop': hop.id, tabindex: '0', role: 'button', 'aria-label': hop.title, onclick: select,
      onkeydown: (event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); select(); } } },
      svgEl('path', { class: 'arrow', d: arrowPath(x1, x2, y), 'marker-end': 'url(#head)' }),
      svgEl('text', { class: 'seq-label', x: labelX, y: y - 7, 'text-anchor': x1 === x2 ? 'start' : 'middle', text: api.truncate(hop.title, 26) }),
      svgEl('circle', { class: 'seq-num', cx: x1, cy: y, r: 9 }),
      svgEl('text', { class: 'seq-num-text', x: x1, y: y + 3.5, 'text-anchor': 'middle', text: api.num(hop.id) }),
      ...backArrow(hop, { x1, x2, y }));
  }

  function defs() {
    return svgEl('defs', {},
      svgEl('marker', { id: 'head', viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 8, markerHeight: 8, orient: 'auto-start-reverse' },
        svgEl('path', { d: 'M 0 0 L 10 5 L 0 10 z' })),
      svgEl('marker', { id: 'head-back', viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' },
        svgEl('path', { d: 'M 0 0 L 10 5 L 0 10 z' })));
  }

  function sequence(api) {
    const rows = api.hops.filter((hop) => hop.from && hop.kind !== 'type');
    const lanes = lanesOf(api, rows);
    const laneX = new Map(lanes.map((file, i) => [file, PAD + i * LANE_W + LANE_W / 2]));
    const width = PAD * 2 + lanes.length * LANE_W;
    const height = HEAD_H + rows.length * ROW_H + PAD;
    const svg = svgEl('svg', { class: 'seq', viewBox: '0 0 ' + width + ' ' + height, width, height, role: 'group', 'aria-label': 'Sequence diagram' },
      defs(), ...lanes.map((file) => laneHead(api, { file, x: laneX.get(file), height })),
      ...rows.map((hop, i) => arrow(api, hop, { laneX, y: HEAD_H + i * ROW_H + 12 })));
    const legend = api.h('p', { class: 'seq-legend' }, api.h('span', {}, 'Solid: a call. Dashed grey: a return. Red: a throw. Dashed amber: unresolved from the code. Numbers match the badges everywhere else.'));
    return api.h('div', {}, legend, api.h('div', { class: 'seq-wrap' }, svg));
  }

  // relatedLink: a related page is a link only when its url is http(s); anything else stays text.
  function relatedLink(h, link) {
    const url = typeof link.url === 'string' ? link.url : '';
    if (url.startsWith('https://') || url.startsWith('http://')) return h('a', { href: url, text: link.label });
    return h('span', { text: link.label });
  }

  function overview(api) {
    const h = api.h;
    const bundle = api.bundle;
    const repos = (bundle.repos || []).map((repo) => repo.path + ' at ' + (repo.commit || 'no commit') + (repo.dirty.length ? ' (uncommitted: ' + repo.dirty.join(', ') + ')' : ''));
    const unreached = api.trace.unreached || [];
    const related = api.trace.related || [];
    return h('div', {},
      h('p', { text: api.trace.summary }),
      h('h3', { class: 'label-caps', text: 'Trigger' }), h('p', { text: api.trace.entry.trigger }),
      h('h3', { class: 'label-caps', text: 'Verified against' }),
      h('dl', { class: 'meta-list' },
        h('dt', { text: 'Repositories' }), h('dd', {}, repos.length ? repos.map((line) => h('div', { class: 'mono', text: line })) : 'none found'),
        h('dt', { text: 'Verified at' }), h('dd', { class: 'mono', text: bundle.verified_at || '' }),
        h('dt', { text: 'Root' }), h('dd', { class: 'mono', text: bundle.root || api.trace.root })),
      h('h3', { class: 'label-caps', text: 'Not covered by this page' }),
      unreached.length ? h('ul', {}, unreached.map((line) => h('li', { text: line }))) : h('p', { class: 'empty', text: 'Nothing was left out.' }),
      related.length ? h('h3', { class: 'label-caps', text: 'Related pages' }) : null,
      related.length ? h('ul', {}, related.map((link) => h('li', {}, relatedLink(h, link)))) : null,
      h('h3', { class: 'label-caps', text: 'How to read this page' }),
      h('p', { text: 'Follow the numbers. The stack on the left is the call order, the panes in the middle are the real lines, and every tab here points back into them.' }));
  }

  function steps(api) {
    const items = (api.trace.pseudocode || []).map((step) => {
      const linked = (step.hops || []).includes(api.state.selected);
      const faded = api.state.query && !(step.hops || []).some((id) => api.matches(api.byId.get(id)));
      return api.h('li', { class: ['step', linked ? 'linked' : '', faded ? 'faded' : ''].join(' ').trim() }, step.text, api.badges(step.hops));
    });
    return api.h('ol', { class: 'steps' }, items);
  }

  function branches(api) {
    const rows = (api.trace.branches || []).map((branch) => api.h('div', { class: 'branch' },
      api.h('span', { class: 'chip ' + (branch.taken ? 'tone-good' : 'tone-plain'), text: branch.taken ? 'taken' : 'not taken' }),
      api.h('span', {}, branch.name, api.badges([branch.at])),
      api.h('code', { class: 'trigger', text: branch.trigger }),
      branch.outcome ? api.h('span', { class: 'outcome', text: branch.outcome }) : null));
    return rows.length ? api.h('div', {}, rows) : api.h('p', { class: 'empty', text: 'No decision points on this path.' });
  }

  function failure(api) {
    const fail = api.trace.failure || {};
    return api.h('div', {},
      api.h('h3', {}, fail.title || 'Failure path', api.badges(fail.hops)),
      api.h('ol', {}, (fail.steps || []).map((line) => api.h('li', { text: line }))));
  }

  function shapes(api) {
    const entries = (api.trace.shapes || []).flatMap((shape) => [
      api.h('dt', {}, api.badges([shape.at]), shape.label),
      api.h('dd', {}, api.h('code', { text: shape.shape }))]);
    return entries.length ? api.h('dl', { class: 'shapes' }, entries) : api.h('p', { class: 'empty', text: 'No data shapes were recorded.' });
  }

  function decisions(api) {
    const items = (api.trace.decisions || []).map((decision) => api.h('li', {},
      api.h('p', {}, decision.text, api.badges(decision.hops)),
      api.h('p', { class: 'outcome' }, 'The alternative would have cost: ' + decision.alternative)));
    return items.length ? api.h('ol', {}, items) : api.h('p', { class: 'empty', text: 'No design decisions were recorded.' });
  }

  function quiz(api) {
    const items = (api.trace.questions || []).map((question) => api.h('details', { class: 'quiz-item' },
      api.h('summary', {}, question.q, api.badges(question.hops)),
      api.h('p', { text: question.a })));
    return api.h('div', {}, api.h('p', { class: 'empty', text: 'Answer each one in your head first, then open it.' }), items);
  }

  Explore.registerPanel('overview', { label: 'Overview', render: overview });
  Explore.registerPanel('sequence', { label: 'Sequence', render: sequence });
  Explore.registerPanel('steps', { label: 'Steps', render: steps });
  Explore.registerPanel('branches', { label: 'Branches', render: branches });
  Explore.registerPanel('failure', { label: 'Failure', render: failure });
  Explore.registerPanel('shapes', { label: 'Shapes', render: shapes });
  Explore.registerPanel('decisions', { label: 'Decisions', render: decisions });
  Explore.registerPanel('quiz', { label: 'Quiz', render: quiz });
})();
