---
slug: 2026-09-13-runtime-capture
title: Runtime capture for explore-feature, real values at every anchor
status: implementing
type: feature
created: 2026-09-13
project: engineering-rules-plugin
related: []
base: 5c2c495
current_task: T18
worktree: null
branch: null
page_url: https://claude.ai/code/artifact/cb124491-1c35-4e68-839d-7bbf10312799
sprint_goal: |
  An explore page can carry one real run of the traced code: at every function inside a hop's
  excerpt the actual arguments, the value returned or the error thrown, the time it took, and
  which way every branch went, masked before they reach disk, from the project's own test or
  from a request the user fires by hand, on Bun and on Node, without writing into the repo.
---

# Runtime capture for explore-feature, real values at every anchor

## 0. Phase ledger

- [x] Phase 1. Clarify (anchor locked, repo brief written)
- [x] Phase 2. Plan + gate (work-doc written, user "go")
- [x] Phase 2.5. Spec review (report produced, doc patched)
- [>] Phase 3. Implement (every task ticked with evidence, every stage committed, scouts run)
- [ ] Phase 4. Verify (Evidence Ledger complete, triad green, ship-gate rows present)
- [ ] Phase 5. Review (coverage ledger complete, decision table empty, fixes verified)
- [ ] Phase 6a. Re-verify + land (Steps A, B, C)
- [ ] Phase 6b. Cleanup sweep (Step D)
- [ ] Phase 6c. Archive work-doc to `done/` (Step F)
- [ ] Phase 6d. Law self-audit + update log (Step F)

## 1. Original ask

> I need to add debug behavior, that will act as the normal debug tool, it will listen to all
> anchor points (entrypoints of each function call or flow change where logic can change its
> route) and print the input and the output of this block of code. this will uncover a lot of
> explanations/justifications and answer many WHYs about the feature we are to explore or the
> problem we are trying to solve.

> start the 2.14.0 debug capture

## Primary Goal & Guardrails

- **North-Star Goal.** A reader of an explore page sees, beside each excerpt, what actually
  went in and came out of that code on one real run, so the page answers "why did it do
  that" with values instead of prose. For whom: whoever opens the page. What changes: the
  excerpts stop being static. How anyone would know: the send-estimate page shows the real
  mode, order id, status and error names from a run of the backend's own test.
- **In-Scope.** (1) A load-time rewriter that instruments every function starting inside a
  hop's excerpt and every `if`, ternary and `switch` inside those functions. (2) A capture sink
  that records entry, exit, throw, duration and branch outcomes with masking and size caps.
  (3) A Bun preload and a Node loader that apply the rewrite in memory. (4) A runner script
  with a test mode, a live mode and a stop command that writes `capture.json`. (5) A verifier
  and a secret scan over the capture. (6) The page: a Runtime block per excerpt, chips on
  anchor and branch lines, a Runtime tab, timings on the sequence diagram. (7) The route,
  schema and rubric text, the sub-skill, README, CHANGELOG, version 2.14.0. (8) Tests for
  every piece and one real capture on SyanatBackend.
- **Out-of-Scope / Non-Goals.** Runtimes other than Bun and Node. A debugger protocol client.
  Capturing loops, `&&`/`||`/`??` short-circuits, getters, setters, constructors or
  generators. Following a call into another process. Merging several runs. Editing the
  explored repository in any way. A UI for firing the live request.
- **Guardrails / Invariants.** Nothing is written inside the explored repository, in either
  mode. No raw value reaches disk before masking. A page built without a capture shows
  nothing new: no Runtime block, chip, tab or label, and every 2.13.1 view unchanged. A capture the verifier refused is never embedded. Every
  file stays under 500 lines, every function under 40, no external host on the page.
- **Success Signals.** The suite green with the new tests, shellcheck clean, `claude plugin
  validate --strict` passing; a fixture Bun project and a fixture Node project each yield a
  `capture.json` with a masked email, a thrown error and a `false` branch; `git status` of the
  fixture repo clean after the run; the send-estimate page republished with real values.
- **Open risks.** A TypeScript construct the rewriter does not handle (decorators, overloads,
  `satisfies`) is left untouched, not broken: the rewriter only splices around bodies it
  understood. Node projects with extensionless imports do not run on Node at all, capture or
  not. A test that mocks a hop's callee records the mock's values, which the page labels as
  the run's values, never as the code's contract.

## 2. Clarifying Q&A

### Q1 (intent)
**Question:** Is this the feature: a capture step that runs the traced code once for real,
records at every hop the actual arguments in and the value out (or the error, with the time
it took) plus which way each listed branch went, and shows it beside each excerpt and on the
sequence diagram?
**Answer:** Yes, that is it.

### Q2 (the request)
**Question:** Where does the one real request come from when the capture runs?
**Answer:** Both, chosen per run: the project's own test by default, a live request on the
user's word.

### Q3 (redaction)
**Question:** How much gets masked before the build?
**Answer:** Secrets plus personal data: secret-shaped keys, email and phone-shaped strings,
strings cut at 200 characters, depth 4, the secret scan refuses the build if anything slipped.

### Q4 (runtimes)
**Question:** Which runtimes does 2.14.0 capture on?
**Answer:** Bun and Node in the same release.

### Gate
**Question:** Approve this plan as written?
**Answer:** "Go (Recommended)"

## 3. Acceptance Criteria

- [ ] AC1. `capture-run.sh <trace.json> --test <command...>` runs the command under the
      rewriting loader and writes `<dir>/capture.json`: per anchor (every function whose
      start line is inside a hop's excerpt) every call's masked arguments, its return value
      or thrown error and its duration; per `if`, ternary and `switch` inside those functions
      the observed outcomes by line.
- [ ] AC2. `capture-run.sh <trace.json> --live <command...>` starts the command instrumented
      in the background and `capture-run.sh --stop <dir>` collects the same file after the
      user's request.
- [ ] AC3. Both modes leave the explored repository untouched: the loaders rewrite in memory
      only, and the fixture tests assert `git status --porcelain` is empty after a run.
- [ ] AC4. Masking happens before a value reaches disk: keys matching the secret list, email,
      phone, JWT and long-token shaped strings; strings cut at 200 characters, objects at
      depth 4, arrays at 20 items, 40 keys, 2 KB per value; the runner's secret scan (the 9.5
      block) refuses a capture that still carries one.
- [ ] AC5. The runner's verify step refuses a capture whose anchor names a hop or a line the
      trace does not have, and `build-page.sh` embeds a capture only after that step passed.
- [ ] AC6. The page shows, per excerpt, a Runtime block (each call: in, out or threw, ms),
      a chip on every anchor line (calls and ms) and on every branch line (true or false), a
      Runtime tab (run summary, per-hop table) and ms labels on the sequence diagram arrows.
      A page built without a capture shows none of these and every 2.13.1 view unchanged.
- [ ] AC7. 16.9 carries the capture step, its two modes and the `Captured:` handoff line;
      16.10 the `capture.json` contract and the optional `branches[].line`; 16.11 the rule
      that captured values are observations of one run and never the code's contract; the
      sub-skill, README and CHANGELOG say so; the version is 2.14.0.
- [ ] AC8. Tests: the rewriter over a fixture file; the runner in test and live mode on a
      fixture Bun project and in test mode on a fixture Node project; the aggregate and
      verify jq; the builder's optional blob; the page template guard. Suite green, shellcheck
      clean, validate strict passing.
- [ ] AC9. One real capture on SyanatBackend from its estimates service test, the
      send-estimate page republished with the values and no unmasked email on it.
- [ ] All tests pass, 0 failures
- [ ] Lint clean (shellcheck), validate clean
- [ ] Original ask demonstrably met (the republished page)

## 4. Approach

**Chosen.** Instrument at load time, never on disk. A rewriter built on the explored
repository's own `typescript` compiler (resolved through `createRequire` from `root`) parses
each cited file, finds every function-like node whose start line is inside a hop's excerpt,
and splices: the body opens with `__explore.enter(anchor, [args])`, every `return X` becomes
`return __explore.exit(ctx, (X))`, the body is wrapped in try/catch/finally that records a
throw or a void exit, and every `if`, ternary and `switch` condition is wrapped in
`__explore.branch(anchor, line, (cond))`. Arrow functions with an expression body are turned
into a block first; nested functions get their own anchor and are not touched by the outer
one's return rewrite. The sink (`globalThis.__explore`) serialises with caps and masking at
record time and flushes JSONL to `EXPLORE_CAPTURE_OUT` on a timer and on exit or signal. A
Bun plugin (`bun --preload`) and a Node loader (`node --import`, `nextLoad` first, then
rewrite what Node returned) apply the same rewriter. The runner injects the flag into the
user's command, waits (test) or backgrounds and stops (live), aggregates the JSONL into
`capture.json` with jq, verifies it against the trace, scans it for secrets, and the builder
takes it as an optional fourth argument.

**Considered & rejected.**
- Bun's `--inspect` debugger protocol (WebKit inspector) with per-line breakpoints: no
  stable client library, off-line-number breakpoints are fragile, and it cannot see Node.
- Rewriting files in a scratch worktree copy of the repository: writes into a repository copy,
  and the copy loses `.env`, keys and the database the app expects, so the run is not real.
- `Proxy` wrappers around exported functions only: misses every internal call
  (`emailSend → runEmailPath` in the same file), which is most of a trace.

**Architectural touchpoints.** New `skills/explore-feature/capture/` (`shared.js`, `sink.js`,
`rewrite.js`, `preload.bun.ts`, `register.node.mjs`, `hooks.node.mjs`, `tests/`); new
`scripts/capture-run.sh`, `capture-aggregate.jq`, `capture-verify.jq`; `scripts/build-page.sh`
(optional fourth argument, `<!--CAPTURE-->` marker); `assets/page.js` (two seams and a
capture lookup), `assets/page-capture.js` (new), `assets/page-flow.js` (ms labels),
`assets/page.css`, `assets/page.html`; references 16.9, 16.10, 16.11; the explore-feature
SKILL.md; README, CHANGELOG, the two manifests. One construct per file; every file under 500
lines; shell functions under 40 lines and 3 parameters.

**Design spec.** Not UI-bearing beyond the existing page template's own tokens; the new
blocks use the GitHub palette already in `page.css`.

### Repo Brief

- **Stack:** bash 3.2 plugin, jq, node 24 and bun 1.4 for the page scripts and their tests
  ← `bash --version`, `bun --version` (1.4.0), `node --version` (v24.13.0)
- **Commands:** test `for t in tests/*.test.sh hooks/tests/*.test.sh skills/*/scripts/tests/*.test.sh; do bash "$t"; done`,
  lint `shellcheck -x -P SCRIPTDIR -S style hooks/*.sh hooks/tests/*.sh tests/*.sh skills/*/scripts/*.sh skills/*/scripts/tests/*.sh skills/*/scripts/tests/fixtures/*.sh`,
  validate `claude plugin validate --strict .` ← all three ran this session, 16 files green,
  shellcheck clean, validation passed
- **Layout:** `skills/explore-feature/{assets,scripts}` hold the page template and the two
  scripts, `scripts/tests` their tests, `tests/` the repo-wide guards ← `ls skills/explore-feature`
- **Layering rule:** scripts never edit the explored repository; the page is self-contained
  and reaches no host ← `tests/explore-feature-page.test.sh:38`
- **Rules source:** the plugin's own law, `skills/engineering-rules/SKILL.md` 1.1 ← read
- **Test convention:** `tests/harness.sh` with `assert_contains`, `assert_eq`,
  `assert_missing`, `report`; a `$WORK` temp dir; node-run JS tests wrapped by a `.test.sh`
  ← `skills/explore-feature/scripts/tests/page-highlight.test.sh`
- **Design spec:** absent; the page template's tokens are the system ← `assets/page.css`
- **Base commit:** 5c2c495 ← `git rev-parse HEAD`
- **Landmines:** a Bun `onLoad` callback must return an object, so the filter regex must
  match only the instrumented files ← spike, `TypeError: onLoad() expects an object`;
  Node's load hook runs off the main thread, so the sink is installed by the `--import` file
  and the rewrite happens in the hook, after `nextLoad`, on a `module-typescript` byte source ← spike, `[format] module-typescript object`; the plugin
  repo has no `node_modules`, so tests take `typescript` from a fixture project installed
  with `bun add -d typescript` (cached locally) ← `ls ~/.bun/install/cache | grep typescript`
  (5 versions cached); no backend test fires the HTTP route with `mode: 'email'`, so the
  real capture reaches the hops the estimates service test drives ← `grep -rn send-estimate test`

### Execution stages

```
Stage 1, foundation:   T1, T2, T3a, T3b (shared helpers, the sink, the rewriter; no loader yet)
Stage 2, loaders:      T4, T5          (Bun preload, Node loader, both over the same rewriter)
Stage 3, runner:       T7, T8, T6a, T6b (the two jq files and the contract first, then the runner)
Stage 4, page:         T9, T10, T11    (seams and builder, the capture renderer, diagram labels)
Stage 5, route:        T12, T13, T14   (16.9, 16.11, sub-skill + README + CHANGELOG + version)
Stage 6, testing:      T15, T16, T17   (rewriter, runner on both fixtures, builder + template)
Stage 7, proof:        T18             (the real capture on SyanatBackend, the page republished)
```

## 5. Sprint Backlog

- [x] T1. `capture/shared.mjs`: read `EXPLORE_CAPTURE_TRACE` and `EXPLORE_CAPTURE_OUT`, map
      each cited file to its hops and ranges, resolve `typescript` from `root` through
      `createRequire`, build the anchor table — files: `skills/explore-feature/capture/shared.mjs`
      → verify: `node -e` loads it against the sample trace and prints 8 files with ranges
- [x] T2. `capture/sink.mjs`: `globalThis.__explore` with `register`, `enter`, `exit` (thenable
      aware), `threw`, `leave`, `branch`, the serialiser (caps, masking) and the flush (timer,
      exit, SIGINT, SIGTERM) — files: `skills/explore-feature/capture/sink.mjs`
      → verify: a node one-liner records an email argument as `<email>` and a thrown error
- [x] T3a. `capture/rewrite.mjs`, functions: the AST walk, the anchor table, argument
      expressions from identifiers and binding patterns, block and concise bodies, entry, own
      returns, throw and void exit, nested functions left to their own anchor — files:
      `skills/explore-feature/capture/rewrite.mjs`
      → verify: the rewritten sample controller parses (`ts.transpileModule` no diagnostics)
      and carries one `enter` per function in range
- [x] T3b. `capture/rewrite.mjs`, branches: `if`, ternary and `switch` conditions wrapped
      inside anchored functions only, insertions applied from the end so positions hold —
      files: the same
      → verify: the sample middleware yields one `branch` per `if` and none in a nested arrow
- [x] T4. `capture/preload.bun.ts`: the Bun plugin with an exact-path filter and the loader by
      extension — files: `skills/explore-feature/capture/preload.bun.ts`
      → verify: `bun --preload` over the spike prints enter and exit records
- [x] T5. `capture/register.node.mjs` + `capture/hooks.node.mjs`: sink in the main thread,
      rewrite after `nextLoad` — files: the two named
      → verify: `node --import` over the spike prints the same records
- [x] T6a. `scripts/capture-run.sh`, test mode: usage, runtime detection, flag injection, env,
      run, then aggregate, verify, secret scan, `capture.json` — files:
      `skills/explore-feature/scripts/capture-run.sh` and
      `scripts/secret-scan.sh`, the one place the 9.5 secret block is run over files, which
      `build-page.sh` now calls too (added at Stage 3, the review sees it)
      → verify: usage on no args; the fixture run writes capture.json and prints one line
- [x] T6b. `scripts/capture-run.sh`, live mode: `--live` backgrounds the command with its pid
      and output under the folder, `--stop` signals it, waits for the flush and runs the same
      aggregate, verify and scan — files: the same
      → verify: the fixture app answers a curl while instrumented, `--stop` yields capture.json
- [x] T7. `scripts/capture-aggregate.jq` (events to calls and branches per anchor) and
      `scripts/capture-verify.jq` (anchors resolve to trace hops and ranges) — files: the two
      → verify: `jq -f` over a hand-written JSONL yields two calls and one branch
- [x] T8. 16.10: the `capture.json` contract, `branches[].line`, and where the file lives —
      files: `references/16-other-routes/16.10-the-trace-data-schema.md`
      → verify: the section names every field the aggregate emits, cross-checked by grep
- [x] T9. `page.js` seams (`registerPaneExtra`, `registerLineMark`, `capture` lookup),
      `page.html` `<!--CAPTURE-->` blob, `build-page.sh` `--capture <capture.json>` flag (the
      plan said "optional fourth argument"; the fourth positional was already the assets dir,
      found at Stage 4) that re-runs `capture-verify.jq` against the trace and the secret scan
      and refuses on any line, and every class the renderer will use in `page.css` (`.runtime`,
      `.rt-call`, `.rt-in`, `.rt-out`, `.rt-threw`, `.rt-ms`, `.linechip`, `.linechip.is-true`,
      `.linechip.is-false`, `.rt-table`) — files: those four
      → verify: a build without a capture renders every 2.13.1 view unchanged and an empty blob
- [x] T10. `page-capture.js`: the Runtime tab, the per-excerpt block, the line chips — files:
      `skills/explore-feature/assets/page-capture.js`
      → verify: a fixture capture renders N Runtime blocks and the chips in the browser
- [x] T11. `page-flow.js`: ms labels on arrows of hops with calls — files: that one
      → verify: the diagram shows `12 ms` on an arrow in the browser
- [x] T12. 16.9: step 6b (both modes, the commands, the stop), the `Captured:` handoff line,
      two anti-rationalisations — files: `references/16-other-routes/16.9-exploring-one-feature.md`
      → verify: the step names the runner, both flags and the handoff line
- [x] T13. 16.11: captured values are observations of one run, masked, never the contract —
      files: `references/16-other-routes/16.11-the-trace-rubric.md`
      → verify: the gate gains one row about the capture
- [x] T14. Sub-skill, README, CHANGELOG, manifests at 2.14.0 — files: `skills/explore-feature/SKILL.md`,
      `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
      → verify: `grep -c 2.14.0` on each; `claude plugin validate --strict .`
- [x] T15. Tests for the rewriter — files: `skills/explore-feature/capture/tests/rewrite.test.sh`,
      `rewrite.test.mjs`, a fixture file
      → verify: watched failure on a planted un-instrumented function, then green
- [x] T16. Tests for the runner: Bun fixture in test and live mode, Node fixture in test mode,
      masking, throw, branch, repo untouched — files: `scripts/tests/capture-run.test.sh`,
      `scripts/tests/fixtures/capture-bun.fixture.sh`, `capture-node.fixture.sh`; the live
      fixture app binds port 0 and writes the port it got to a file, never a fixed port
      → verify: green, and a planted raw email in the JSONL is refused by the scan
- [x] T17. Builder and template tests — files: `scripts/tests/build-page.test.sh`,
      `tests/explore-feature-page.test.sh`
      → verify: the fourth argument embeds the blob once; the template list has page-capture.js
- [ ] T18. The real capture on SyanatBackend from its estimates service test; republish the
      send-estimate page — files: none in the plugin
      → verify: the page's Runtime tab shows the run; no `@` in any captured string

## 6. Daily Updates

### 2026-09-13, Stage 1 foundation: T1, T2, T3a, T3b

Placement (2.2, detected and stated): the skill keeps its runtime files flat in a purpose
folder with plain kebab-case names (`assets/page-flow.js`, `scripts/verify-trace.sh`), so
the capture modules sit flat in `skills/explore-feature/capture/` under the plan's names.
Test mode, every task: `test-authoring`, the tests land in Stage 6 (T15) with watched
failures; this stage's proof is a scratchpad prover the tests will be cut from.

Landed: `capture/shared.mjs` (82 lines), `capture/sink.mjs` (220), `capture/rewrite.mjs`
(187). Proven by `$S/stage1/prove.mjs`, 100 checks, `ALL OK` under Bun 1.4.0 and under
Node v24.13.0 (both runs pasted in the session, exit 0):
- the 28 files of the send-estimate trace rewritten with the backend's own TypeScript
  5.9.3 (`createRequire`): 61 anchors, `transpileModule` diagnostics 0 on every file, and
  every file keeps its line count (no insertion carries a newline, so stack traces still
  point at the source);
- the sample (10 anchors): directive prologue kept first, the function outside the range
  and the getter untouched, a file with no anchor returned byte-identical, anchor names
  `sendEstimate … Orders.add, twice, (fn in emitter.on), log` on their declaration lines;
- run under the sink: every return value unchanged, `RangeError` rethrown unchanged, the
  promise exit recorded at settle with `async: true`, branches `5:true,5:false,8:true`, the
  switch value `pos`, a void exit for a body that falls off the end, a bare `return` as a
  plain exit, args `<email>` and `password: <masked>`, every event numbered;
- masking: email, phone, jwt, 200-char cut, secret keys at any depth, cycles, arrays at 20,
  the 2 KB value cap, errors keep name and masked message.
The prover found three defects before they left the stage, all fixed: two closes at one
position were emitted outer-first (`return (input) => limiter.run(...)` broke the
concurrency limiter file), now the innermost close comes first; a callback given to `new
Promise` was named `(anonymous)`; the token mask swallowed any 32-char word (`'x'.repeat(300)`,
a uuid), now it needs mixed case and a digit.

Caps, measured: 46 functions, 0 over 40 lines (`createSink` was 81 and is split into
`callRecorders`, `branchRecorders`, `flush`); 0 functions over 3 parameters (`wrap` and
`settle` had 4); files 82/220/187 lines; `node --check` parses all three.

Triad: `claude plugin validate --strict .` → Validation passed; the 11 suites → 11 pass, 0
fail (catalog-ids 5, design-scout 67, explore-feature-page 20, hook-caps 5, hooks-wiring 12,
law-scout 96, no-control-bytes 196, sub-commands 11, build-page 39, page-highlight 15,
verify-trace 110); shellcheck: no shell file in this stage. Boot: no startup file touched.

#### Perf-scout (stage 1, 2026-09-13)

Coverage: scope 3 | covered by a table 3 | no table: none | unreadable: none (paths in 3, read 3)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| sync read of the trace | perf.async.sync-blocking | capture/shared.mjs:27 | `readFileSync(tracePath)` | none: runs once when the loader installs, never per request | false-positive |
| map of files | perf.memory.unbounded-cache | capture/shared.mjs:34 | `new Map()` | none: bounded by the trace's files, built once, never written from a handler | false-positive |
| regex after `.map(` | perf.algorithmic.regex-in-loop | capture/shared.mjs:74 | `new RegExp(...)` in the 12-line window | none: one regex per process, the window caught the map above it | false-positive |
| sync append | perf.async.sync-blocking | capture/sink.mjs:216 | `appendFileSync(path, text)` | keep: batched per flush (250 ms timer), and the exit and signal handlers cannot await an async write; an async append could be dropped at `process.exit` | staged |
| cycle set | perf.memory.unbounded-cache | capture/sink.mjs:83 | `new Set()` | none: per call, discarded with it | false-positive |
| flush timer | perf.memory.leaked-listeners | capture/sink.mjs:203 | `setInterval(..., 250)` | none: one per process, `unref`, guarded by `installSink`'s once check | false-positive |
| stringify to measure | perf.obs.eager-log-serialization | capture/sink.mjs:84 | `JSON.stringify(copy)` | none: the byte cap needs the size, and the value is already capped by depth, items and keys | false-positive |
| stringify on flush | perf.obs.eager-log-serialization | capture/sink.mjs:169 | `JSON.stringify(event)` | none: it is the write itself | false-positive |
| `await` in a window | perf.async.await-in-loop | capture/sink.mjs:130 | a comment line inside the window after `forEach(` | none: prose | false-positive |
| stringify in header | perf.obs.eager-log-serialization | capture/rewrite.mjs:25 | `JSON.stringify(state.anchors)` | none: once per rewritten file at load | false-positive |
| sort after `.map(` | perf.algorithmic.sort-in-loop | capture/rewrite.mjs:54 | `.sort(...)` in the window | none: one sort of the edit list, not inside a loop | false-positive |

#### Law-scout (stage 1, 2026-09-13)

Coverage: paths handed in 3 | paths readable 3

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| ban.bare-error | capture/rewrite.mjs:87 | `'throw ' + ERR` inside a string literal | none: generated text that rethrows the caller's own caught error, no `Error` is constructed | false-positive |

Design scout: no UI file in scope.

Sweep (13.1 classes, over the stage diff): 1 debug output 0 (`process.stderr.write` in
`appendSafely` is the failure report, not debug); 2 commented-out code 0, `removed:` markers
0; 3 ownerless markers 0 (`grep -nE 'TODO|FIXME|HACK|XXX'` over the three files: none);
4 dead code: every exported symbol has its caller here or in the plan: `hopFor` (rewrite),
`readEnv`, `loadTrace`, `resolveTypescript`, `filterRegex`, `loaderFor`, `installSink`,
`rewrite` (T4, T5), `ENV_TRACE`, `ENV_OUT` (T6a), `CAPS`, `maskString`, `capped`,
`createSink` (T15); `escapeRegex`, `serialise`, `apply`, `argsExpression` were exported and
had no second caller, so they are module-private now; 5 unused imports 0 (each of
`createRequire`, `readFileSync`, `resolve`, `extname`, `appendFileSync`, `hopFor` is used);
9 stale references 0 (no doc names these files yet; T8, T12, T14 do). Reuse search, pasted:
`grep -rn "createRequire\|maskString\|serialise\|appendFileSync\|escapeRegex\|hopFor\|transpileModule" --include=*.sh --include=*.js --include=*.mjs --include=*.jq .`
outside `capture/` → no match, so no existing equivalent. Dead code in touched files: 0
(three new files), no cleanup commit. Nothing the plan did not authorize was changed.

Commit: `feat(explore-feature): capture foundation, the sink and the rewriter` on
`feat/runtime-capture`, explicit paths, no attribution; hash recorded in the Stage 2 entry.

### 2026-09-13, Stage 2 loaders: T4, T5

Stage 1 landed as `fee790e`. Test mode, both tasks: `test-authoring` (T16 runs the fixture
projects through the runner, which runs through these loaders). Placement as stated in the
Stage 1 entry; `preload.bun.ts` keeps the plan's name and extension, a Bun-only file.

Landed: `capture/preload.bun.ts` (40 lines), `capture/register.node.mjs` (22),
`capture/hooks.node.mjs` (42); `capture/shared.mjs` gained `ENV_BUN_TEST` and a check that
every hop's file exists under the trace root. Proven over the spike project
(`$S/spike/main.ts` importing `lib.ts`, a two-anchor trace, the compiler linked into the
spike's `node_modules`), all pasted in the session:
- `bun --preload preload.bun.ts main.ts` → program output unchanged (`hi nady x2 42`),
  exit 0, 7 events (2 anchors, enter, branch, exit, enter, exit);
- `node --import register.node.mjs main.ts` → the same output, exit 0, 7 events, and
  `diff` of the two files without `t`, `ms`, `seq` → identical;
- `bun test --preload preload.bun.ts lib.test.ts` with `EXPLORE_CAPTURE_BUN_TEST=1` →
  1 pass, 5 events flushed (`branch 2:false`, `out: "hi t"`); the probe before the fix showed
  that `bun test` fires neither `exit` nor `beforeExit`, only a `bun:test` `afterAll`, and
  that `afterAll` throws outside the runner, so the runner names the case through the env;
- failure paths: no env → `EXPLORE_CAPTURE_TRACE is not set; capture-run.sh sets it`,
  exit 2 on both runtimes; a missing trace → `ENOENT`, exit 2; a trace whose root does not
  hold its files → `hop h0 names lib.ts, which is not under /tmp`, exit 2 on both.
Known and recorded, not a defect of this stage: Bun resolves `typescript` from its global
cache (`~/.bun/install/cache/typescript@7.0.2`) when the repository has none, so the
"not installed under root" reason fires on Node only.
The Stage 1 prover re-run after the `shared.mjs` change: `ALL OK` on Bun and on Node.

Caps, measured: 14 functions in the four files, 0 over 40 lines; 0 over 3 parameters;
`node --check` parses every `.mjs`. Triad: no shell file and no manifest touched, the 11
suites were green at Stage 1 and no file they cover changed; boot: nothing the plugin
loads at startup changed.

#### Perf-scout (stage 2, 2026-09-13)

Coverage: scope 4 | covered by a table 4 | no table: none | unreadable: none (paths in 4, read 4)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| sync read for a CommonJS source | perf.async.sync-blocking | capture/hooks.node.mjs:30 | `readFileSync(file)` when Node handed no source | none: once per instrumented file at load, in the loader thread | false-positive |
| file map | perf.memory.unbounded-cache | capture/hooks.node.mjs:10 | `let files = new Map()` | none: filled once from the trace in `initialize` | false-positive |
| sync trace read | perf.async.sync-blocking | capture/shared.mjs:30 | `readFileSync(tracePath)` | none: once at install | false-positive |
| exists check per hop | perf.async.sync-blocking | capture/shared.mjs:41 | `existsSync(abs)` | none: once per hop at install, bounded by the trace | false-positive |
| file map | perf.memory.unbounded-cache | capture/shared.mjs:37 | `new Map()` | none: as at Stage 1 | false-positive |
| regex in a window | perf.algorithmic.regex-in-loop | capture/shared.mjs:78 | `new RegExp` after `.map(` | none: as at Stage 1 | false-positive |

#### Law-scout (stage 2, 2026-09-13)

Coverage: paths handed in 4 | paths readable 4

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| none | | | | |

Design scout: no UI file in scope.

Sweep: 1 debug output 0 (`process.stderr.write` in the two `fail` helpers reports the
refusal, then exit 2); 2 commented-out code 0, `removed:` 0; 3 ownerless markers 0 (grep
over the four files: none); 4 dead code: `initialize` and `load` are read by Node's
`register`, `ENV_BUN_TEST` by `readEnv` and the runner (T6a), `CaptureHookError` thrown in
`initialize`; 5 unused imports 0 (`plugin`, `register`, `readFileSync`, `fileURLToPath`,
`existsSync` each used); 9 stale references 0. Reuse search, pasted:
`grep -rn "fileURLToPath\|nextLoad\|onLoad\|register(\|afterAll" --include=*.sh --include=*.js --include=*.mjs --include=*.ts .`
outside `capture/` → no match. Dead code in touched files: 0, no cleanup commit. Nothing
the plan did not authorize was changed; the env marker and the root check are the two
additions the proof forced, both inside T4 and T1's files.

Commit: `feat(explore-feature): the Bun preload and the Node loader`, explicit paths, no
attribution; hash in the Stage 3 entry.

### 2026-09-13, Stage 3 runner: T7, T8, T6a, T6b

Stage 2 landed as `2456206`. Test mode: T7 and T6a/T6b `test-authoring` (T16 covers the
runner on both fixtures, T17 the jq pair through the builder); T8 `none`, a reference file.
Placement: scripts flat in `scripts/` beside `verify-trace.sh` and `build-page.sh`, as the
skill already does; the jq pair beside `verify-trace.jq`.

A change the plan did not name, recorded here for the review: `scripts/secret-scan.sh`
(35 lines) now holds the one way the law scout's secret block (9.5) is run over files, and
`build-page.sh` calls it instead of carrying `extract_block` and the block run itself, so
the runner's scan and the builder's scan are the same 3+ lines once (1.1, DRY); T6a's file
list in the backlog names it. The refactor kept every message the build-page suite asserts:
39 passed, 0 failed after it.

Landed: `scripts/capture-aggregate.jq` (49 lines), `scripts/capture-verify.jq` (32),
`scripts/capture-run.sh` (189, 14 functions, none over 40 lines), `scripts/secret-scan.sh`,
`build-page.sh` (127, the scan through the shared script), 16.10 (+84 lines: the folder
tree, `branches[].line`, the `capture.json` contract, masking, the run's environment, the
five checks in order, the page's assumptions); `capture/rewrite.mjs` records `file` on every
anchor, `capture/shared.mjs` and `capture/preload.bun.ts` carry the bun-test decision.

Three things the proof changed in the design, all inside the plan's files:
- the loaders reach the command through the environment, `BUN_OPTIONS=--preload=…` and
  `NODE_OPTIONS=--import …`, not by editing argv: the spike showed `bun --preload x test` is
  read as a script named test, `bun --preload x run main.ts` prints help, and a package
  script's child never sees an argv flag, while both option variables reach every child
  (`bun run t` → `bun test`, `bun run nmain` → `node`);
- `bun test` cannot be told from a package script's argv, so the preload recognises the
  test runner by its entry file being a test file (the Definitions' shapes), with
  `EXPLORE_CAPTURE_BUN_TEST=1|0` as the override; the first cut keyed on the word `test` in
  the command and `bun run t` recorded nothing;
- the runner's meta file carries the trace path, since `--stop` runs in another process.

Proven, pasted in the session (`$S/stage3/prove-runner.sh` over the spike project):
- T7: the aggregate over the Stage 2 events → 2 anchors, 2 calls, 1 branch, `hops` and
  `run` rows; `capture-verify.jq` → 0 lines on it and one named line for each of 11
  mutations (a hop the trace lacks, a line and a branch line outside the range, a wrong
  file, a branch kind, a call with no outcome, no arguments, no duration, version 2, mode
  `dry`, no call at all); `secret-scan.sh` → exit 0 on the aggregate, exit 1 naming line 30
  with the value redacted on a planted AWS key, exit 2 on a missing block, no args, an
  unreadable file;
- T8: every field the aggregate emits is named in 16.10, checked by a grep over 29 names:
  `fields not named: 0`;
- T6a: no args, one arg, `--dry`, bare `--stop` → usage, exit 2; a missing trace → exit 1;
  `--test bun main.ts` and `--test node main.ts` → the program's output unchanged, `wrote
  …/capture.json: 2 anchors, 2 calls, 1 branches, 0 threw, exit 0`, identical records;
  `--test bun test lib.test.ts` and `--test bun run t` → 1 pass, 1 call, `branch 2:false`;
  a command that reaches no anchor → `no event was recorded…`, exit 1; a raw AWS-shaped
  argument the masks do not cover → `the aggregate carried a hardcoded secret at its line
  25 … deleted`, exit 1, and neither capture.json nor capture.jsonl is left;
- T6b: `--live bun server.ts` → `started pid N in the background…`, two curls answered
  (`hi nady x3`, `hi x@y.io`), `--stop` → `wrote …: 2 anchors, 2 calls, 1 branches, 0
  threw, stopped`, the email masked in both the arguments and the value, `outcomes:
  [true, false]`, the pid file gone, a second `--stop` refused;
- the override: `=0` under `bun test` → nothing recorded, as designed; `=1` under a plain
  run → `Cannot use afterAll() outside of the test runner`, a loud failure.
Stage 1 prover after the `rewrite.mjs` and `shared.mjs` changes: `ALL OK` on Bun and Node.

Triad: shellcheck clean over the whole repo (the 2.13.1 command); `claude plugin validate
--strict .` → Validation passed; 11 suites, 11 pass (no-control-bytes 203 with the new
files). Boot: the plugin loads no script at startup.

#### Perf-scout (stage 3, 2026-09-13)

Coverage: scope 8 | covered by a table 5 | no table: capture-aggregate.jq, capture-verify.jq, 16.10 (jq and markdown carry no loop or query) | unreadable: none (paths in 8, read 8)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| grep per marker | perf.process.spawn-per-item | scripts/build-page.sh:48 | `n=$(grep -c "<!--$marker-->" …)` inside `for marker in TITLE CSS JS TRACE EXCERPTS` | none: bounded driver, five literal markers, 2.13.1 code | false-positive: bounded driver, 1 candidate at build-page.sh:48 |
| sync trace read, exists per hop, file map, regex in a window | perf.async.sync-blocking, perf.memory.unbounded-cache, perf.algorithmic.regex-in-loop | capture/shared.mjs:31, :42, :38, :79 | as at Stage 2 | none: once at install, bounded by the trace | false-positive |

#### Law-scout (stage 3, 2026-09-13)

Coverage: paths handed in 8 | paths readable 8

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| none | | | | |

Design scout: no UI file in scope. The plugin's own edit guard refused two writes on the way
(`SECRET_SCAN="…/secret-scan.sh"` read as an assigned secret, and a literal AWS-shaped key in
a spike file); the variable is `SCAN_SH` and the spike assembles its planted key at runtime,
the way `build-page.test.sh` does.

Sweep: 1 debug output 0; 2 commented-out code 0, `removed:` 0; 3 ownerless markers 0 (the
one grep hit is mktemp's `XXXXXX` template); 4 dead code: `has_test_word` was added and
removed within the stage, `extract_block` left `build-page.sh` with its only caller,
`EXCERPT_IDS` is read by the scan, every runner function is called from `main` or `finish`;
5 unused imports and variables 0 (shellcheck style clean); 9 stale references 0 (16.10 names
the files that exist; 16.9 and the SKILL are T12 and T14). Reuse search, pasted:
`grep -rn "capture.meta\|runtime_label\|write_meta\|stop_live\|secret-scan" --include=*.sh --include=*.md --include=*.jq .`
outside the stage's files → no match. Dead code in touched files: 0 (`build-page.sh` read in
full, every function called), no cleanup commit.

Commit: `feat(explore-feature): the capture runner, the aggregate and the contract`,
explicit paths, no attribution; hash in the Stage 4 entry.

### 2026-09-13, Stage 4 page: T9, T10, T11

Stage 3 landed as `8da4e5c`. Test mode: T9, T10 and T11 `test-authoring` (T17 covers the
builder's `--capture` and the template list; the two existing guards were only kept truthful
here, see the sweep). Placement: `page-capture.js` flat in `assets/` beside the other three
scripts, the skill's convention; the classes in `page.css`, the seams in `page.js`.

Two deviations from the plan's wording, both inside its files:
- `build-page.sh` takes `--capture <capture.json>` rather than "an optional fourth argument":
  the fourth positional was already the assets dir (`build-page.test.sh` passes it), and a
  flag survives either order; T9's text now says so.
- `build-page.sh` re-runs the secret scan on the capture as well as `capture-verify.jq`,
  since the page is what gets published; 16.10's one sentence about the builder says
  "checks 3 and 4" now (it said 4).

Landed: `assets/page-capture.js` (152 lines, new: the block under each excerpt, the line
chips, the Runtime tab, two legend rows; registers nothing without a capture), `page.js`
(the `capture` blob, `registerPaneExtra`, `registerLineMark`, `api.capture`, `api.millis`,
tabs 1 to 9), `page.html` (the `capture-data` blob, the key legend 1 to 9), `page.css` (+31
lines: `.runtime` and the `.rt-*` family, `.linechip` and its five states, `.rt-table`,
`.seq-ms`), `page-flow.js` (`timingLabel`, fed from a Map of the capture's hop rows built
once per diagram render), `build-page.sh` (179 lines: `parse_args`, `check_capture`,
`scan_capture`, `capture_json`; the JS list and the template list gain `page-capture.js`,
the markers gain `CAPTURE`, the wrote line says `capture embedded`), and the two guards
kept truthful (`build-page.test.sh` copies the fifth script into its broken-template
fixture; `explore-feature-page.test.sh` counts six markers and parses four scripts).

Proven, pasted in the session (`$S/stage4/`; a capture fixture shaped from the smoke trace
by `fixture.jq`: 34 anchors, 34 calls, 31 branches, 6 throws, `capture-verify.jq` → 0
lines on it and one line on a planted bad hop):
- T9: a build without a capture writes `null` into the blob, and the page differs from the
  build with one in nothing but that line (`diff` after dropping the two blob lines: 0); in
  the browser the without-page has 0 Runtime blocks, 0 chips, 8 tabs, 3 legend rows,
  `api.capture` null, 39 panes, no console error; `--capture` with a bad hop → `capture
  does not match the trace: anchor 0: hop nope is not in the trace`, exit 1; an AWS-shaped
  key planted in a captured argument → `the capture carries a hardcoded secret…`, exit 1;
  a missing file, broken JSON, `--capture` with no value and an unknown flag refuse (exit
  1, 1, 2, 2) and `never.html` is never written; the assets dir still works as the fourth
  positional beside `--capture=`; the build with the fixture: `wrote … (161802 bytes,
  capture embedded)`, 0 markers left;
- T10: the with-page renders 34 Runtime blocks, 34 anchor blocks, 34 call rows, 65 chips in
  the code (34 call chips, 31 branch chips), 9 tabs ending in Runtime, 5 legend rows; the
  first chip reads `1× 1.50 ms`; hop 5's block shows the masked arguments
  `["sample-h4",{"mode":"email","email":"<email>","password":"<masked>"}]`,
  `SampleError: planted h4` in red, `5.50 ms` and `L30 true`, and its amber `1× 5.50 ms`
  chip sits beside line 29 (screenshot); the folds: with a first anchor of 7 calls the
  `2 more calls` fold holds 1 child before opening and 3 after (its 2 rows), a long value's
  pretty `pre` is absent until opened and built once across a close and reopen;
- T11: the Sequence tab shows 33 `.seq-ms` labels (34 hops with calls, the entry hop has no
  arrow), samples `2.50 ms` and `5.50 ms, threw`.
`node --check` over the four scripts: all parse. No function over 40 lines (awk over the
three scripts). Test mode of the runtime tab against the real capture is T18.

Triad: shellcheck clean over the whole repo (the 2.13.1 command); `claude plugin validate
--strict .` → Validation passed; 11 suites, 11 pass (explore-feature-page 20, build-page 39,
no-control-bytes 207). Boot: the plugin loads no script at startup; the page boots in the
browser with no console error, with and without a capture.

#### Perf-scout (stage 4, 2026-09-13)

Coverage: scope 8 | covered by a table 6 | no table: page.css, page.html (no loop or query) | unreadable: none (paths in 8, read 8)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| every call row past the fifth, and every long value's pretty form, built at boot | perf.obs.eager-log-serialization | page-capture.js:36 and :58 on the first run; :35 on the second, now inside the toggle handler | `h('pre', { text: JSON.stringify(value, null, 2) })` per long value, `calls.slice(CALLS_SHOWN).map(callRow)` per anchor | build on the `details` toggle, once (proven above: 1 child before, 3 after) | fixed |
| a linear search per arrow | perf.loop-body-candidate | page-flow.js:65 on the first run | `(api.capture.hops \|\| []).find(...)` inside `arrow()`, once per hop | `runRows`, one Map per `sequence()` render, passed in geo; the row is gone on the second run | fixed |
| the inline text of each value | perf.obs.eager-log-serialization | page-capture.js:28 | `JSON.stringify(value)` for the inline form | none: the inline text is the render itself, each value capped at 2048 bytes by the sink | false-positive |
| three maps and the run-rows map | perf.memory.unbounded-cache | page-capture.js:15-17, page-flow.js:102 | `new Map()` keyed by hop and line | none: built once from the embedded blob and bounded by it | false-positive |
| one listener | perf.memory.leaked-listeners | page-capture.js:151 | `DOMContentLoaded` → the legend rows | none: one listener for the page's life | false-positive |
| 2.13.1 lines in page.js and page-flow.js | perf.memory.unbounded-cache, perf.memory.leaked-listeners, perf.loop-body-candidate | page.js:14-21, :86, :283, :65, :323-331, :354, :134, :139, :293; page-flow.js:17, :29, :101, :143 | maps bounded by the trace, listeners bound once at boot, `includes` over tens of hops | none: pre-existing lines this stage did not write, bounded by the trace | false-positive |
| grep per marker | perf.process.spawn-per-item | build-page.sh:69 | `n=$(grep -c "<!--$marker-->" …)` over six literal markers | none: bounded driver | false-positive: bounded driver |

#### Law-scout (stage 4, 2026-09-13)

Coverage: paths handed in 8 | paths readable 8

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| ban.empty-catch | tests/explore-feature-page.test.sh:89 | `assert_missing "…" "catch (err) {}" …` | none: the guard's own needle, a string in a test | false-positive |
| ban.bare-error | page.css:186 | `.seq .arrow-throw { stroke: var(--bad); }` | none: a class name | false-positive |

#### Design-scout (stage-4, 2026-09-13)

Coverage: handed in 8, readable 8 | covered by a table 5 | no table: none | out of scope 3 | unreadable: none

| Finding | tell id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| three uppercase labels against one section | tell.label.eyebrow-everywhere | scope | `.label-caps` (page.css:72), `.overlay-sub` (:206), `.rt-k` (:223) against the one `<section>` in page.html, budget 1 | none | false-positive: product-UI overlines on the rails, the panels and the in/out/took keys of a data row (15.22 scope), not eyebrows on sections; two of the three are 2.13.1 |

Sweep: 1 debug output 0; 2 commented-out code 0, `removed:` 0; 3 ownerless markers 0; 4 dead
code both ways: 256 JS definitions across the four scripts each referenced at least twice
(word grep over the scripts and page.html; a planted `plantedDeadZz` is the one it reports;
the limit: a one-letter name like `h` cannot be told dead this way), 125 CSS classes each
named in a script or the template (a planted `.plantedzz` is reported), every function in
`build-page.sh` called (each name 2+ hits), `hopRow` was added and removed within the stage,
nothing removed left a dangling reference; 5 unused variables 0 (shellcheck style clean,
every builder variable read 3+ times); 9 stale references: 3 found and fixed in the stage
(`README.md` "five markers" twice, 16.10 "check 4"), `five markers` left: 0. Reuse search,
pasted:
`grep -rn "registerPaneExtra\|registerLineMark\|millis\|linechip\|parse_args\|check_capture\|scan_capture\|capture_json\|paneExtraRenderers\|lineMarkRenderers\|timingLabel" --include=*.js --include=*.sh --include=*.css --include=*.md --include=*.html .`
outside the stage's files → two catalog prose hits on "milliseconds", no equivalent;
`millis` replaces the same formatter written twice (page-flow.js and page-capture.js) with
one on `api`. Dead code in touched files: 0 (the counts above), no cleanup commit.

Commit: `feat(explore-feature): the capture on the page`, explicit paths, no attribution;
hash in the Stage 5 entry.

### 2026-09-13, Stage 5 route: T12, T13, T14

Stage 4 landed as `174dcc7`. Test mode: `none` for all three, reference and manifest text;
the suites that read these files (sub-commands, catalog-ids, no-control-bytes) are the
guard. Placement: no new file. The runner and the secret scan gain the executable bit the
other two scripts already had (`100644` → `100755`), since the route's ready line tests
`-x` on all three.

Two things the plan named here that this stage leaves for Stage 6 on purpose, recorded so
the review sees them: the README's test paragraph ("covers the two explore-feature
scripts") and the CHANGELOG entry say nothing about the runner's tests, because those tests
do not exist yet; both are completed when T15 to T17 land.

Landed: 16.9 (contract item 8 and a refused row; the capture in the definitions and the
ready line; step 6b with test mode, live mode, the rebuild, four refusals and the skip
rule; `Captured:` in the handoff; the re-run note; two anti-rationalisations; a does-not
bullet; the summary), 16.11 (gate row 13 with its third answer, the `Captured:` line in
section 12, section 13 in four bullets), `skills/explore-feature/SKILL.md` (the description
and step 4 name the capture and `capture/`), README (the 2.14.0 sentence in the intro, the
section "Explore a feature, with one real run", the layout tree with `capture/`, the jq
pair, `secret-scan.sh` and `page-capture.js`), CHANGELOG (the 2.14.0 entry), both
manifests at 2.14.0 with the capture in their descriptions.

Proven, pasted in the session:
- T12: 16.9 names `capture-run.sh` 7 times, `--test` 1, `--live` 2, `--stop` 2,
  `--capture` 3, `Captured:` 4, `Step 6b` 1, the override 1;
- T13: 16.11 line 241 is row 13 (`yes / no / no capture`), line 258 is section 13;
- T14: `2.14.0` in README 2, CHANGELOG 1, plugin.json 1, marketplace.json 1; the sub-skill
  carries no version string, as no sub-command skill does (`grep -l "2\.1[0-9]\.[0-9]"
  skills/*/SKILL.md` → none), its check is `capture/` named once; `claude plugin validate
  --strict .` → Validation passed; the section count the README and plugin.json quote is
  the count on disk (122);
- the two scripts: `-rwxr-xr-x` on both, so the ready line's three `test -x` pass.
Caps: 16.9 346 lines, 16.11 320, README 439, CHANGELOG 216, the sub-skill 36.

Triad: shellcheck clean over the whole repo; `claude plugin validate --strict .` passed;
11 suites, 11 pass (no-control-bytes 208 with the new text, sub-commands 11). Boot: the
plugin loads no script at startup; nothing here runs at boot.

#### Perf-scout (stage 5, 2026-09-13)

Coverage: scope 9 | covered by a table 2 (the two shell scripts, mode change only) | no table: 16.9, 16.11, SKILL.md, README, CHANGELOG, plugin.json, marketplace.json (prose and manifests carry no loop or query) | unreadable: none (paths in 9, read 9)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| none | | | | | |

#### Law-scout (stage 5, 2026-09-13)

Coverage: paths handed in 9 | paths readable 9

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| ban.suppression | README.md:157 | the guard's description names `@ts-expect-error` in prose | none: 2.13.1 prose naming the ban, shifted down by the insertion | false-positive |
| ban.suppression, ban.empty-catch, ban.bare-error | CHANGELOG.md:157, :184, :185 | earlier entries name `shellcheck disable`, `.catch(() => {})` and `reject(new Error(` | none: history naming the bans | false-positive |

Design scout: no UI file in scope.

Sweep: 1 debug output 0; 2 commented-out code 0, `removed:` 0; 3 ownerless markers 0;
4 dead code: a prose stage, no symbol added or removed, the mode change adds no code; 5
unused variables n/a; 9 stale references: the grep for "two scripts", "five markers" and
"verify-trace.sh and build-page.sh" finds one line, README's test paragraph, which is still
true until Stage 6 adds the runner tests and is completed there. Reuse search: no symbol
added, nothing to search. Dead code in touched files: 0 (prose), no cleanup commit.

Commit: `docs(explore-feature): the route runs the capture, 2.14.0`, explicit paths, no
attribution; hash in the Stage 6 entry.

### 2026-09-13, Stage 6 tests: T15, T16, T17

Stage 5 landed as `ad81150`. Test mode: the stage is the tests, and every suite was watched
red on a mutated copy before it was believed green (below). Placement: `capture/tests/`
beside the modules it tests (`rewrite.test.sh`, `rewrite.test.mjs`, `fixtures/sample.ts`);
the runner's suite and its two fixtures beside the other script suites under
`scripts/tests/` and `scripts/tests/fixtures/`, in the shape `sample-repo.fixture.sh`
already has (`build_<x>_repo`, `write_<x>_trace`).

Six things the plan did not name, found here and decided here:
- `bun add -d typescript` installs typescript 7.0.2, which ships the Go compiler only
  (`main: null`, `exports["."]` is `lib/version.cjs`, so `require('typescript')` returns
  `{ version, versionMajorMinor }` and `ts.createSourceFile` is undefined); every earlier
  proof ran on the backend's 5.9.3 through the spike's symlink. `resolveTypescript` now
  checks for the compiler API and refuses with the version and the way out;
  `EXPLORE_CAPTURE_TYPESCRIPT=<dir>` names another directory whose `node_modules` holds a
  5, since nothing is installed into an explored repository; both fixtures and the rewrite
  wrapper pin `typescript@5` (0.03 s from bun's cache); 16.10 (the run's environment), 16.9
  (the refusals), README and CHANGELOG say so. SyanatBackend carries 5.9.3, so T18 needs no
  override.
- T16's "planted raw email refused by the scan" cannot happen: the 9.5 block judges secrets,
  not emails, and the sink masks emails before disk anyway. The refusal test plants the AWS
  documentation example key, assembled at runtime so no literal sits in the fixture, and
  proves the refusal line, the deleted aggregate and events, and the untouched repo.
- The sink records an `async` function at its `return` statement, with the resolved value
  and no `async` flag; the flag marks a Promise handed back, recorded when it settles
  (sink.mjs, the foreign-thenable comment). The suite's first draft expected the flag on
  `greet`; the fixture's arrow now hands back a promise, so the aggregate's `async` fold is
  proven end to end and the `async` function's shape is asserted as it is.
- `tests/hook-caps.test.sh` audits `skills/*/capture/tests/*.sh` too (35 files, was 34), and
  the README's shellcheck command carries the same glob.
- macOS sets `TMPDIR` with a trailing slash, so the harness's `WORK` carried a double slash
  the runner's printed paths do not (it prints the trace directory as `cd` sees it);
  `capture-run.test.sh` normalises `WORK` once through `cd`/`pwd`.
- T15's "planted un-instrumented function" is three copies through `CAPTURE_DIR`, not one:
  a sink that writes `<mail>`, a `shared.mjs` without the API check, a rewriter that skips
  arrows; the suite reads a missing anchor as `-1` so the last one reds four checks instead
  of stopping the run.

Landed: `capture/tests/rewrite.test.sh` (installs `typescript@5` into a scratch root, skips
without bun, node or the install), `rewrite.test.mjs` (46 checks: env, compiler, the
rewriter over `fixtures/sample.ts`, the masks, the rewritten sample under the sink with
every event checked), `scripts/tests/capture-run.test.sh` with `fixtures/capture-bun.fixture.sh`
and `capture-node.fixture.sh` (47 checks: usage and missing inputs, Bun test mode, Node
test mode and the same-shape compare, `bun test` through `afterAll` and the `bun run t`
child and the override, the no-anchor refusal, the leak refusal, live mode on port 0 with
two requests, `--stop` and a second stop), `build-page.test.sh` (`capture_fixture` and the
`--capture` case: embedded once, checked, a hop the trace lacks, a secret, a missing file,
no value, assets dir with `--capture=`), `explore-feature-page.test.sh` (the capture is
optional: the guard, the blob element, the two seams, the keys legend), `hook-caps.test.sh`
(the glob), `shared.mjs` (`ENV_TYPESCRIPT`, the API check, the require error cut to its
first line), 16.9 and 16.10 (the requirement and the refusal), README (the test paragraph,
`typescript` 5), CHANGELOG (the override).

Proven, pasted in the session:
- T15: `rewrite.test.sh` → 46 passed, 0 failed, on typescript 5.9.3; watched red through
  `CAPTURE_DIR`: sink writing `<mail>` → 43 passed, 3 failed; API check dropped → "a
  typescript without the compiler API is refused" failed, exit 1; arrows skipped → 42
  passed, 4 failed (names, lines, the anchor table, the password inside an arrow's
  arguments);
- T16: `capture-run.test.sh` → 47 passed, 0 failed; watched red through `CAPTURE_RUN_SH` on
  a runner whose `scan` is a no-op → the three leak checks failed (the key printed, the
  aggregate written, exit 0); the fixture repos read `git status --porcelain` empty after
  every mode; the live server wrote its port 0 pick to `$PORT_FILE`, two `curl`s answered
  `hi nady` and `hi x@y.io`, the capture carries `nady` and `<email>`;
- T17: `build-page.test.sh` → 56 passed, 0 failed; watched red through `BUILD_PAGE_SH` on a
  builder whose `check_capture` is a no-op → 4 failed (the hop-less capture named, exit,
  writes nothing, the missing file); `explore-feature-page.test.sh` → 24 passed, 0 failed;
  watched red through `ASSETS_DIR` on a `page-capture.js` without `if (!capture) return;`
  → 23 passed, 1 failed;
- `hook-caps.test.sh` → 5 passed over 35 files; the seven globs on disk count 35, one of
  them under `capture/tests/`;
- the typescript finding: fresh `bun add -d typescript` → 7.0.2, `main: null`, `bin`
  `{"tsc"}`; `typescript@5` → 5.9.3 with `createSourceFile` a function and `ScriptTarget`
  an object.
Caps: rewrite.test.mjs 163 lines (functions 4 to 26), capture-run.test.sh 144,
capture-bun.fixture.sh 90, capture-node.fixture.sh 15, rewrite.test.sh 27, sample.ts 49,
shared.mjs 96 (`resolveTypescript` 11, `loadTrace` 21), build-page.test.sh 122,
explore-feature-page.test.sh 105, hook-caps.test.sh 60, README 455, CHANGELOG 221, 16.9
351, 16.10 301; hook-caps holds every shell function under 40.

Triad: 13 suites, 13 pass (catalog-ids 5, design-scout 67, explore-feature-page 24,
hook-caps 5, hooks-wiring 12, law-scout 96, no-control-bytes 208, sub-commands 11,
build-page 56, capture-run 47, page-highlight 15, verify-trace 110, rewrite 46);
shellcheck clean over the seven globs, `capture/tests` included; `claude plugin validate
--strict .` passed. Boot: nothing here runs at boot.

#### Perf-scout (stage 6, 2026-09-13)

Coverage: scope 14 | covered by a table 10 | no table: README, CHANGELOG, 16.9, 16.10 (prose) | unreadable: none (paths in 14, read 14)

| Finding | Catalog ID | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|---|
| sync fs in the test | perf.async.sync-blocking | rewrite.test.mjs:45-53, :135, :150 | `mkdirSync`, `writeFileSync`, `mkdtempSync`, `rmSync`, `readFileSync` | none: a one-shot test script, no request path | false-positive |
| sync fs in the loader | perf.async.sync-blocking | shared.mjs:31, :42 | the trace read and the hop files checked once at process start | none: runs before the command's own code, once | false-positive |
| a Map | perf.memory.unbounded-cache | rewrite.test.mjs:77, shared.mjs:38 | a one-entry literal; the file map bounded by the trace's hops, built once | none | false-positive |
| JSON in a check | perf.obs.eager-log-serialization | rewrite.test.mjs:28, :68 | `sameJson`, a 40-char slice in a message | none: assertions | false-positive |
| top-level lines | perf.loop-body-candidate | rewrite.test.mjs:136, :156, :160, shared.mjs:88 | not inside a loop | none | false-positive |
| sequential awaits | perf.network.sequential-awaits | rewrite.test.mjs:21-22, :101, :152-153 | three local module loads; calls whose event order the suite asserts | none: no latency to overlap, order is the point | false-positive |

#### Law-scout (stage 6, 2026-09-13)

Coverage: paths handed in 14 | paths readable 14

| rule_id | file:line | Evidence | Proposed fix | Status |
|---|---|---|---|---|
| ban.suppression | README.md:157, CHANGELOG.md:162 | prose naming the ban, history naming the guard | none | false-positive |
| ban.empty-catch | tests/explore-feature-page.test.sh:90, CHANGELOG.md:189 | the needle of an `assert_missing`; history | none | false-positive |
| ban.bare-error | capture/tests/fixtures/sample.ts:20, scripts/tests/fixtures/capture-bun.fixture.sh:19, CHANGELOG.md:190 | fixture sources throwing `RangeError` so the suites prove the rethrow keeps the error; history | none: test fixtures, exempt by Definitions | false-positive |

Design scout: no UI file in scope.

Sweep: 1 debug output 0 (`rewrite.test.mjs` prints its check lines through `console.log`
the way the shell harness prints through `printf`; no `debugger`, no `set -x`); 2
commented-out code 0, `removed:` 0; 3 ownerless markers 0 (the grep's one hit is
`mktemp`'s `XXXXXX` template); 4 dead code: every helper in the three shell files and the
six check functions has a caller (counted, 1 to 35 each); 5 unused variables: shellcheck
clean, every import in the two mjs files read at least once past its import line; 9 stale
references: no "two scripts", "five markers" or "11 suites" left in README, CHANGELOG or
16.9, and the CHANGELOG's "three suites" is what the tree has. Reuse search: the fixture
shape reuses `sample-repo.fixture.sh`'s (`build_sample_repo`, `write_sample_trace` →
`build_capture_bun_repo`, `write_capture_trace`; a second repo was needed because the
sample repo carries no `typescript`, no `bun:test` case and no server); `run` follows the
per-suite helper the other suites keep (`build` in build-page.test.sh); `ENV_TYPESCRIPT`
sits beside `ENV_TRACE`, `ENV_OUT` and `ENV_BUN_TEST` and the suite reads it;
`checkCompilerApi` had no equivalent (`grep -rn "compiler API"` found nothing before it).
Dead code in touched files: 0, no cleanup commit.

Commit: `test(explore-feature): the capture suites, typescript 5 pinned, 2.14.0`, explicit
paths, no attribution; hash in the Stage 7 entry.

## 7. Sprint Review

(empty until Phase 4)

## 8. Retrospective

(empty until Phase 6)

## Spec review (Phase 2.5), done in this session

Execution order: stages 1 to 7 as listed; stage 5 (route text) can be worked beside stage
4. Contended resources: `page.css` was written by T9 and T10, now T9 alone with the classes
named; the live fixture's port, lifted by binding port 0; no shared database (the estimates
service test runs on fakes). Findings, all patched above:

- F1 Important, internal consistency: AC5's second clause had no mechanism; T9 now makes the
  builder re-run `capture-verify.jq` before embedding.
- F2 Important, anchor: "byte-for-byte what 2.13.1 builds" was impossible once the template
  carries the blob and the renderer; reworded to "shows nothing new, every view unchanged".
- F3 Minor, contended file: the runtime classes are named in T9 so T10 and T11 write no CSS.
- F4 Minor, exclusive resource: the live fixture binds port 0 and writes its port to a file.
- F5 and F6 Minor, oversized tasks: T3 and T6 split in two.
- F7 Important, rule 1.1 "≤ 3 parameters. Group into a named interface or DTO if more.":
  every exported capture function takes an options object where it needs more than three.
- F8 Minor, placement: the capture modules are `.mjs`, since the plugin repo has no
  `package.json` and Node would read `.js` as CommonJS.

Not reached: the TypeScript constructs the rewriter must leave alone (decorators,
`satisfies`, labelled statements, `return` inside `finally`); T15's tests reach them.
