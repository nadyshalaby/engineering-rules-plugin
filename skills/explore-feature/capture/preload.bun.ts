// preload.bun.ts: `bun --preload <this file> <command>`. Installs the sink in this process,
// reads the trace and the explored repository's own TypeScript, and registers a plugin whose
// onLoad rewrites exactly the files the trace names; the filter admits nothing else, since
// a Bun onLoad callback has to return an object. A missing variable, trace or compiler ends
// the run with the reason, because a run without the capture is not the run that was asked for.
import { plugin } from 'bun';
import { readEnv, loadTrace, resolveTypescript, filterRegex, loaderFor } from './shared.mjs';
import { installSink } from './sink.mjs';
import { rewrite } from './rewrite.mjs';

function fail(reason: string): never {
  process.stderr.write('explore capture: ' + reason + '\n');
  process.exit(2);
}

const env = readEnv(process.env);
if (!env.ok) fail(env.reason);
const trace = loadTrace(env.tracePath);
if (!trace.ok) fail(trace.reason);
const compiler = resolveTypescript(trace.root);
if (!compiler.ok) fail(compiler.reason);
const { ts } = compiler;
const { files } = trace;

// `bun test` ends its process without firing exit or beforeExit, so under it the sink
// flushes from a bun:test afterAll, which throws anywhere else. The runner cannot see
// through a package script, so the test runner is recognised by its entry file, a test file
// by the shapes SKILL.md Definitions name, and EXPLORE_CAPTURE_BUN_TEST=1 or =0 overrides.
const TEST_FILE = /(^|\/)(tests?|__tests__|spec)\/|\.(test|spec)\.[cm]?[jt]sx?$|_(test|spec)\.[cm]?[jt]sx?$|(^|\/)test_[^/]*$/;
function underBunTest(setting: string | undefined, main: string): boolean {
  if (setting === '1') return true;
  if (setting === '0') return false;
  return TEST_FILE.test(main);
}

const sink = installSink({ outPath: env.outPath });
if (underBunTest(env.bunTest, Bun.main)) {
  const { afterAll } = await import('bun:test');
  afterAll(() => sink.flush());
}

plugin({
  name: 'explore-capture',
  setup(build) {
    build.onLoad({ filter: filterRegex(files) }, async (args) => {
      const source = await Bun.file(args.path).text();
      const { code } = rewrite({ source, file: args.path, ranges: files.get(args.path) || [], ts });
      return { contents: code, loader: loaderFor(args.path) };
    });
  },
});
