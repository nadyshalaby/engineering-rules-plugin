// register.node.mjs: `node --import <this file> <command>`. The sink lives here, in the main
// thread, where the instrumented code runs; the load hook runs in Node's loader thread and
// gets the trace path as its data, since a compiler object cannot cross that boundary. The
// trace and the compiler are checked here first, so a bad run fails before anything loads.
import { register } from 'node:module';
import { prepare, failRun } from './shared.mjs';
import { installSink } from './sink.mjs';

const run = prepare(process.env);
if (!run.ok) failRun(run.reason);

installSink({ outPath: run.outPath });
register('./hooks.node.mjs', import.meta.url, { data: { tracePath: run.tracePath } });
