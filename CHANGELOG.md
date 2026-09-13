# engineering-rules, the history

One entry per version, newest first. The README says what the plugin is now; this file says how it got there.

- **2.13.0**: the walkthrough route becomes `explore-feature`, and its output becomes a
  verified page. `/engineering-rules:explore-feature <entry point>` walks one entry to its
  leaves and writes `trace.json` to the v2 contract in `16.10`;
  `skills/explore-feature/scripts/verify-trace.sh` refuses any citation the working tree
  disagrees with (eleven checks, the structural ones in `verify-trace.jq`) before writing
  `excerpts.json` with every line copied by `sed`; `build-page.sh` refuses an excerpt carrying a
  hardcoded secret (the `9.5` patterns, the value never printed) and inlines the template under
  `assets/` into one self-contained page (the call stack, diff-style excerpts with hop
  badges, a clickable sequence diagram, steps, branches, the failure path, shapes, decisions
  and a quiz, all keyed to one selected hop, syntax-highlighted, in GitHub's light and dark palettes with a theme switch) that is published through the
  artifact tool and never written into the explored repository. `16.9` is the route, `16.11`
  the code-only rubric with its gate: the explored repo's docs are a map, never a source.
  Playbook mode, note merging and the `.walkthrough/` viewer are gone. Two script tests on a
  sample-repo fixture, a page-template guard, the caps test over the skills' scripts and
  the cross-references in `4.1`, `4.4`, `5.1`, `6.2`, `13.1`, `13.2`, `0.1`, the README, the
  manifests and the full-mode eval grader follow.
  The defaults flip: full mode and agentless are the defaults for every substantive prompt;
  quick mode and helpers are what the user names, by `/engineering-rules:quick`,
  `/engineering-rules:helpers` (the renamed agentless switch: bare switches helpers on, `off`
  back to agentless) or their own words. `4.2` and `4.3` swap their subtitles, the eval
  `agentless-quick` becomes `agentless-default`, and `1.7`, `1.8`, `4.1`, `4.4`, `5.1` and
  `16.1` say the same thing.
- **2.12.1**: the gaps a sweep of 2.12.0 found. The bold "never in this session" lines of
  `8.1` and `12.1` name agentless mode as their one exception and `12.1`'s intro reads the
  check files here under it too; `16.1`'s build-verb veto does not apply to a prompt typed
  after `/engineering-rules:shape`; `1.8` says the user's word holds for the conversation;
  the README's helper-shapes section says none is sent in agentless mode; and the
  route-picker grader is named for the intake it checks.
- **2.12.0**: agentless is a sub-command, not a token. `/engineering-rules:agentless` switches
  the mode on for the task in flight and every task that starts in the conversation, until
  `/engineering-rules:agentless off`; with a request after it, the request classifies as
  prose and starts agentless. The nine route sub-commands take no mode token any more (no
  `arguments` list, no `$mode` line), the intake skips its helper question when the switch
  is already on, and `4.4`, `4.1`, `SKILL.md`, the test and the `agentless-quick` eval say so.
- **2.11.0**: the route parameter becomes nine sub-commands, the bare invocation becomes an
  intake, and agentless mode arrives. `skills/quick`, `full`, `shape`, `walkthrough`,
  `audit`, `triage`, `skill`, `design` and `log` each hold a short skill only the user can
  invoke (`disable-model-invocation: true`), which loads the law, picks its row outright and
  hands over the request; `SKILL.md` drops `arguments: [route]` and the `$route` line, and
  `/engineering-rules:engineering-rules <request>` classifies the request as prose. Typed
  bare, the skill walks the user through the options through the wizard tool (what they are
  here for, which route, helpers or agentless, the request) and starts only when all three
  are settled; the old picker asked for nine options in one question, which the wizard tool
  cannot hold. Agentless mode, by an `agentless` first word, the user's own words or the
  intake, keeps every helper shape in the session: a third helper line in `1.8` and `5.1`,
  every mandatory send done here in the same order, the one-line cost at task start, all
  written up in a new `4.4`, with `4.1`, `4.2`, `4.3`, `5.5`, `6.1`, `8.1`, `9.1`, `12.1` and
  the seven route sections pointing at it. `tests/sub-commands.test.sh` keeps the route
  table and the skill directories in step; two eval cases, `sub-command-full` and
  `agentless-quick`, state the promise.
- **2.10.0**: every built-in agent type is employed, and the builder reads what binds it.
  The spec review of Phase 2.5 moves out of the context that wrote the plan into a fresh
  `Plan` agent, read-only by construction, with its own prompt block in `5.5`; `8.1` sends
  it, `8.2` returns the execution order for the session to write, and it is a mandatory
  send in `1.8`. The builder prompt no longer says `2.2` and `9.2` "bind you" and leaves
  it there: the Skill tool loads `SKILL.md` alone, so the builder now reads `2.2` before
  creating or moving a file, `9.2` before writing a test and `14.1` when an approach feels
  grand, at paths the brief carries, and a file placed or a test written without them is a
  finding.
- **2.9.0**: the clarify round is hardened into a senior product owner's. A new `6.15`,
  the end-to-end coverage map: sixteen aspects (value, actors, entry points, inputs, the
  happy path, states, data, failure paths, integrations, security, volume, observability,
  rollout, surfaces, tests, operations) walked per deliverable, each `pinned:<source>`,
  `asked:Q<n>` or `n/a:<reason>`, printed with the restatement, and Phase 1 does not close
  on a hole. `6.4` gains Q0, the intent restatement (outcome, for whom, why now, done,
  excluded, the interpretations weighed) confirmed by the user before any domain question,
  plus an `Assuming:` list with a source per line. Every question carries `traces-to` (a
  deliverable or requirement, or it is cut) and `cost-of-guessing` (the costliest fork is
  asked first). The anchor's goal gains a value line and In-Scope is written as
  deliverables (`5.2`). A `Suggestions:` block brings the options the user did not ask for,
  each with its evidence tier (`6.2`). Always-on: a **Product owner** hat (`1.2`, `5.4`) and
  **Memory is a hypothesis** (`1.5`): nothing about a library, API, tool, version or
  platform is a fact until verified this session in the lockfile, the installed source, its
  help or docs fetched now; the repo brief gets an Externals row (`6.13`), the investigation
  method a go-and-read step (`6.14`), and the self-audit a fourteenth line.
- **2.8.0**: the law leaves nothing behind. `1.1` gains a "leave nothing behind" principle
  and "DRY, with the search shown": every new symbol carries the pasted search that found no
  existing equivalent. The leftover sweep moves from the finish to every stage end (`9.1`,
  `9.3`), and dead code runs both directions: what the diff added with no caller, and what it
  orphaned by removing the last caller, import or reference. Dead code that was already in a
  touched file is removed by default in its own `chore(<scope>): remove dead code in touched
  files` commit, with a zero-reference proof per symbol, the looks-dead-but-may-not-be
  guardrails in `13.2` class 10, one `git revert` as the veto, and the commit named in the
  update log (`16.13`); `1.6`, `2.1` and `3.4` carry the exception. `12.7` names leftovers and
  the reuse search explicitly, `9.5` hands it a leftovers lens, the builder prompt in `5.5`
  searches before it adds and sweeps before it returns, and the self-audit asks.
- **2.7.1**: every helper runs on the session's model. The mechanic's `haiku` pin is gone,
  and with it "the cheapest model" and "no weaker than" from `1.8`, `5.5` and the README: no
  send names a `model`, a fork runs on the session's model by construction and a fresh type
  inherits it, so the reviewer, the mechanic, a builder and a reader are all the model the
  user is talking to. A runtime default that would hand helpers a different model is
  overridden by naming the session's model on the send.
- **2.7.0**: the shipped agents are gone. `agents/` (`law-reviewer`, `law-mechanic`,
  `law-builder`) is removed, and the four helper shapes run on the agent types Claude Code
  ships itself: `fork` for a reader that needs the conversation, `Explore` for a wide
  read-only search, `general-purpose` for the reviewer, the mechanic (on `haiku`) and a
  builder. `5.5` now carries each shape's prompt, the former agent bodies plus a reader
  block, pasted whole on every fresh send, so a built-in type is bound exactly as the shipped
  agent was; the session checks `git status --porcelain` after a reviewer or a mechanic
  returns. The agent-tool definition, `12.1` and the manifests name the built-in types; the
  notifier's fixture test logs a `general-purpose` helper.
- **2.6.0**: the git guard is gone. The `PreToolUse` hook on `Bash` that refused the git
  commands `1.7` bans and prompted on the waivable ones is removed with its fixture test, and
  `1.7` no longer says a hook stands behind it; the git safety law itself is unchanged and
  still binds every session through the skill. `tests/hooks-wiring.test.sh` now fails when a
  hook reaches the `Bash` tool. The `git-safety` eval stays, since its graders accept an
  explicit refusal with no hook behind it.
- **2.5.1**: the law scout's path helper in `9.5` matches a glob without a slash against the
  file name alone, and the one slash glob that named a file shape (`*/test_*`) is gone, so a
  directory named like a test file (`pkg.test.util/`, `src/test_utils/`) no longer makes
  every file under it a test file, which had applied the test-only rows to real code and
  invited the test-file waivers on it; the same helper serves the domain, scoped and
  non-null rows, which now read a file name where they always meant one.
  `tests/law-scout.test.sh` plants both look-alike directories, and the edit guard's test
  pins its test globs to the scout's. Re-run any scout table built over a tree with such a
  directory.
- **2.5.0**: the law meets Claude Code's runtime. Four new hooks: a git guard on every
  `Bash` call that refuses the commands `1.7` bans and prompts on the waivable ones; an edit
  guard on the four edit tools that runs `9.5`'s block over the edit and refuses an added
  banned token under nine rule ids, with the law's own exemptions; a file cap that reports a
  file over 500 lines as it is written; a re-anchor that puts the re-read instruction and the
  last ledger position into a compacted or resumed session. The notifier gains `StopFailure`,
  `SubagentStart` and `SubagentStop`. Three agents ship (`law-reviewer`, `law-mechanic`,
  `law-builder`) and `5.5`, `12.1` and the agent-tool definition name them; `7.1` and `13.2`
  name the worktree tools; `9.5` says which rows are enforced at write time and learns shell's
  `shellcheck disable`; `1.1` and `1.7` say that a guard's refusal is the law speaking and
  never an obstacle to route around. Three eval cases under `evals/`. Tests: one fixture test
  per hook script, `tests/hooks-wiring.test.sh`, `tests/hook-caps.test.sh`, and every test
  now shares `tests/harness.sh`.
- **2.4.0**: group 15 grows from nineteen to thirty-one sections, folding in the design read
  and the three dials (`15.20`), the design-system map (`15.21`), the page composition law
  (`15.22`), the copy and imagery law (`15.23`), the AI-tell catalog with stable
  `tell.<area>.<slug>` ids (`15.24`), motion discipline and recipes (`15.25`), implementation
  guardrails (`15.26`), the pattern vocabulary (`15.27`), the redesign protocol (`15.28`), a
  third scout keyed to the tell ids (`15.29`), the design pre-flight (`15.30`) and image-first
  and brand work (`15.31`). `15.1` carries the expanded bans and musts, the twelve profiles
  carry a default dial triple and three new anti-tells, `15.3` gains optional `dials` and
  `system` blocks and a thirteenth validation item, `12.5` re-judges the scout's rows and
  re-runs the pre-flight, and `SKILL.md`, `0.1`, `2.2`, `4.2`, `4.3`, `5.1`, `5.4`, `5.5`,
  `6.1`, `6.6`, `6.9`, `6.13`, `7.1`, `7.2`, `9.1`, `9.3`, `12.1`, `13.2` and `16.13` are
  aligned to it: three scouts where they said two, the read and the dials in the clarify
  step and the work-doc, the block library in the folder law, placeholder image slots in
  the cleanup sweep and the update log. `tests/design-scout.test.sh` is new and
  `tests/catalog-ids.test.sh` checks the `tell` family.
- **2.2.0**: the clean-code catalog (`3.4`) is new, 99 judged rows with stable
  `style.<domain>.<slug>` ids across naming, functions, comments, structure, objects, error
  handling, boundaries, classes, async and test hygiene, plus the community rules this law
  deliberately does not adopt; `2.1` is extended to match and `SKILL.md` 1.1 carries its
  ten-line floor. The always-on bans grew by focused or unticketed skipped tests, debug
  artifacts and coverage-ignore markers, and the test-file exception was narrowed to the one
  1.1 names. The law scout (`9.5`) now catches the suppression siblings (`oxlint`, `deno`,
  `tslint`, `stylelint`, Flow, Sonar, JetBrains), comment-only and multi-line empty catches
  and the promise `.catch(() => {})`, `throw` without `new`, thrown literals and
  `reject(new Error(`, the cross-language analogs, owner-aware debt markers, and redacts every
  secret it finds; inline types are scanned in the five scoped roles only, `console.*` in the
  domain roles only, focused tests in test files only, where a test file is now named by
  every language's convention (`_test.go`, `_spec.rb`, `test_*.py`, a `src/test/` tree), and
  the non-null `!` only where the language has the operator; every line the scout prints
  starts with its rule id. `16.4`, `16.5`, `16.6`, `16.7`,
  `16.3`, `16.2`, `13.1`, `13.2`, `12.7`, `11.2` and `9.3` follow, and
  `tests/catalog-ids.test.sh` is new.
- **2.1.1**: the law scout's shell block in `9.5` carried raw control bytes where `\n`, `\0`
  and `\b` were typed, so in 2.0.1 and 2.1.0 every construct-ban row came back empty and the
  readable count read zero without scanning; re-run any table built from it. The path list is
  now NUL-separated at the source (`git diff -z`), a list built without `-z` is refused, the
  readable count no longer runs a shell per path, `9.4` takes the same list, the three
  word-boundary patterns are POSIX ERE, and `tests/no-control-bytes.test.sh` and
  `tests/law-scout.test.sh` guard the plugin's files and the block itself.
- **2.1.0**: the file and folder law (`2.2`) now puts every file of a feature in a role
  folder (`services/`, `types/`, `tests/` and the rest) and refuses the flat feature
  folder; `2.1`, the always-on law in `SKILL.md` and the review-triage example in `16.2`
  were aligned to it. `5.5` (delegation) is new: what stays in this session and what goes
  to a helper, with the always-on Helpers rule, `0.1`, `6.1`, `9.1` and `12.1` pointing
  at it. Hooks ship with the plugin (`hooks/`): a progress log and a desktop notification
  on every turn end and whenever Claude is waiting, a status line with the ledger position,
  and the notify-at-every-tick rule in `1.4` and `5.1`.
- **2.0.1**: the skill description trimmed under the 1024-character cap the Agent Skills
  spec sets for a `description`; install notes rewritten around the copy-on-install
  behaviour.
- **2.0.0**: the hardening pass described at the top. Sections were rewritten where they
  contradicted each other or pointed at machinery that is not part of this plugin, and `1.7`
  (run discipline) was added. The section numbering is unchanged; `1.7` is the only new
  number.
- **1.0.0**: a mechanical split of the original `CLAUDE.md`, one section per file, text
  unchanged.
