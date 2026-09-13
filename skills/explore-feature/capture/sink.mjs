// sink.mjs: the recorder the rewritten code calls. Installed once per process as
// globalThis.__explore. Every value is serialised with caps and masking at record time, so
// nothing raw ever reaches disk; events are buffered and appended as JSON lines to the file
// the runner named, on a timer, at exit, and on a signal. Nothing here throws into the code
// it observes: a value that cannot be serialised becomes a marker, and a write that fails is
// reported on stderr.
import { appendFileSync } from 'node:fs';

export const CAPS = { depth: 4, string: 200, items: 20, keys: 40, bytes: 2048, nodes: 1000, events: 20000 };
const SECRET_KEY = /pass(word|wd)?|secret|token|ticket|api[-_]?key|authorization|cookie|session|otp|ssn|iban|card|private[-_]?key|credential/i;
// Both parts stop at a URL separator, so an email inside a query keeps the path around it.
const EMAIL = /[^\s@"'<>/?&=:]+@[^\s@"'<>/?&=:]+\.[A-Za-z]{2,}/g;
const PHONE = /^(\+|\()?\d[\d ()-]{6,}\d$/;
// A hyphenated calendar date has the digits and the separators of a phone number and is not one.
const DATE = /^(\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{4})$/;
const JWT = /^eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\./;
// A token is long and mixes cases with digits; a uuid, a hex hash or a long word is not one.
const TOKEN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z0-9_\-+/=]{32,}$/;
// Inside a URL the bar is lower: a query value or a path segment of 24+ url-safe characters
// holding a digit is a ticket or a token when it has no separator (a hex ticket) or mixes
// cases (base64url); a uuid, a dated slug and a plain word are none of those.
const OPAQUE = /^(?=.*\d)(?:[A-Za-z0-9]{24,}|(?=.*[a-z])(?=.*[A-Z])[A-Za-z0-9_-]{24,})$/;
const QUERY = /([?&][^=&#\s"'<>]*)=([^&#\s"'<>]*)/g;
const SEGMENT = /\/([A-Za-z0-9_-]{24,})(?=[/?#\s"'<>]|$)/g;

// maskUrl(text): the value of every secret-shaped or opaque query parameter and every opaque
// path segment become <masked>, so a handoff ticket or an invite token never reaches disk.
function maskUrl(text) {
  return text
    .replace(QUERY, (whole, key, value) => (SECRET_KEY.test(key) || OPAQUE.test(value) ? key + '=<masked>' : whole))
    .replace(SEGMENT, (whole, segment) => (OPAQUE.test(segment) ? '/<masked>' : whole));
}

// maskString(text): personal or secret-shaped text becomes a marker; the rest is cut.
export function maskString(text) {
  if (JWT.test(text) || TOKEN.test(text)) return '<token>';
  if (PHONE.test(text) && !DATE.test(text)) return '<phone>';
  const masked = maskUrl(text).replace(EMAIL, '<email>');
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

// serialise(value, depth, ctx): the capped, masked, cycle-safe copy of any value. ctx.seen
// holds the objects on the current path; ctx.nodes counts every object and array visited,
// and past CAPS.nodes the rest becomes markers, so a wide, deep value costs a bounded walk
// rather than every node the depth cap admits.
function serialise(value, depth, ctx) {
  if (value === null || value === undefined) return value;
  const type = typeof value;
  if (type === 'string') return maskString(value);
  if (type === 'number' || type === 'boolean') return value;
  if (type === 'bigint') return value.toString() + 'n';
  if (type === 'symbol') return value.toString();
  if (type === 'function') return '<fn ' + (value.name || 'anonymous') + '>';
  if (ctx.seen.has(value)) return '<circular>';
  const special = describeSpecial(value);
  if (special !== null) return typeof special === 'object' ? serialise(special, depth, ctx) : special;
  if (depth >= CAPS.depth || ctx.nodes >= CAPS.nodes) return Array.isArray(value) ? '<array ' + value.length + '>' : '<object>';
  ctx.nodes += 1;
  ctx.seen.add(value);
  const out = Array.isArray(value) ? serialiseArray(value, depth, ctx) : serialiseObject(value, depth, ctx);
  ctx.seen.delete(value);
  return out;
}

function serialiseArray(value, depth, ctx) {
  const out = value.slice(0, CAPS.items).map((item) => serialise(item, depth + 1, ctx));
  if (value.length > CAPS.items) out.push('<' + (value.length - CAPS.items) + ' more>');
  return out;
}

function serialiseObject(value, depth, ctx) {
  const out = {};
  const proto = Object.getPrototypeOf(value);
  if (proto && proto !== Object.prototype && proto.constructor && proto.constructor.name) out['<class>'] = proto.constructor.name;
  const keys = Object.keys(value);
  for (const key of keys.slice(0, CAPS.keys)) {
    out[key] = SECRET_KEY.test(key) ? '<masked>' : serialise(readProperty(value, key), depth + 1, ctx);
  }
  if (keys.length > CAPS.keys) out['<more>'] = keys.length - CAPS.keys;
  return out;
}

// cappedText(copy): the copy, or its text cut to the byte cap when it is still too big.
function cappedText(copy) {
  const text = JSON.stringify(copy);
  if (text === undefined || text.length <= CAPS.bytes) return copy;
  return '<' + text.length + ' bytes, first ' + CAPS.bytes + '> ' + text.slice(0, CAPS.bytes);
}

// capped(value): the serialised, capped value. A value whose own traps or getters throw
// becomes a marker, because a throw here would surface inside the instrumented function, or
// as an unhandled rejection after an async exit.
export function capped(value) {
  try {
    return cappedText(serialise(value, 0, { seen: new Set(), nodes: 0 }));
  } catch (err) {
    return '<unserialisable ' + (err && err.name ? err.name : 'error') + '>';
  }
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

// settleLater(state, ctx, promise): the exit or throw of a call that handed back a native
// promise, recorded when it settles. Only a native Promise is observed: a foreign thenable
// such as a query builder runs its query on then(), and the caller's own await would run it
// again.
function settleLater(state, ctx, promise) {
  promise.then((out) => record(state, { ...settled(state, ctx, 'exit'), out: capped(out), async: true }),
    (err) => record(state, { ...settled(state, ctx, 'throw'), err: capped(err), async: true }));
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
      if (value instanceof Promise) settleLater(state, ctx, value);
      else record(state, { ...settled(state, ctx, 'exit'), out: capped(value) });
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

// exitOnSignal(sink, signal, code): flush, then end the process with the conventional code
// only when this handler is the sole listener. Registering a handler cancels the default
// exit, so with nobody else listening the process would otherwise keep running; an app with
// its own handler (a server draining its connections) owns the exit and is left to it.
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
