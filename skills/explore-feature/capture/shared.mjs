// shared.mjs: what every capture piece needs and none should re-derive. The environment
// (which trace, where the events go), the trace read into a map from absolute file path to
// the hop ranges inside it, the explored repository's own TypeScript compiler, the steps
// every loader takes before the first file loads, and the exact-path filter the Bun plugin
// needs (a Bun onLoad callback must return an object, so the filter itself has to exclude
// every file the capture does not own).
import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import { resolve, extname } from 'node:path';

const ENV_TRACE = 'EXPLORE_CAPTURE_TRACE';
const ENV_OUT = 'EXPLORE_CAPTURE_OUT';
// 1 or 0 forces the Bun preload's answer to "is this `bun test`", which decides how the
// sink's last flush happens; unset, the preload reads it off the entry file's name.
const ENV_BUN_TEST = 'EXPLORE_CAPTURE_BUN_TEST';

// readEnv(env): the two paths the runner sets, or the reason one is missing, and the
// bun-test override as given.
export function readEnv(env) {
  const tracePath = env[ENV_TRACE];
  const outPath = env[ENV_OUT];
  if (!tracePath) return { ok: false, reason: ENV_TRACE + ' is not set; capture-run.sh sets it' };
  if (!outPath) return { ok: false, reason: ENV_OUT + ' is not set; capture-run.sh sets it' };
  return { ok: true, tracePath, outPath, bunTest: env[ENV_BUN_TEST] };
}

// loadTrace(tracePath): the root and, per absolute file path, the hops whose excerpt is in
// that file, each with its inclusive line range. A trace that does not parse is a reason.
function loadTrace(tracePath) {
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
    if (!existsSync(abs)) return { ok: false, reason: 'hop ' + hop.id + ' names ' + hop.file + ', which is not under ' + trace.root };
    const list = files.get(abs) || [];
    list.push({ hop: hop.id, start: hop.range[0], end: hop.range[1] });
    files.set(abs, list);
  }
  return { ok: true, root: trace.root, files };
}

// ENV_TYPESCRIPT names a directory whose node_modules holds the compiler to rewrite with, for
// a repository that carries none the rewriter can call (typescript 7 on npm is the Go
// compiler with no JS API); unset, the explored repository's own install is used.
export const ENV_TYPESCRIPT = 'EXPLORE_CAPTURE_TYPESCRIPT';

// resolveTypescript(root): the compiler installed under the explored repository (or under
// the directory ENV_TYPESCRIPT names), resolved the way the repository's own code would
// resolve it, and checked to carry the compiler API the rewriter calls.
export function resolveTypescript(root) {
  const from = process.env[ENV_TYPESCRIPT] || root;
  let ts;
  try {
    ts = createRequire(resolve(from) + '/')('typescript');
  } catch (err) {
    return { ok: false, reason: 'typescript is not installed under ' + from + ' (' + String(err.message).split('\n')[0] + ')' };
  }
  if (typeof ts.createSourceFile === 'function' && ts.ScriptTarget) return { ok: true, ts };
  return { ok: false, reason: 'typescript ' + ts.version + ' under ' + from + ' has no compiler API; the capture needs TypeScript 5 (set ' + ENV_TYPESCRIPT + ' to a directory whose node_modules holds one)' };
}

// loadRun(tracePath): the files the trace names, with their hop ranges, and the compiler
// that rewrites them; or the first reason a run cannot start.
export function loadRun(tracePath) {
  const trace = loadTrace(tracePath);
  if (!trace.ok) return trace;
  const compiler = resolveTypescript(trace.root);
  if (!compiler.ok) return compiler;
  return { ok: true, files: trace.files, ts: compiler.ts };
}

// prepare(env): everything a loader needs before the first file loads: the two paths, the
// bun-test override, the files and the compiler; or the first reason, in the order a run
// meets them.
export function prepare(env) {
  const read = readEnv(env);
  if (!read.ok) return read;
  const run = loadRun(read.tracePath);
  if (!run.ok) return run;
  return { ok: true, tracePath: read.tracePath, outPath: read.outPath, bunTest: read.bunTest, files: run.files, ts: run.ts };
}

// failRun(reason): the run ends here with the reason on stderr, because a run without the
// capture is not the run that was asked for.
export function failRun(reason) {
  process.stderr.write('explore capture: ' + reason + '\n');
  process.exit(2);
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
