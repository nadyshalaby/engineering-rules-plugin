// rewrite.mjs: the source rewriter. Given one file's source and the hop ranges inside it,
// every function whose start line falls in a range becomes an anchor: its body opens with
// an enter record, its own return statements go through exit, a throw is recorded and
// rethrown, a body that never returns records a void exit, and every if, ternary and switch
// condition inside it is recorded. Everything is done with insertions at positions, applied
// from the end of the file backwards, so no edit moves another; a nested function keeps its
// own anchor and its own returns. Files with no anchor come back untouched.
import { hopFor } from './shared.mjs';

const RUNTIME = '__explore_rt';
const ANCHORS = '__explore_anchors';
const CTX = '__explore_c';
const ERR = '__explore_e';
const FALLBACK = 'const ' + RUNTIME + ' = globalThis.__explore || { register: (l) => l.map((_, i) => i), enter: () => null, exit: (c, v) => v, threw: () => {}, leave: () => {}, branch: (a, l, v) => v, switchOn: (a, l, v) => v }; ';
const lineAt = (sf, pos) => sf.getLineAndCharacterOfPosition(pos).line + 1;

// rewrite({ source, file, ranges, ts }): { code, anchors }. No insertion carries a newline,
// so every line keeps its number and stack traces still point at the source.
export function rewrite(options) {
  const { source, file, ranges, ts } = options;
  const sf = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, scriptKind(ts, file));
  const state = { ts, sf, ranges, file, anchors: [], edits: [] };
  visit(state, sf, null);
  if (state.anchors.length === 0) return { code: source, anchors: [] };
  const header = FALLBACK + 'const ' + ANCHORS + ' = ' + RUNTIME + '.register(' + JSON.stringify(state.anchors) + '); ';
  state.edits.push({ pos: headerPosition(ts, sf), text: header, header: true });
  return { code: apply(source, state.edits), anchors: state.anchors };
}

function scriptKind(ts, file) {
  if (file.endsWith('.tsx')) return ts.ScriptKind.TSX;
  if (file.endsWith('.jsx')) return ts.ScriptKind.JSX;
  if (/\.(js|mjs|cjs)$/.test(file)) return ts.ScriptKind.JS;
  return ts.ScriptKind.TS;
}

// headerPosition(ts, sf): after the directive prologue ('use strict', 'use client'), which
// only counts while it is first; else at the first statement, past a shebang or a comment.
function headerPosition(ts, sf) {
  let pos = sf.statements.length > 0 ? sf.statements[0].getStart(sf) : 0;
  for (const statement of sf.statements) {
    if (!ts.isExpressionStatement(statement) || !ts.isStringLiteral(statement.expression)) break;
    pos = statement.getEnd();
  }
  return pos;
}

// apply(source, edits): insert every edit's text at its position, last position first. At one
// position the header comes first, then the closes with the innermost (registered last)
// first, then the opens in registration order; `return () => x` is the case where a return's
// close and an arrow's close share the position and the arrow's must come first.
function apply(source, edits) {
  const rank = (edit, i) => (edit.header ? -Infinity : edit.close ? -1 - i : i);
  const ordered = edits.map((edit, i) => ({ ...edit, rank: rank(edit, i) })).sort((a, b) => b.pos - a.pos || b.rank - a.rank);
  let out = source;
  for (const edit of ordered) out = out.slice(0, edit.pos) + edit.text + out.slice(edit.pos);
  return out;
}

function isAnchorable(ts, node) {
  if (!ts.isFunctionLike(node) || !node.body) return false;
  if (ts.isGetAccessor(node) || ts.isSetAccessor(node) || ts.isConstructorDeclaration(node)) return false;
  return !node.asteriskToken;
}

// visit(state, node, fn): walk the tree; fn is the anchor index of the nearest enclosing
// anchored function, or null.
function visit(state, node, fn) {
  const { ts } = state;
  let current = fn;
  if (isAnchorable(ts, node)) current = anchorFunction(state, node);
  else if (current !== null && ts.isFunctionLike(node)) current = null;
  if (current !== null && current === fn) rewriteInside(state, node, fn);
  ts.forEachChild(node, (child) => visit(state, child, current));
}

// anchorFunction(state, node): register the function as an anchor when its start line is in
// a range, splice its entry, exit and error records, and return its index (or null).
function anchorFunction(state, node) {
  const { ts, sf } = state;
  const line = lineAt(sf, (node.name || node).getStart(sf));
  const hop = hopFor(state.ranges, line);
  if (hop === null) return null;
  const index = state.anchors.length;
  state.anchors.push({ hop, file: state.file, line, name: nameOf(ts, node, sf), kind: kindOf(ts, node) });
  const enter = 'const ' + CTX + ' = ' + RUNTIME + '.enter(' + ANCHORS + '[' + index + '], ' + argsExpression(ts, node, sf) + '); try { ';
  const close = ' } catch (' + ERR + ') { ' + RUNTIME + '.threw(' + CTX + ', ' + ERR + '); throw ' + ERR + ' } finally { ' + RUNTIME + '.leave(' + CTX + ') }';
  if (ts.isBlock(node.body)) {
    state.edits.push({ pos: node.body.getStart(sf) + 1, text: ' ' + enter });
    state.edits.push({ pos: node.body.getEnd() - 1, text: close + ' ', close: true });
    return index;
  }
  state.edits.push({ pos: node.body.getStart(sf), text: '{ ' + enter + 'return ' + RUNTIME + '.exit(' + CTX + ', (' });
  state.edits.push({ pos: node.body.getEnd(), text: '))' + close + ' }', close: true });
  return index;
}

// rewriteInside(state, node, fn): a return, if, ternary or switch that belongs to the
// anchored function fn (not to a function nested in it).
function rewriteInside(state, node, fn) {
  const { ts, sf } = state;
  const open = (method) => RUNTIME + '.' + method + '(' + ANCHORS + '[' + fn + '], ' + lineAt(sf, node.getStart(sf)) + ', (';
  if (ts.isReturnStatement(node)) return rewriteReturn(state, node);
  if (ts.isIfStatement(node)) return wrap(state, node.expression, open('branch'));
  if (ts.isConditionalExpression(node)) return wrap(state, node.condition, open('branch'));
  if (ts.isSwitchStatement(node)) return wrap(state, node.expression, open('switchOn'));
  return undefined;
}

function rewriteReturn(state, node) {
  const { sf } = state;
  const keywordEnd = node.getStart(sf) + 'return'.length;
  if (!node.expression) {
    state.edits.push({ pos: keywordEnd, text: ' ' + RUNTIME + '.exit(' + CTX + ', undefined)' });
    return;
  }
  state.edits.push({ pos: keywordEnd, text: ' ' + RUNTIME + '.exit(' + CTX + ', (' });
  state.edits.push({ pos: node.expression.getEnd(), text: '))', close: true });
}

// wrap(state, expression, open): `open` before the expression, its two closing parens after.
function wrap(state, expression, open) {
  state.edits.push({ pos: expression.getStart(state.sf), text: open });
  state.edits.push({ pos: expression.getEnd(), text: '))', close: true });
}

function kindOf(ts, node) {
  if (ts.isArrowFunction(node)) return 'arrow';
  if (ts.isMethodDeclaration(node)) return 'method';
  return 'function';
}

// nameOf(ts, node, sf): the function's own name, the variable or property it is assigned
// to, or the call it is passed to.
function nameOf(ts, node, sf) {
  const parent = node.parent;
  if (node.name) {
    const own = node.name.getText(sf);
    const inClass = parent && ts.isClassLike(parent) && parent.name;
    return inClass ? parent.name.getText(sf) + '.' + own : own;
  }
  if (!parent) return '(anonymous)';
  if (ts.isVariableDeclaration(parent) || ts.isPropertyAssignment(parent) || ts.isPropertyDeclaration(parent)) return parent.name.getText(sf);
  if (ts.isCallExpression(parent)) return '(fn in ' + calleeText(parent, sf) + ')';
  if (ts.isNewExpression(parent)) return '(fn in new ' + calleeText(parent, sf) + ')';
  if (ts.isExportAssignment(parent)) return '(default export)';
  return '(anonymous)';
}

function calleeText(call, sf) {
  return call.expression.getText(sf).split('\n')[0].slice(0, 40);
}

// argsExpression(ts, node, sf): an array literal that reads every parameter by name; a
// binding pattern is rebuilt as a literal of its bindings, defaults and types dropped.
function argsExpression(ts, node, sf) {
  const parts = [];
  for (const param of node.parameters) {
    if (ts.isIdentifier(param.name) && param.name.text === 'this') continue;
    parts.push(bindingExpression(ts, param.name, sf));
  }
  return '[' + parts.join(', ') + ']';
}

function bindingExpression(ts, name, sf) {
  if (ts.isIdentifier(name)) return name.text;
  if (ts.isObjectBindingPattern(name)) {
    const props = name.elements.map((element) => {
      const value = bindingExpression(ts, element.name, sf);
      if (element.dotDotDotToken) return '...' + value;
      if (element.propertyName) return propertyKey(ts, element.propertyName, sf) + ': ' + value;
      return value;
    });
    return '{ ' + props.join(', ') + ' }';
  }
  if (ts.isArrayBindingPattern(name)) {
    const items = name.elements.map((element) => (ts.isOmittedExpression(element) ? 'undefined' : (element.dotDotDotToken ? '...' : '') + bindingExpression(ts, element.name, sf)));
    return '[' + items.join(', ') + ']';
  }
  return 'undefined';
}

function propertyKey(ts, name, sf) {
  if (ts.isComputedPropertyName(name)) return name.getText(sf);
  if (ts.isIdentifier(name)) return name.text;
  return name.getText(sf);
}
