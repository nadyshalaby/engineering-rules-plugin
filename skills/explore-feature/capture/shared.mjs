// shared.mjs: what every capture piece needs and none should re-derive. The environment
// (which trace, where the events go), the trace read into a map from absolute file path to
// the hop ranges inside it, the explored repository's own TypeScript compiler, and the
// exact-path filter the Bun plugin needs (a Bun onLoad callback must return an object, so the
// filter itself has to exclude every file the capture does not own).
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { resolve, extname } from 'node:path';

export const ENV_TRACE = 'EXPLORE_CAPTURE_TRACE';
export const ENV_OUT = 'EXPLORE_CAPTURE_OUT';

// readEnv(env): the two paths the runner sets, or the reason one is missing.
export function readEnv(env) {
  const tracePath = env[ENV_TRACE];
  const outPath = env[ENV_OUT];
  if (!tracePath) return { ok: false, reason: ENV_TRACE + ' is not set; capture-run.sh sets it' };
  if (!outPath) return { ok: false, reason: ENV_OUT + ' is not set; capture-run.sh sets it' };
  return { ok: true, tracePath, outPath };
}

// loadTrace(tracePath): the root and, per absolute file path, the hops whose excerpt is in
// that file, each with its inclusive line range. A trace that does not parse is a reason.
export function loadTrace(tracePath) {
  let trace;
  try {
    trace = JSON.parse(readFileSync(tracePath, 'utf8'));
  } catch (err) {
    return { ok: false, reason: tracePath + ' is not readable JSON: ' + err.message };
  }
  if (!trace || typeof trace.root !== 'string' || !Array.isArray(trace.hops)) {
    return { ok: false, reason: tracePath + ' has no root or no hops' };
  }
  const files = new Map();
  for (const hop of trace.hops) {
    if (!hop.file || !Array.isArray(hop.range) || hop.range.length !== 2) continue;
    const abs = resolve(trace.root, hop.file);
    const list = files.get(abs) || [];
    list.push({ hop: hop.id, start: hop.range[0], end: hop.range[1] });
    files.set(abs, list);
  }
  return { ok: true, root: trace.root, files };
}

// resolveTypescript(root): the compiler installed under the explored repository, resolved
// the way the repository's own code would resolve it.
export function resolveTypescript(root) {
  try {
    const require = createRequire(resolve(root) + '/');
    return { ok: true, ts: require('typescript') };
  } catch (err) {
    return { ok: false, reason: 'typescript is not installed under ' + root + ' (' + err.message + ')' };
  }
}

// hopFor(ranges, line): the hop whose range holds the line; the narrowest range wins when
// two hold it, since a nested hop describes the line better than the frame around it.
export function hopFor(ranges, line) {
  let best = null;
  for (const r of ranges) {
    if (line < r.start || line > r.end) continue;
    if (best === null || r.end - r.start < best.end - best.start) best = r;
  }
  return best ? best.hop : null;
}

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// filterRegex(files): matches exactly the instrumented paths and nothing else.
export function filterRegex(files) {
  const paths = [...files.keys()].map(escapeRegex);
  return new RegExp('^(?:' + paths.join('|') + ')$');
}

const LOADERS = { '.ts': 'ts', '.tsx': 'tsx', '.mts': 'ts', '.cts': 'ts', '.js': 'js', '.jsx': 'jsx', '.mjs': 'js', '.cjs': 'js' };

// loaderFor(path): the Bun loader name for the file's extension, 'js' when unknown.
export function loaderFor(path) {
  return LOADERS[extname(path)] || 'js';
}
