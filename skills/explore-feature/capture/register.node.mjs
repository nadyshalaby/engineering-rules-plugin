// register.node.mjs: `node --import <this file> <command>`. The sink lives here, in the main
// thread, where the instrumented code runs; the load hook runs in Node's loader thread and
// gets the trace path as its data, since a compiler object cannot cross that boundary. The
// trace and the compiler are checked here first, so a bad run fails before anything loads.
import { register } from 'node:module';
import { readEnv, loadTrace, resolveTypescript } from './shared.mjs';
import { installSink } from './sink.mjs';

function fail(reason) {
  process.stderr.write('explore capture: ' + reason + '\n');
  process.exit(2);
}

const env = readEnv(process.env);
if (!env.ok) fail(env.reason);
const trace = loadTrace(env.tracePath);
if (!trace.ok) fail(trace.reason);
const compiler = resolveTypescript(trace.root);
if (!compiler.ok) fail(compiler.reason);

installSink({ outPath: env.outPath });
register('./hooks.node.mjs', import.meta.url, { data: { tracePath: env.tracePath } });
