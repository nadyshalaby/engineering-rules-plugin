// sink.mjs: the recorder the rewritten code calls. Installed once per process as
// globalThis.__explore. Every value is serialised with caps and masking at record time, so
// nothing raw ever reaches disk; events are buffered and appended as JSON lines to the file
// the runner named, on a timer, at exit, and on a signal.
import { appendFileSync } from 'node:fs';

export const CAPS = { depth: 4, string: 200, items: 20, keys: 40, bytes: 2048, events: 20000 };
const SECRET_KEY = /pass(word|wd)?|secret|token|api[-_]?key|authorization|cookie|session|otp|ssn|iban|card|private[-_]?key|credential/i;
const EMAIL = /[^\s@"'<>]+@[^\s@"'<>]+\.[A-Za-z]{2,}/g;
const PHONE = /^(\+|\()?\d[\d ()-]{6,}\d$/;
// A hyphenated calendar date has the digits and the separators of a phone number and is not one.
const DATE = /^(\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{4})$/;
const JWT = /^eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\./;
// A token is long and mixes cases with digits; a uuid, a hex hash or a long word is not one.
const TOKEN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z0-9_\-+/=]{32,}$/;

// maskString(text): personal or secret-shaped text becomes a marker; the rest is cut.
export function maskString(text) {
  if (JWT.test(text) || TOKEN.test(text)) return '<token>';
  if (PHONE.test(text) && !DATE.test(text)) return '<phone>';
  const masked = text.replace(EMAIL, '<email>');
  return masked.length > CAPS.string ? masked.slice(0, CAPS.string) + '…' : masked;
}

function describeSpecial(value) {
  if (value instanceof Error) return { error: value.name, message: maskString(String(value.message)) };
  if (value instanceof Date) return value.toISOString();
  if (ArrayBuffer.isView(value) || value instanceof ArrayBuffer) return '<bytes ' + value.byteLength + '>';
  if (typeof Request !== 'undefined' && value instanceof Request) return '<Request ' + value.method + ' ' + maskString(value.url) + '>';
  if (typeof Response !== 'undefined' && value instanceof Response) return '<Response ' + value.status + '>';
  if (typeof Headers !== 'undefined' && value instanceof Headers) return '<Headers>';
  if (typeof value.then === 'function') return '<promise>';
  if (value instanceof Map) return { '<Map>': [...value.entries()].slice(0, CAPS.items) };
  if (value instanceof Set) return { '<Set>': [...value.values()].slice(0, CAPS.items) };
  return null;
}

function readProperty(value, key) {
  try {
    return value[key];
  } catch (err) {
    return '<unreadable ' + (err && err.name ? err.name : 'error') + '>';
  }
}

// serialise(value, depth, seen): the capped, masked, cycle-safe copy of any value.
function serialise(value, depth, seen) {
  if (value === null || value === undefined) return value;
  const type = typeof value;
  if (type === 'string') return maskString(value);
  if (type === 'number' || type === 'boolean') return value;
  if (type === 'bigint') return value.toString() + 'n';
  if (type === 'symbol') return value.toString();
  if (type === 'function') return '<fn ' + (value.name || 'anonymous') + '>';
  if (seen.has(value)) return '<circular>';
  const special = describeSpecial(value);
  if (special !== null) return typeof special === 'object' ? serialise(special, depth, seen) : special;
  if (depth >= CAPS.depth) return Array.isArray(value) ? '<array ' + value.length + '>' : '<object>';
  seen.add(value);
  const out = Array.isArray(value) ? serialiseArray(value, depth, seen) : serialiseObject(value, depth, seen);
  seen.delete(value);
  return out;
}

function serialiseArray(value, depth, seen) {
  const out = value.slice(0, CAPS.items).map((item) => serialise(item, depth + 1, seen));
  if (value.length > CAPS.items) out.push('<' + (value.length - CAPS.items) + ' more>');
  return out;
}

function serialiseObject(value, depth, seen) {
  const out = {};
  const proto = Object.getPrototypeOf(value);
  if (proto && proto !== Object.prototype && proto.constructor && proto.constructor.name) out['<class>'] = proto.constructor.name;
  const keys = Object.keys(value);
  for (const key of keys.slice(0, CAPS.keys)) {
    out[key] = SECRET_KEY.test(key) ? '<masked>' : serialise(readProperty(value, key), depth + 1, seen);
  }
  if (keys.length > CAPS.keys) out['<more>'] = keys.length - CAPS.keys;
  return out;
}

// capped(value): the serialised value, cut to the byte cap as text when it is still too big.
export function capped(value) {
  const copy = serialise(value, 0, new Set());
  const text = JSON.stringify(copy);
  if (text === undefined || text.length <= CAPS.bytes) return copy;
  return '<' + text.length + ' bytes, first ' + CAPS.bytes + '> ' + text.slice(0, CAPS.bytes);
}

// record(state, event): number and time the event, or note once that the cap was reached.
function record(state, event) {
  if (state.truncated) return;
  if (state.seq >= CAPS.events) {
    state.truncated = true;
    state.buffer.push({ k: 'truncated', seq: state.seq, t: state.now() });
    return;
  }
  event.seq = state.seq;
  event.t = state.now();
  state.seq += 1;
  state.buffer.push(event);
}

// settled(state, ctx, kind): the exit or throw event of a call, timed from its entry; the
// caller adds the value.
function settled(state, ctx, kind) {
  return { k: kind, c: ctx.id, a: ctx.anchor, ms: state.now() - ctx.t0 };
}

// callRecorders(state): the anchor table and the four calls a function body makes.
function callRecorders(state) {
  return {
    register(list) {
      const base = state.anchors.length;
      list.forEach((anchor, i) => {
        state.anchors.push(anchor);
        state.buffer.push({ k: 'anchor', a: base + i, ...anchor });
      });
      return list.map((_, i) => base + i);
    },
    enter(anchor, args) {
      state.calls += 1;
      const ctx = { id: state.calls, anchor, t0: state.now(), done: false };
      record(state, { k: 'enter', c: ctx.id, a: anchor, in: capped(args) });
      return ctx;
    },
    exit(ctx, value) {
      if (!ctx || ctx.done) return value;
      ctx.done = true;
      // Only a native promise is observed by then(); a foreign thenable such as a query
      // builder runs its query on then(), and the caller's own await would run it again.
      if (value instanceof Promise) {
        value.then((out) => record(state, { ...settled(state, ctx, 'exit'), out: capped(out), async: true }),
          (err) => record(state, { ...settled(state, ctx, 'throw'), err: capped(err), async: true }));
        return value;
      }
      record(state, { ...settled(state, ctx, 'exit'), out: capped(value) });
      return value;
    },
    threw(ctx, err) {
      if (!ctx || ctx.done) return;
      ctx.done = true;
      record(state, { ...settled(state, ctx, 'throw'), err: capped(err) });
    },
    leave(ctx) {
      if (!ctx || ctx.done) return;
      ctx.done = true;
      record(state, { ...settled(state, ctx, 'exit'), void: true });
    },
  };
}

// branchRecorders(state): a condition's truth and a switch's value, returned unchanged.
function branchRecorders(state) {
  return {
    branch(anchor, line, value) {
      record(state, { k: 'branch', a: anchor, line, v: Boolean(value) });
      return value;
    },
    switchOn(anchor, line, value) {
      record(state, { k: 'switch', a: anchor, line, v: capped(value) });
      return value;
    },
  };
}

function flush(state) {
  if (state.buffer.length === 0) return 0;
  const lines = state.buffer.splice(0, state.buffer.length);
  state.append(lines.map((event) => JSON.stringify(event)).join('\n') + '\n');
  return lines.length;
}

// createSink(options): the recorder. options.outPath is where the lines go; options.now and
// options.append exist for the tests.
export function createSink(options) {
  const state = {
    append: options.append || ((text) => appendSafely(options.outPath, text)),
    now: options.now || (() => performance.now()),
    anchors: [], buffer: [], seq: 0, calls: 0, truncated: false,
  };
  return {
    anchors: state.anchors,
    ...callRecorders(state),
    ...branchRecorders(state),
    flush: () => flush(state),
    stats: () => ({ seq: state.seq, calls: state.calls, truncated: state.truncated, anchors: state.anchors.length, pending: state.buffer.length }),
  };
}

function exitOnSignal(sink, signal, code) {
  process.on(signal, () => {
    sink.flush();
    if (process.listenerCount(signal) === 1) process.exit(code);
  });
}

// installSink(options): globalThis.__explore, created once, flushing on a timer, at exit and
// on the two signals the runner uses. Returns the sink either way.
export function installSink(options) {
  if (globalThis.__explore) return globalThis.__explore;
  const sink = createSink(options);
  globalThis.__explore = sink;
  const timer = setInterval(() => sink.flush(), 250);
  if (typeof timer.unref === 'function') timer.unref();
  process.on('beforeExit', () => sink.flush());
  process.on('exit', () => sink.flush());
  exitOnSignal(sink, 'SIGTERM', 143);
  exitOnSignal(sink, 'SIGINT', 130);
  return sink;
}

// appendSafely(path, text): a capture that cannot write reports it and never throws into
// the instrumented code.
function appendSafely(path, text) {
  try {
    appendFileSync(path, text);
  } catch (err) {
    process.stderr.write('explore capture: could not write ' + path + ': ' + err.message + '\n');
  }
}
