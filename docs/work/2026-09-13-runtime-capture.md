---
slug: 2026-09-13-runtime-capture
title: Runtime capture for explore-feature, real values at every anchor
status: implementing
type: feature
created: 2026-09-13
project: engineering-rules-plugin
related: []
base: 5c2c495
current_task: T4
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
- [ ] T4. `capture/preload.bun.ts`: the Bun plugin with an exact-path filter and the loader by
      extension — files: `skills/explore-feature/capture/preload.bun.ts`
      → verify: `bun --preload` over the spike prints enter and exit records
- [ ] T5. `capture/register.node.mjs` + `capture/hooks.node.mjs`: sink in the main thread,
      rewrite after `nextLoad` — files: the two named
      → verify: `node --import` over the spike prints the same records
- [ ] T6a. `scripts/capture-run.sh`, test mode: usage, runtime detection, flag injection, env,
      run, then aggregate, verify, secret scan, `capture.json` — files:
      `skills/explore-feature/scripts/capture-run.sh`
      → verify: usage on no args; the fixture run writes capture.json and prints one line
- [ ] T6b. `scripts/capture-run.sh`, live mode: `--live` backgrounds the command with its pid
      and output under the folder, `--stop` signals it, waits for the flush and runs the same
      aggregate, verify and scan — files: the same
      → verify: the fixture app answers a curl while instrumented, `--stop` yields capture.json
- [ ] T7. `scripts/capture-aggregate.jq` (events to calls and branches per anchor) and
      `scripts/capture-verify.jq` (anchors resolve to trace hops and ranges) — files: the two
      → verify: `jq -f` over a hand-written JSONL yields two calls and one branch
- [ ] T8. 16.10: the `capture.json` contract, `branches[].line`, and where the file lives —
      files: `references/16-other-routes/16.10-the-trace-data-schema.md`
      → verify: the section names every field the aggregate emits, cross-checked by grep
- [ ] T9. `page.js` seams (`registerPaneExtra`, `registerLineMark`, `capture` lookup),
      `page.html` `<!--CAPTURE-->` blob, `build-page.sh` optional fourth argument that re-runs
      `capture-verify.jq` against the trace and refuses on any line, and every class the
      renderer will use in `page.css` (`.runtime`, `.rt-call`, `.rt-in`, `.rt-out`, `.rt-threw`,
      `.rt-ms`, `.linechip`, `.linechip.is-true`, `.linechip.is-false`, `.rt-table`) — files:
      those four
      → verify: a build without a capture renders every 2.13.1 view unchanged and an empty blob
- [ ] T10. `page-capture.js`: the Runtime tab, the per-excerpt block, the line chips — files:
      `skills/explore-feature/assets/page-capture.js`
      → verify: a fixture capture renders N Runtime blocks and the chips in the browser
- [ ] T11. `page-flow.js`: ms labels on arrows of hops with calls — files: that one
      → verify: the diagram shows `12 ms` on an arrow in the browser
- [ ] T12. 16.9: step 6b (both modes, the commands, the stop), the `Captured:` handoff line,
      two anti-rationalisations — files: `references/16-other-routes/16.9-exploring-one-feature.md`
      → verify: the step names the runner, both flags and the handoff line
- [ ] T13. 16.11: captured values are observations of one run, masked, never the contract —
      files: `references/16-other-routes/16.11-the-trace-rubric.md`
      → verify: the gate gains one row about the capture
- [ ] T14. Sub-skill, README, CHANGELOG, manifests at 2.14.0 — files: `skills/explore-feature/SKILL.md`,
      `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
      → verify: `grep -c 2.14.0` on each; `claude plugin validate --strict .`
- [ ] T15. Tests for the rewriter — files: `skills/explore-feature/capture/tests/rewrite.test.sh`,
      `rewrite.test.mjs`, a fixture file
      → verify: watched failure on a planted un-instrumented function, then green
- [ ] T16. Tests for the runner: Bun fixture in test and live mode, Node fixture in test mode,
      masking, throw, branch, repo untouched — files: `scripts/tests/capture-run.test.sh`,
      `scripts/tests/fixtures/capture-bun.fixture.sh`, `capture-node.fixture.sh`; the live
      fixture app binds port 0 and writes the port it got to a file, never a fixed port
      → verify: green, and a planted raw email in the JSONL is refused by the scan
- [ ] T17. Builder and template tests — files: `scripts/tests/build-page.test.sh`,
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
