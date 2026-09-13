// hooks.node.mjs: the Node module hooks register.node.mjs installs. Runs in the loader thread:
// initialize reads the trace and resolves the compiler once, load lets Node load the module
// first (so the format and the type-stripping decision stay Node's) and then rewrites the
// source of exactly the files the trace names.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { loadRun } from './shared.mjs';
import { rewrite } from './rewrite.mjs';

let files = new Map();
let ts = null;

export function initialize(data) {
  const run = loadRun(data.tracePath);
  if (!run.ok) throw new CaptureHookError(run.reason);
  files = run.files;
  ts = run.ts;
}

class CaptureHookError extends Error {
  constructor(reason) {
    super('explore capture: ' + reason);
    this.name = 'CaptureHookError';
  }
}

function sourceText(loaded, file) {
  if (loaded.source === null || loaded.source === undefined) return readFileSync(file, 'utf8');
  return typeof loaded.source === 'string' ? loaded.source : new TextDecoder().decode(loaded.source);
}

export async function load(url, context, nextLoad) {
  const loaded = await nextLoad(url, context);
  if (!url.startsWith('file:')) return loaded;
  const file = fileURLToPath(url);
  const ranges = files.get(file);
  if (!ranges) return loaded;
  const { code } = rewrite({ source: sourceText(loaded, file), file, ranges, ts });
  return { ...loaded, source: code };
}
