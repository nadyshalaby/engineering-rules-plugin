// rewrite.test.mjs: the rewriter over the sample fixture, the sink's masks and caps, then the
// rewritten sample run under the sink with every event checked. rewrite.test.sh runs it and
// hands it a directory holding node_modules/typescript as the first argument, since the
// rewriter resolves the explored repo's own compiler; CAPTURE_DIR points the checks at another
// copy of the capture modules, for a watched failure. One line per check, then the closing
// "N passed, M failed" line the shell harness prints.
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';

const here = fileURLToPath(new URL('.', import.meta.url));
const captureDir = resolve(process.env.CAPTURE_DIR || resolve(here, '..'));
const root = process.argv[2];
if (!root) {
  console.error('usage: node rewrite.test.mjs <dir with node_modules/typescript>');
  process.exit(2);
}
const load = (name) => import(pathToFileURL(resolve(captureDir, name)).href);
const { rewrite } = await load('rewrite.mjs');
const { resolveTypescript, readEnv, filterRegex, ENV_TYPESCRIPT } = await load('shared.mjs');
const { createSink, maskString, capped } = await load('sink.mjs');

let failures = 0;
let count = 0;
const check = (ok, what) => { count += 1; console.log((ok ? 'ok   ' : 'FAIL ') + what); if (!ok) failures += 1; };
const lines = (text) => text.split('\n').length;
const sameJson = (a, b) => JSON.stringify(a) === JSON.stringify(b);

const compiler = resolveTypescript(root);
check(compiler.ok, 'typescript resolves from the root: ' + (compiler.ok ? compiler.ts.version : compiler.reason));
if (!compiler.ok) { console.log(count - failures + ' passed, ' + failures + ' failed'); process.exit(1); }
const ts = compiler.ts;
const transpile = (code, file) => ts.transpileModule(code, { fileName: file, reportDiagnostics: true, compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ESNext } });

function checkEnv() {
  check(readEnv({}).ok === false && readEnv({ EXPLORE_CAPTURE_TRACE: 't' }).ok === false, 'readEnv refuses a missing variable: ' + readEnv({}).reason);
  check(readEnv({ EXPLORE_CAPTURE_TRACE: 't', EXPLORE_CAPTURE_OUT: 'o' }).ok, 'readEnv accepts both variables');
}

// checkCompilerApi: a typescript that carries no compiler API (typescript 7 on npm exports
// its version and a Go binary) is refused with a reason, and the override names another root.
function checkCompilerApi() {
  const noApi = resolve(root, 'no-api');
  mkdirSync(resolve(noApi, 'node_modules/typescript'), { recursive: true });
  writeFileSync(resolve(noApi, 'node_modules/typescript/package.json'), '{ "name": "typescript", "version": "7.0.0", "main": "index.js" }\n');
  writeFileSync(resolve(noApi, 'node_modules/typescript/index.js'), 'module.exports = { version: "7.0.0" };\n');
  const refused = resolveTypescript(noApi);
  check(refused.ok === false && refused.reason.includes('no compiler API'), 'a typescript without the compiler API is refused: ' + refused.reason);
  // A directory under the root would still find the root's node_modules on the walk up.
  const bare = mkdtempSync(resolve(tmpdir(), 'no-typescript-'));
  const missing = resolveTypescript(bare);
  rmSync(bare, { recursive: true });
  check(missing.ok === false && missing.reason.startsWith('typescript is not installed under ' + bare), 'a root with no typescript at all is refused: ' + missing.reason);
  process.env[ENV_TYPESCRIPT] = root;
  const overridden = resolveTypescript(noApi);
  delete process.env[ENV_TYPESCRIPT];
  check(overridden.ok === true && overridden.ts.version === ts.version, ENV_TYPESCRIPT + ' names the root the compiler comes from instead');
}

// checkRewrite: the sample rewritten over its first range; returns the rewritten code.
function checkRewrite(sampleFile, sample) {
  const outsideLine = sample.split('\n').findIndex((l) => l.startsWith('export function outside')) + 1;
  const out = rewrite({ source: sample, file: sampleFile, ranges: [{ hop: 'h1', start: 1, end: outsideLine - 1 }], ts });
  const result = transpile(out.code, sampleFile);
  check(result.diagnostics.length === 0, 'the rewritten sample parses, diagnostics ' + result.diagnostics.length);
  check(lines(out.code) === lines(sample), 'the line count is kept: ' + lines(out.code));
  check(out.code.startsWith('"use strict";const __explore_rt'), 'the directive prologue stays first: ' + JSON.stringify(out.code.slice(0, 40)));
  check(!out.code.split('\n').slice(outsideLine - 1).join('\n').includes('__explore'), 'the function outside the range is untouched');
  check(!out.code.includes('get count(): number { const'), 'the getter is untouched');
  const names = out.anchors.map((a) => a.name).join(',');
  check(names === 'sendEstimate,classify,boom,later,(fn in new Promise),(fn in setTimeout),Orders.add,twice,(fn in emitter.on),log', 'anchor names in source order: ' + names);
  check(out.anchors.length === 10 && out.anchors[0].line === 4 && out.anchors[6].line === 30, 'anchor lines are the declaration lines');
  check(out.anchors.every((a) => a.hop === 'h1' && a.file === sampleFile), 'every anchor carries its hop and file');
  const untouched = rewrite({ source: sample, file: sampleFile, ranges: [{ hop: 'h1', start: 200, end: 300 }], ts });
  check(untouched.code === sample && untouched.anchors.length === 0, 'no anchor in range: the source comes back as it is');
  const filter = filterRegex(new Map([[sampleFile, []]]));
  check(filter.test(sampleFile) && !filter.test(sampleFile + 'x') && !filter.test('/' + sampleFile), 'the load filter matches the exact path only');
  return result.outputText;
}

function checkMasks() {
  check(maskString('nady@example.com wrote') === '<email> wrote', 'an email is masked');
  check(maskString('+20 10 1170 0133') === '<phone>', 'a phone number is masked');
  check(maskString('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abc') === '<token>', 'a jwt is masked');
  check(maskString('x'.repeat(300)).length === 201, 'a long string is cut to 200 and an ellipsis');
  check(sameJson(capped({ password: 'p', nested: { apiKey: 'k', ok: 1 } }), { password: '<masked>', nested: { apiKey: '<masked>', ok: 1 } }), 'secret-shaped keys are masked at any depth');
  const ring = { a: 1 };
  ring.self = ring;
  check(sameJson(capped(ring), { a: 1, self: '<circular>' }), 'a cycle is marked');
  check(capped(new Array(50).fill(0)).length === 21, 'an array is capped to 20 items and a marker');
  const wide = Object.fromEntries(Array.from({ length: 30 }, (_, i) => ['k' + i, 'y'.repeat(150)]));
  const cappedWide = capped(wide);
  check(typeof cappedWide === 'string' && cappedWide.length < 2200 && cappedWide.startsWith('<'), 'a value over the byte cap becomes a marker: ' + String(cappedWide).slice(0, 40));
  check(sameJson(capped(new TypeError('bad nady@x.io')), { error: 'TypeError', message: 'bad <email>' }), 'an error keeps its name and a masked message');
}

// checkValues: the rewritten module behaves exactly as the original would.
async function checkValues(mod) {
  check(await mod.sendEstimate('wo-1', { mode: 'email', email: 'nady@example.com' }) === 'sent wo-1 to nady@example.com', 'sendEstimate returns its value unchanged');
  check(await mod.sendEstimate('wo-2', { mode: 'print', email: 'x@y.z' }) === 'printed wo-2', 'the second branch returns unchanged');
  check(mod.classify(5) === 'positive' && mod.classify(0) === 'zero', 'classify is unchanged');
  let thrown = null;
  try { mod.boom('nope'); } catch (err) { thrown = err; }
  check(thrown instanceof RangeError && thrown.message === 'nope', 'boom rethrows the same error');
  check(await mod.later(21) === 42, 'later resolves unchanged');
  const orders = new mod.Orders();
  check(orders.add('a', ['b', 'c']) === 3 && orders.count === 3, 'Orders.add is unchanged');
  check(mod.twice(4) === 8, 'twice is unchanged');
  check(mod.emitter.emit('ping', { password: ['hun', 'ter2'].join(''), user: 'nady' }) === true, 'the emitter callback runs');
  check(mod.log('') === undefined && mod.log('hello') === undefined, 'log is unchanged');
  check(mod.outside(0) === 0 && mod.outside(3) === 3, 'outside is unchanged');
}

// checkEvents: what the sink recorded while checkValues ran.
function checkEvents(events) {
  const anchors = events.filter((e) => e.k === 'anchor');
  check(anchors.length === 10 && anchors[6].name === 'Orders.add', 'the anchor table is recorded first');
  // A missing anchor reads as -1 and empty arguments, so a rewriter that skipped a function
  // reds the checks below instead of stopping the run.
  const byName = (name) => (anchors.find((a) => a.name === name) || { a: -1 }).a;
  const enters = events.filter((e) => e.k === 'enter');
  const argsOf = (name) => (enters.find((e) => e.a === byName(name)) || { in: [] }).in;
  check((argsOf('sendEstimate')[1] || {}).email === '<email>', 'an email inside the arguments is masked');
  check((argsOf('(fn in emitter.on)')[0] || {}).password === '<masked>', 'a password inside the arguments is masked');
  check(events.some((e) => e.k === 'throw' && e.a === byName('boom') && e.err.error === 'RangeError'), 'the throw is recorded for boom');
  check(events.some((e) => e.k === 'exit' && e.a === byName('later') && e.async === true && e.out === 42), 'a promise exit is recorded when it settles');
  const branches = events.filter((e) => e.k === 'branch' && e.a === byName('sendEstimate')).map((e) => e.line + ':' + e.v).join(',');
  check(branches === '5:true,5:false,8:true', 'the branches of sendEstimate in order: ' + branches);
  check(events.some((e) => e.k === 'switch' && e.a === byName('classify') && e.v === 'pos'), 'the switch value is recorded');
  check(events.some((e) => e.k === 'exit' && e.a === byName('log') && e.void === true), 'a body that falls off the end records a void exit');
  check(events.some((e) => e.k === 'exit' && e.a === byName('log') && e.void !== true && e.out === undefined), 'a bare return records a plain exit with undefined');
  check(events.every((e) => e.k === 'anchor' || typeof e.seq === 'number'), 'every recorded event is numbered');
}

async function main() {
  const sampleFile = resolve(here, 'fixtures/sample.ts');
  const sample = readFileSync(sampleFile, 'utf8');
  console.log('== env');
  checkEnv();
  console.log('== the compiler');
  checkCompilerApi();
  console.log('== the rewriter over the sample');
  const rewritten = checkRewrite(sampleFile, sample);
  console.log('== the masks');
  checkMasks();
  console.log('== the rewritten sample under the sink');
  const written = [];
  let tick = 0;
  const sink = createSink({ outPath: '/dev/null', append: (text) => written.push(text), now: () => (tick += 1) });
  globalThis.__explore = sink;
  const rewrittenFile = resolve(root, 'sample.rewritten.mjs');
  writeFileSync(rewrittenFile, rewritten);
  const mod = await import(pathToFileURL(rewrittenFile).href);
  await checkValues(mod);
  await new Promise((r) => setTimeout(r, 5));
  check(sink.flush() > 0 && sink.flush() === 0, 'flush writes once, then nothing');
  checkEvents(written.join('').trim().split('\n').map((line) => JSON.parse(line)));
  console.log(count - failures + ' passed, ' + failures + ' failed');
  process.exit(failures === 0 ? 0 : 1);
}

await main();
