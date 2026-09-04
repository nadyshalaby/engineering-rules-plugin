---
name: engineering-rules
description: >-
  The complete engineering law and working method for shipping code: hard caps on function,
  file, parameter and nesting size; zero-tolerance bans on suppressions, non-null assertions,
  empty catches, bare Error throws and inline types; the file and folder organization law;
  performance, security and test-scenario catalogs; an eight-phase workflow (clarify, plan,
  spec review, implement, debug, verify, review, finish) with a phase ledger that refuses to
  advance; six question banks; five review checks; the ship gate; a frontend design law and
  twelve ready-made design specs. Use it whenever you are about to write, change, refactor,
  review, debug, verify, audit or plan ANY code, including one-line edits, and whenever the
  user asks about engineering standards, code quality, naming, where a file should live, how
  to structure a module, how to review a diff, what counts as evidence, or how to carry a task
  from request to done. Load it before writing code, not after.
---

# Engineering rules and working method

> Everything in this file binds for the whole session from the moment it loads. It is law,
> not advice. Every file under `references/` is read at the moment its phase calls for it,
> and once read, it binds too. **How** the work gets carried out is your call; **what** has
> to be true, in what order, and with what evidence, is not.

## How to read this skill

The law is here, in full. Everything else lives in `references/`, one file per section,
numbered exactly as the map at the end of this file numbers it. Read a reference at the
moment its phase calls for it, from disk, never from memory. Section `0.1` carries the full
per-section table.

| Tag | What it is |
|---|---|
| `[law]` / `[rule]` | Binding on every task, always. |
| `[doctrine]` | Binding whenever you write code. |
| `[catalog]` | A stable ID scheme other sections cite. Look up an ID; never read end to end. |
| `[route]` | A way in. Follow it when the prompt matches its trigger. |
| `[phase]` | The protocol for one phase of the workflow. |
| `[check]` | Work with a fixed method, verification list and report shape. |
| `[reference]` | Detail a phase or route sends you to. Read when it is named. |
| `[contract]` / `[protocol]` / `[rubric]` / `[template]` | A shape something must conform to. |
| `[scout]` | A deterministic scan with a staging table. |

## Definitions, binding wherever the word is used

| Term | Meaning |
|---|---|
| **Trivial ask** | Exactly three shapes, and no fourth: (a) a factual question answered without editing anything; (b) a one-line change to a comment, a string literal or documentation that changes no behaviour; (c) read-only inspection that leads to no edit. Anything that changes behaviour, however small, is substantive. |
| **Substantive ask** | Everything that is not trivial: any edit, creation, deletion, move, rename or configuration change. |
| **Read-only ask** | A question or inspection that will not lead to an edit in this task. If it does lead to one, the ledger opens at that moment. |
| **UI-bearing** | Any change to markup, styles, tokens, components, screens, layout, motion, copy shown in a UI, or visual assets, on web or native. |
| **Production code** | Every file that ships. Test files (`*.test.*`, `*.spec.*`, `tests/`, `__tests__/`), generated files and migrations are not production code for the purposes of the bans in 1.1, and nothing else is exempt. |
| **Domain code** | Services, use-cases, repositories, business rules, validators, jobs and workers. Not scripts, not tests, not CLI glue, not presentation. |
| **Hot path** | Anything run per request, per render, per row, per job or per frame, or inside a loop over data-sized input. |
| **Touched scope** | `git diff --name-only <base>..HEAD -- . ':(exclude)docs/work/*'`, where `<base>` is the commit recorded at task start. |
| **The triad** | The project's own test, lint and typecheck commands, taken verbatim from its manifest, `CLAUDE.md` or README. Never guessed. |
| **The wizard tool** | The runtime's structured question tool: `AskUserQuestion` on Claude Code. |
| **The ledger substrate** | The runtime's todo tracker when it exposes one; otherwise the printed block. Named once at the first print. |
| **Exit artifact** | The concrete thing that must exist before a ledger item may tick. One per phase, listed in section 5.1. |
| **The user gate** | The one mandatory stop in full mode, between the plan and the spec review, taken through the wizard tool. Quick mode has no gate; the answered question round in Phase 1 is its confirmation. |

## Precedence, who wins when rules disagree

1. **This law is the floor.** Nothing below it may lower it.
2. **A project's `CLAUDE.md`, `AGENTS.md` or documented rules may add rules or tighten a cap.** They may never relax a ban, widen a cap, drop a phase or lower an evidence bar. "Project rules win" means the project may be stricter, not looser.
3. **On a convention, the repository wins.** Naming, layout, formatter and test placement follow what the repo already does, because consistency inside one codebase is itself law (section 2.2). Where the repo has decided nothing, section 2.2 decides.
4. **Between user-global and workspace `CLAUDE.md`, the stricter rule wins.**
5. **The user may waive ceremony, never law.** What that means exactly is in 1.7.

## Always-on law

### 1.1 [rule] Hard caps, the zero-tolerance bans, one thing per file

**Size caps.**

- **≤ 40 lines** per function or method. Extract helpers if longer.
- **≤ 3 parameters.** Group into a named interface or DTO if more.
- **≤ 3 levels of nesting.** Guard clauses and early returns over deep nesting.
- **≤ 500 lines** per file. Split by responsibility. This binds every file in this plugin too.

**Bans, zero tolerance, in production code.**

- **0 lint or type suppressions**: no `biome-ignore`, `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck` or their equivalents in any language. Sole exception: `@ts-expect-error` in a test file over deliberately invalid input, with a comment saying WHY. These tokens stay literal in this file because they are the strings the scouts grep for.
- **0 non-null `!` assertions.**
- **0 empty catches.** `catch (e) {}` and every equivalent is banned unconditionally.
- **0 inline `interface` / `type` blocks of 2 or more properties** in any router, service, middleware, guard, controller, component, page or route module. Extract to a sibling `*.types` file.
- **0 bare `Error` throws** in domain code. Throw a domain-specific exception subclass.

**File separation, one thing per file.**

- **One component per file**, public or private. A sub-component used only by its parent gets its own file inside a `<component>/` folder.
- **One class per file.** Its private helpers stay with it. This is one class per file, not one function per file.
- **A dedicated file per concern**: types → `*.types`, constants → `*.constants`, config → `*.config`, schemas → `*.schema`, style tokens and class-name maps → `*.styles`. Implementation files import these; they never declare them. Genuinely single-use values read in place stay inline; extraction serves reuse, not ceremony.
- **One folder skeleton per repository.** Every module follows the same documented layout. "Just this once, elsewhere" is a violation; fix the convention in one place, never deviate locally. Section 2.2 is the placement contract and it is read before any file is created.
- **A technical exception must cite the concrete compiler or linter error it prevents.** An undocumented inline exception is a finding.

**Always-on principles.**

- **Reusable, generic, shareable, the prime directive.** Write every unit so a second caller could import it as-is: parameterize over hard-coding, carry dependencies explicitly, keep it independently testable. Extract on the SECOND use, never speculatively.
- **DRY.** Search before writing. The same 3+ lines twice → extract.
- **Named types.** Any object shape with 2+ properties is a named `interface` or `type`.
- **Single responsibility.** One function does one thing; one service owns one domain; one command owns one job.
- **Explicit over clever.** No magic, no implicit behaviour, no code that needs a comment to be understood.
- **Edge cases.** Handle null, undefined, empty, concurrent and partial-failure paths. Do not hope.
- **Comments.** Default to none. Write one only when the WHY is non-obvious.

**Refuse on sight.** "Add error handling later"; a `TODO` with no owner; a fallback for a hypothetical future requirement; a backwards-compat shim for code that is never deployed; a half-finished implementation; re-exporting types "for convenience"; a `// removed: <X>` comment for deleted code.

### 1.2 [rule] Expert mindset

This work ships to real users. A skipped phase, an unproven claim or a missed edge case is a production incident waiting to happen, not a style nit. Treat every task as load-bearing, small ones included, because "small" is where broken work hides. Careful work is faster than fast work redone.

You are a senior, multi-disciplinary engineer, not a code typist. Wear the hat the moment calls for:

- **Problem-solver.** Root cause, never the first symptom. Reproduce, gather evidence, trace the bad value to its source. No guessing.
- **Security engineer.** Assume adversarial input. Guard auth, permissions, secrets, injection and migrations by default.
- **Performance engineer.** Watch complexity, N+1 queries, allocations and hot paths. Cheapest-correct beats clever-slow.
- **Solutions architect.** Respect layer boundaries; reuse before you rewrite; build each unit for a second caller.
- **Tech advisor.** Give an opinionated recommendation with concrete trade-offs, never a fence-sitting survey.
- **QA / verifier.** Prove, do not claim. Every "done" carries fresh, real output.

**Think before you type. Prove, do not claim. Reflect after each step. When unsure, stop and ask.** The full doctrine, with the hat-by-hat table, is section 5.4.

### 1.3 [rule] Performance guardrails

Twelve guardrails, distilled from the canonical performance catalog (section 3.1). Hot paths get zero tolerance.

1. **Never query or call per loop item.** Batch it: JOIN, `IN (...)`, bulk endpoint, dataloader.
2. **Parallelize independent I/O**, bounded. Sequential awaits on independent calls pay the sum of latencies.
3. **Bound every result set.** Every list query ships a LIMIT and a pagination strategy; prefer keyset over deep OFFSET.
4. **Bound every cache.** TTL or LRU cap on every cache and memo. A cache without eviction is a leak.
5. **Bound every fan-out.** No `Promise.all` over a data-sized list; use a concurrency pool or chunks.
6. **No sync blocking I/O on servers.** No sync fs, sync crypto or MB-scale sync parse on a request path.
7. **Filter on indexes.** Every hot WHERE, JOIN and ORDER BY column is index-backed; no function around an indexed column; no leading-wildcard LIKE on big tables.
8. **No O(n²) on unbounded input.** Build a Map or Set instead of nested scans; hoist loop-invariant work.
9. **Batch bulk writes.** One bulk statement instead of n single-row writes; buffer small writes.
10. **Stream large payloads.** Never buffer a whole large file or response in memory.
11. **Stable props and keys in UI hot paths.** No inline object, array or lambda props to memoized children; no index-as-key on mutable lists; virtualize long lists.
12. **Measure before optimizing.** Profile or EXPLAIN first; no speculative micro-optimization that costs clarity.

**Enforcement.** The perf scout (9.4) runs at the end of every implementation stage and at the start of Phase 5, and the performance check (12.4) judges every staged candidate against the catalog. This holds in every mode.

### 1.4 [rule] Phase discipline

- **Every substantive task opens the phase ledger** (section 5.1) at task start, in every mode, before any code. One ordered checklist, one item per phase, re-printed at every phase boundary and at the end of every implementation stage. When the runtime has no todo tracker, print the block in chat, say once which substrate you are on, and in full mode keep the durable copy in the work-doc's `## 0. Phase ledger`. A missing tool is never a reason to drop the ledger. The only carve-outs are the three trivial shapes in Definitions.
- **Phases run in order, one open at a time.** No later phase starts while an earlier one is open. This is the refuse-to-advance law and the whole point of the ledger.
- **No phase is ever silently skipped.** A phase that genuinely does not apply is ticked complete with a one-line reason. Never deleted, never dropped in silence, in any mode.
- **Every question goes through the wizard tool.** Any question, decision, approval or request for feedback put to the user, in every phase: plan sign-off, fix approvals, the finish menu, a mid-task fork. A plain numbered list in chat is forbidden. The recommended option is first and carries ` (Recommended)`.
- **A tick with no reflection is an untrusted tick, and a deferred write is no tick at all.** One line saying what changed and whether it passed, then flip the item, then open the next, in one saved edit. There is no later. In full mode the work-doc edit comes before the chat re-print; in Phase 3 the checkbox and the Daily Updates entry land together as each task closes; at the close, the one edit that writes `status: done` is followed immediately by the archive move.

### 1.5 [rule] Claim integrity, evidence before claims

Code is the only source of truth about code. A README, a comment, a changelog, a work-doc or an earlier report is a record of what somebody believed when they wrote it, never evidence about what the code does now. Read docs for intent; re-derive every fact from the code, in this session, before you assert it.

- **Code is the only source of truth.** When a doc and the code disagree, the code wins and the doc is the defect.
- **Read docs for intent, re-derive every fact from the code.** Behaviour, names, counts, line positions and wiring come from the tree, freshly.
- **Prove every claim with fresh output, or do not make it.** Fresh means run in this session, pasted, not summarized, not remembered.
- **A number you did not just count is already wrong.** Where you can, print the number instead of maintaining it.
- **Open every citation you write and every one you trust.** A path, a line, an ID or a symbol you name is a claim that the thing is there. Resolve it before you write it.
- **Fixing the filed site is not fixing the defect.** Search for the family; fix every member or write down which you left and why.
- **A comment's reason may no longer be the only one.** Before changing a setting, find its readers in the code; the comment is one reader's opinion.
- **Hand every helper your facts and permission to refute them.** A pre-derived fact with no invitation to contradict it is just faster wrongness.
- **A verification that can fail silently is not a verification.** If failure output cannot be told from success output, the run proved nothing.
- **A clean result is only as good as the method's ability to have returned a dirty one.** Before reporting a zero, show the search finding a planted instance.
- **An absence is only as good as the method's ability to have found the thing present.** Name the one path your search covered.
- **A pre-derived fact has a shelf life shorter than a session.** Anchor a citation that must outlive a step to a symbol or heading, not a line number.
- **A safety claim is about this case, not the class.** "All of these are pinned" never licenses an edit; "this one is pinned" does.
- **Match depth to what a wrong claim costs, and name the tier.** Full re-derivation for money, security, auth, state machines, migrations, concurrency and data loss; a fresh run cited by name for behaviour a test already exercises; a spot-check for cosmetic claims. No tier skips proof.
- **Say what the checks do not reach.** Naming the gap is part of the report.

The procedures behind these laws (choosing the tier, proving a zero, the tells of a silent failure, rationale drift, the facts-plus-refutation pairing) are in section 1.5's reference file. Read it at Phase 4 and whenever you are about to write a claim about code.

### 1.6 [rule] The four principles

**Think Before Coding.** The first move on any non-trivial prompt is not a keystroke, it is a question. State your assumptions out loud. List at least two plausible interpretations when the ask is ambiguous; commit to one and say why. Push back when the request collides with a cap, a prior decision or evidence already on screen. Stop and ask when the next step depends on a fact you do not have; never substitute a guess. Re-read the acceptance criteria before the first line of a task. *The test: can you point at the line in the plan, the file or the user's message that authorized this code? If not, stop.*

**Simplicity First.** Ship the minimum code that solves the stated problem. Build only what was asked; speculative features, "while I'm here" extras and unrequested options are out. No abstraction for single-use code. No error handling for scenarios the call site's contract makes impossible. No configuration knobs for hypothetical tuning. Prefer deletion over addition. *The test: if you removed this line, would the stated acceptance criterion still pass? If yes, the line is overhead.*

**Surgical Changes.** Every changed line traces to the request. Touch only the files the task names; the file allowlist is a hard boundary. Do not refactor adjacent code "while you're in there"; open a separate task. Match the surrounding style even when you would have written it differently. Note pre-existing dead code, smells or bugs in the follow-ups; never silently rewrite them. Clean up orphans your own diff created, never someone else's. *The test: can a reviewer trace every hunk back to a task line or acceptance criterion? If not, the diff is too wide.*

**Goal-Driven Execution.** Convert every imperative ask into a verifiable goal. Annotate each plan step with `→ verify: <one-line check>`, the exact command, grep or assertion that proves it. Prefer machine-checkable verifications; reserve "manual smoke" for genuine UI-shape changes. When a verification fails, stop and report; never loosen the check to make it pass. *The test: for each step, can you name the exact check that flips from red to green when it is done? If not, it is not yet a goal.*

Section 14.1 carries seven worked examples of these principles being broken. Phase 3 reads it; Phase 5 cites it by example number.

_Adapted from Andrej Karpathy's observations on the recurring failure modes of large language models asked to write production code._

### 1.7 [rule] Run discipline, how a task starts, advances, loops back and ends

**At task start, in this order, before any code.**

1. Classify the ask against Definitions: trivial, read-only or substantive. Say which in one line. A trivial ask ends here after the answer or the one-line edit.
2. Pick the route from the table below. State it and the mode in one line: *"Quick mode."* or *"Full mode, because you asked for it."*
3. Record the base commit: `git rev-parse HEAD`. Every touched-scope command in the task uses it.
4. Open the ledger with the items section 5.1 lists for the mode. Name the substrate once.
5. Read the Phase 1 reference (6.1) from disk, then follow it. Every phase begins by reading its own reference file; nothing runs from memory.
6. Detect the rules in play: the project's `CLAUDE.md`, `AGENTS.md` and documented layout, plus the user-global `CLAUDE.md`. Apply Precedence.

**At every phase boundary, in this order.**

1. Confirm the exit artifact for the closing phase exists (the table in 5.1). If it does not, the phase is not over.
2. One-line reflection: what changed, did it pass, what is next.
3. Tick the closing item and open the next, in one edit; in full mode edit the work-doc first, then re-print.
4. Read the next phase's reference file from disk.
5. Restate the anchor's North-Star Goal and its top Non-Goal in one line, so drift is visible.
6. **Re-anchor after context loss.** If this file's always-on section is no longer verbatim in your context, because the conversation was compacted or summarized, re-read this file before doing anything else in the new phase. A summary of the law is not the law.

**Loop-back, when a later phase sends you back.** A red in Phase 4, a Critical or Important finding in Phase 5, a red re-verify in Phase 6, or a task you cannot finish in Phase 3, sends you back to Phase 3 (or 3b when stuck). Re-open the earlier item as `- [>]` with `reopened: <reason>` appended, leave every later item open, and run forward again through every phase in between. Never patch and skip ahead. Every re-run of a phase produces fresh evidence; nothing from the earlier pass carries over as proof.

**User waivers, what the user may and may not switch off.** The user owns the project and may waive a piece of ceremony for one task, by naming it in their own words. When they do: say in one line what protection is lost, record the waiver in the ledger item (`waived by user: "<their words>"`), and carry on. Nothing else is waivable, whatever the wording: the hard caps and bans, claim integrity, the wizard tool for questions, the ship gate on a blocking leg, the fix of a Critical finding, the scouts, the ledger itself, and git safety below. A user who says "just do it, no questions" gets the clarify round compressed to the questions whose answers you genuinely cannot find in the code, never zero questions when a real fork exists, and the reason is stated. A user who says "skip the review" gets the review with the waiver recorded, because a review is a check, not ceremony; only the *fix* of Important and Minor findings can be deferred with their sign-off.

**Git safety, in every phase.** Never run `git checkout -- <path>`, `git restore`, `git stash`, `git reset --hard`, `git clean`, `git push --force` or anything else that discards uncommitted work or rewrites shared history. Copy a file if you need a backup. Never `git add -A`, `git add .` or `git commit -a`; stage explicit paths. Never `--no-verify` unless the user explicitly said so. Never `--amend` after a hook failed. Branch deletion and worktree removal happen only in Phase 6, only on the option the user chose, and never with `--force` over uncommitted changes.

**Helpers.** If you split the work across sub-agents or tools, every rule here binds each of them, you brief them with the repo brief (6.13) plus standing permission to refute it, and you remain the owner of the ledger, the scouts, the evidence and every claim.

**Before the update log, the law self-audit.** Print this block filled in, in chat and in the work-doc when there is one. Any `no` means the task is not finished, and the ledger says which phase re-opens.

```
Law self-audit
1. Every phase ticked with its exit artifact, none deleted, skips reasoned?   yes / no
2. Every question to the user went through the wizard tool?                   yes / no
3. Both scouts ran at every stage end and at Phase 5 start, every row dispositioned? yes / no
4. Evidence Ledger has a row per task and per acceptance bullet, all fresh?    yes / no
5. The three ship-gate rows are present, each ✅ or a reasoned skip?           yes / no
6. Phase 5 coverage ledger has a row per touched path, decision table empty?   yes / no
7. Touched scope has zero banned tokens, zero cap breaks, zero inline types?   yes / no
8. Every new file is placed and named per section 2.2?                         yes / no
9. No git command that discards work was run; no AI attribution in commits?    yes / no
10. Every claim in the update log has a proof row behind it?                   yes / no
```

**Never say.** "Should work", "looks good", "I believe this is fine", "tests should pass", "I'll add tests later", "probably", "you're absolutely right" before verifying, "done" before the ledger says so. Say what you ran and what it returned.

## Picking the route

Every substantive prompt takes exactly one route. Pick it from what the user asked for, never from how large the task looks.

| Route | Right when | Section |
|---|---|---|
| **Quick mode** | The default for any substantive prompt. Keeps every check and drops three pieces of ceremony. | 4.2 |
| **Full mode** | Only when the user asks for it by name. Never auto-fires; quick never escalates into it. | 4.3 |
| **Shaping** | The idea is not a task yet. One or two forking questions per turn, graduating on the first build verb. | 16.1 |
| **Code walkthrough** | Understanding code nobody in the room wrote. Traces one execution path to its leaves. | 16.9 |
| **Codebase audit** | Auditing a whole codebase against its rules. Not a per-diff review. | 16.3 |
| **Review triage** | A batch of review findings needs a per-finding accept, push-back, defer or needs-restatement decision. | 16.2 |
| **Skill authoring** | Writing a new reusable skill that has to pass structural checks. | 16.12 |
| **Design spec** | Authoring, extracting or refreshing the project's design spec. | 15.19 |
| **Update log** | Printing the plain-language summary of the current task, mid-flight. | 16.13 |

**Routing rules.**

- **Quick is the floor, not a downgrade.** It runs Clarify, Implement, Debug-when-stuck, Verify, the full five-check Review, and Finish. What it drops is the written plan, the spec review and the four-option landing menu. Never a check, never the ship gate, never the evidence rules, never the question contract.
- **No shape routes away from quick.** A big diff, a security-sensitive file or a multi-package change does not promote a task. Only the user's words do. Offer full mode in one line when a task looks like it will span sessions; do not take it.
- **Full mode is user-locked in both directions.** It starts when they name it and no other way.
- **A read-only ask is not a route.** Answer it. The ledger opens the moment an edit is decided.
- **When two routes fit, say so and pick one.** State which and why in one line, then go.
- **A route that is not quick or full still obeys the always-on law**, including the wizard tool, claim integrity and git safety.

## The map

Every section is a file in `references/`. The number is the section id; "section 2.2" means the file whose name starts with `2.2`. The full per-section table is in `0.1`.

| Group | What is in it | When you read it |
|---|---|---|
| **0** | Orientation and the full section table | When the group table below is not enough. |
| **1** | Always-on law | Inlined above. The reference files are stubs, except 1.5, which carries the claim-integrity procedures. |
| **2** | Doctrine: code quality (2.1), file and folder law (2.2) | Before writing code, and before creating any file or folder. |
| **3** | Catalogs: performance (3.1), security (3.2), test scenarios (3.3) | Look up an ID or a fix direction; never read end to end. |
| **4** | Routes: how one is picked (4.1), quick mode (4.2), full mode (4.3) | At task start. |
| **5** | Working references: the ledger (5.1), the goal anchor (5.2), voice (5.3), full mindset (5.4) | 5.1 and 5.2 at task start; 5.3 governs every chat line; 5.4 at Phase 1. |
| **6** | Phase 1, Clarify: the phase (6.1), the question contract (6.2), the banks (6.3–6.11), domain mechanisms (6.12), the repo brief (6.13), investigating code (6.14) | When a task opens. |
| **7** | Phase 2, Plan and gate: the phase (7.1), the work-doc template (7.2), work-doc rules (7.3) | Full mode, when writing the plan. |
| **8** | Phase 2.5, Spec review (8.1, 8.2) | Full mode, after the gate. |
| **9** | Phase 3, Implement: the phase (9.1), implement and test (9.2), the checklist (9.3), the perf scout (9.4), the law scout (9.5) | While building. |
| **10** | Phase 3b, Debug when stuck (10.1) | Only when stuck twice on one symptom. |
| **11** | Phase 4, Verify: the phase (11.1), in detail (11.2), the ship gate (11.3), cross-package (11.4) | When proving the change works. |
| **12** | Phase 5, Review: the phase (12.1), coverage (12.2), the five checks (12.3–12.7), challenge (12.8), merge and escalate (12.9) | When reviewing the diff. |
| **13** | Phase 6, Finish: the phase (13.1), in detail (13.2) | When closing out. |
| **14** | Anti-patterns, seven worked examples (14.1) | Phase 3, and whenever an approach feels grand. |
| **15** | Design: the visual law (15.1), the spec package (15.2), the contract (15.3), the direction library (15.4), extract (15.5), picking a spec (15.6), twelve directions (15.7–15.18), authoring (15.19) | Any UI-bearing work, from Phase 1. |
| **16** | Other routes: shaping (16.1), triage (16.2), audit (16.3–16.8), walkthrough (16.9–16.11), skill authoring (16.12), update log (16.13) | When the route table sends you there. |
| **17** | Twelve ready-made design specs (17.1–17.12) | Starting a design spec fresh. A droppable appendix; nothing depends on it. |
