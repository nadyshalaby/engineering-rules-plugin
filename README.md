# engineering-rules

The engineering law and working method, packaged as one Claude Code plugin: a skill that
carries the law, hooks that enforce the parts of it a hook can see, three agents that carry
the helper shapes the law sends work to, and eval cases that state what the plugin promises.

It began as a single 1 MB `CLAUDE.md`, split one section per file behind progressive
disclosure. Version 2.0.0 was a hardening pass over that split: one canonical copy of the
always-on law, inlined in `SKILL.md`; the seams the split left behind closed; a run discipline
so the law is applied the same way in every session, with a phase ledger that refuses to
advance without its exit artifact, loop-back rules, a fixed list of what a user may waive and
what nobody may, git safety, and a law self-audit before any task is called done. Version
2.5.0 moves the enforceable part of that law from the prompt into the runtime: a git command
the law bans is refused before it runs, an edit that adds a banned token is refused before it
lands, a file that crosses the line cap is reported the moment it is written, and a session
that lost its context is re-anchored on the law and the ledger before its next step.

## What loads when

| Level | What | Cost |
|---|---|---|
| 1 | `name` + `description` | Always in context, about 100 words |
| 2 | `SKILL.md`: definitions, precedence, the always-on law (`1.1` to `1.8`), the route table, the group map | Loads when the skill triggers, about 380 lines |
| 3 | `references/**`: all 120 sections, one file each | Only when a phase names one |
| hooks | `hooks/hooks.json`: eight events, four guard and anchor scripts plus the notifier | Live from install, no prompt cost; up to half a second per edit of a code file |

The eight always-on sections live in `SKILL.md` because they bind from the moment the skill
loads, and a reference you have to go fetch is a reference you might not fetch. The files
under `references/01-always-on-law/` are short stubs that point back to `SKILL.md`, except
`1.5`, which carries the claim-integrity procedures the laws call for (proving a zero, the
tells of silent failure, the depth tiers). If a stub and `SKILL.md` ever differ, `SKILL.md`
wins.

## How a task runs

Every substantive ask goes through the same phases:
1 Clarify, 2 Plan and gate, 2.5 Spec review, 3 Implement (3b Debug when stuck), 4 Verify,
5 Review, 6 Finish. Quick mode, the default, drops the written plan, the spec review and the
landing menu, and nothing else: every check, every scout, all three verify layers, the five
review checks and the ship gate still run. Full mode runs when the user names it. The other
routes (shaping, walking one execution path, auditing a whole codebase, review triage,
authoring a skill, authoring a design spec, printing the update log) are picked by the rules
in `4.1`.

The phase ledger (`5.1`) is the order-enforcer. Every phase is an item with an exit artifact,
a phase is ticked only when that artifact exists, and the ledger is re-printed at every
boundary, so a session that lost its context can pick the work up from the ledger alone.
Every question to the user goes through the `AskUserQuestion` tool. Every claim of "done",
"passes" or "clean" has a proof row behind it. Work the law sends out of the session (a
reader, the stage-end scouts, the fresh reviewer, a mechanic, a builder; `5.5`) goes through
the `Agent` tool, and the reviewer, mechanic and builder shapes ship as agents under
`agents/`.

## The law at the tool boundary

Installing the plugin installs `hooks/hooks.json`; nothing to configure. Every hook is a
plain shell script that reads the event on stdin, needs `bash`, `jq`, `git` and the usual `awk`, `sed` and coreutils, and exits 0
whatever happens: a hook that cannot read its input has no opinion, and a missing tool never
fails a turn. Nothing here calls a model.

| Event | Script | What it does |
|---|---|---|
| `PreToolUse` on `Bash` | `git-guard.sh` | Refuses the git commands the law bans (`1.7`) and turns the waivable ones into a permission prompt. |
| `PreToolUse` on `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | `edit-guard.sh` | Runs the law scout's own block (`9.5`) over the edit and refuses it when it adds a banned token. |
| `PostToolUse` on the same four | `file-cap.sh` | Tells Claude when the file it just wrote is over 500 lines (`1.1`). |
| `SessionStart` on `compact` or `resume` | `re-anchor.sh` | Puts the re-read instruction (`1.7`, step 7) and the last ledger position into the new context. |
| `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `Notification` | `progress-notify.sh` | One log line per event, a desktop notification on a boundary, a wait or an error. |

**What the git guard refuses.** `reset --hard`; `checkout --` and `checkout .`; `restore`;
`stash` (except `list` and `show`); `clean` (except a dry run); `push --force`, `-f`,
`--force-with-lease`, `--force-if-includes` and a `+refspec`; `add -A`, `--all`, `add .`, `./`,
`:/` and a bare `*`; `commit -a` and its clusters such as `-am`. It sees the command behind
`&&`, `;`, `|`, a subshell, a second line, a `\` line continuation, a glued redirect such as
`git stash>/dev/null`, an absolute path to `git`, `git -C dir` and `git -c key=value`, and
inside a quoted string that something runs, so `sh -c "git reset --hard"` and `eval "git
stash"` are refused too. A banned command that only appears as text inside a quoted string (a
commit message, a grep pattern, an `echo`) is asked about instead, so a false refusal never
blocks and a real run never passes as text. Heredoc bodies are not commands and are left alone.
A refusal quotes the law (`1.7`) and is logged; a secret in the command is redacted before
either.

**What the git guard asks about.** `--no-verify` (and `commit -n`) on `commit`, `push` and
`merge`; `--amend`; `branch -d`, `-D` and `--delete`; `worktree remove`; `push --delete`, `-d`
and `:ref`; and a banned command spelled only inside a quoted string. Each becomes a permission
prompt, so the user says yes or no every time, which is what `1.7` requires. Under bypass
permissions there is nobody to answer: in a headless boot the asked command did not run, the
log line marks the mode, and every refusal still holds there.

**What the edit guard refuses.** An edit to a code file that adds a hit under one of nine rule
ids the scout can judge without a lexer: `ban.suppression`, `ban.empty-catch`, `ban.bare-error`
(domain files only: services, use-cases, repositories, validators, jobs, workers),
`test.focused`, `test.skipped`, `clean.debug-artifact`, `clean.debt-marker`,
`clean.removed-comment` and `sec.hardcoded-secret` (not in a git-ignored file such as `.env`).
It runs `9.5`'s block over the new text and, on a hit, over the old text, and refuses only when
a rule's count grew: keeping an existing token, moving it, or writing over a file that already
holds one is allowed, because the law bans adding, and the stage-end scout owns what is already
there. Test files keep the four rows that bind them too (`ban.suppression` minus the
`@ts-expect-error` exception, `test.focused`, `test.skipped`, and `sec.hardcoded-secret`
outside a git-ignored file); prose, docs, generated files, lockfiles, migrations and build
output are not judged. The guard carries no token list of its own: `9.5` is the single source,
so a token added there is enforced here. The refusal names the rule, the line of the new text
and the law (`1.1`), and is logged. When `9.5` cannot be found, or its block fails to run, the
guard allows and logs `skipped` with the reason. A test that must plant a banned token as
fixture text writes it in two pieces (`printf '%s disable=SC2086' '# shellcheck'`), the way
this repo's own scout test does: the guard cannot tell a fixture from a directive, and the law
keeps the suppression ban in test files.

**What it costs and what it cannot see.** A quarter to half a second per edit of a code file,
the time of one run of the block. A file written from a `Bash` heredoc is not an edit-tool call
and is not judged; `1.1` forbids routing around the guard that way, and the stage-end scout
catches it. A notebook cell is judged on its new source only. The non-null `!` and the
inline-type rows need a lexer and stay with the scout.

**The log.** Every hook writes to `~/.claude/progress.log` (or `$CLAUDE_CONFIG_DIR`), one
line per event, `time | project | text`, append-only and never trimmed:

```
guard | git | deny | reset --hard | git reset --hard HEAD~1
guard | git | ask | no-verify | git commit --no-verify -m fix (bypass mode)
guard | git | ask | stash (quoted) | git commit -m "note: never git stash"
guard | edit | deny | ban.suppression | src/a.ts | line 3 of the new text
cap | file-lines | src/big.ts | 512 lines
anchor | compact | (3 of 6, Phase 4)
stop | (3 of 6, Phase 4) | first line of the reply
waiting | permission_prompt | what it is waiting for
error | rate_limit | the message
helper | start | engineering-rules:law-reviewer | the brief
helper | stop | engineering-rules:law-reviewer | first line of the return
```

## Progress while you are away

- **`Stop`**, every time Claude finishes a turn: one log line, and when that turn ends on a
  ledger re-print a desktop notification says so. Back from a break, run
  `tail ~/.claude/progress.log`.
- **`StopFailure`**, when a turn ends on an API error: an `error` line and a desktop
  notification with the error type.
- **`SubagentStart` and `SubagentStop`**: a `helper` line each, with the agent type and the
  brief or the first line of what came back, so the mandatory sends (`1.8`) leave a trail.
- **`Notification`**, whenever Claude is blocked on you (a permission prompt, a question, an
  idle wait): a desktop notification saying what it is waiting for, and a `waiting` line.
- **Your phone.** The ledger rule (`1.4`, `5.1`) sends every tick through Claude Code's
  `PushNotification` tool, which Remote Control delivers to the mobile app. Add
  `"inputNeededNotifEnabled": true` to `~/.claude/settings.json` to also be pushed when a
  permission prompt or a question is waiting.
- **Status line.** A plugin cannot set `statusLine`, so it is one line in
  `~/.claude/settings.json`, and it follows plugin updates on its own:

  ```json
  "statusLine": { "type": "command", "command": "f=$(ls -t \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/engineering-rules-marketplace/engineering-rules/*/hooks/statusline.sh 2>/dev/null | head -n 1); [ -n \"$f\" ] && exec bash \"$f\"; echo 'engineering-rules status line: plugin not installed'" }
  ```

  It shows the directory, git branch and dirty state, model, a context bar, session uptime,
  and the last ledger position Claude printed, e.g. `(3 of 6, Phase 4)`.

Desktop notifications use `osascript` on macOS and `notify-send` on Linux. On macOS a turn
that ends on a ledger re-print is announced twice, once by Claude's notification tool (the
rule in `1.4`) and once by the Stop hook; the hook is the one that cannot be forgotten under
load, so silence the tool's desktop alerts in Claude Code's settings if you want one alert,
or comment out the `notify_desktop` call in `on_stop` for the other.

## The agents

Three agents ship under `agents/`, one per helper shape the delegation rule (`5.5`) sends
work to. The skill names them on the send and falls back to a fresh general-purpose agent
with the same brief when the plugin is not installed.

| Agent | Shape | Model | What it may do |
|---|---|---|---|
| `engineering-rules:law-reviewer` | the fresh reviewer of Phase 5 | inherits | Reads the five review checks (`12.3` to `12.7`) from the plugin, runs them over the diff, returns findings in the review's shape. Never edits, never asks, never spawns. |
| `engineering-rules:law-mechanic` | the mechanic | `haiku` | Runs the command it was given and returns the raw output, nothing summarized. |
| `engineering-rules:law-builder` | a builder | inherits | Loads the skill, builds one stage inside the file allowlist it was handed, never commits, never spawns. Isolation is chosen on the send, not in the agent. |

Every hook fires inside an agent too, so a builder is under the same guards as the session.

## The evals

`evals/` holds three cases in the plugin-eval shape (`prompt.md` plus graders): `git-safety`
(a prompt that invites a destructive git command; the run must refuse and name the law),
`ledger-opens` (a small code task; the skill must fire, the ledger must be printed, every
question must go through the wizard tool, no banned token may land) and `route-picker` (the
bare slash invocation; the route table must be offered through the wizard tool). The runner,
`claude plugin eval`, is in early access at the time of writing; until it runs here, the cases
are the written statement of what the plugin promises, and the headless boots below are the
proof.

## Layout

```
engineering-rules-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   ├── law-reviewer.md                  the fresh reviewer of Phase 5
│   ├── law-mechanic.md                  runs a command, returns raw output
│   └── law-builder.md                   builds one stage inside an allowlist
├── evals/
│   ├── git-safety/                      prompt.md + graders/
│   ├── ledger-opens/
│   └── route-picker/
├── hooks/
│   ├── hooks.json                       eight events, live the moment the plugin is installed
│   ├── git-guard.sh                     PreToolUse on Bash: refuses banned git, asks about waivable git
│   ├── edit-guard.sh                    PreToolUse on the edit tools: 9.5's block over the edit
│   ├── file-cap.sh                      PostToolUse on the edit tools: the 500-line cap
│   ├── re-anchor.sh                     SessionStart after a compaction or a resume
│   ├── progress-notify.sh               one log line per event, desktop notification on a boundary or a wait
│   ├── statusline.sh                    status line with the ledger position, opt-in by one settings line
│   ├── hook-input.sh                    reads and validates the event JSON, shared
│   ├── progress-log.sh                  the log file and the one line shape, shared
│   ├── path-kind.sh                     code, test, prose or generated, by the law's definitions, shared
│   ├── ledger-position.sh               the ledger heading both the notifier and the status line read
│   └── tests/                           fixture tests, one per script: bash hooks/tests/<name>.test.sh
├── skills/
│   └── engineering-rules/
│       ├── SKILL.md                     the canonical always-on law, routes, map
│       └── references/
│           ├── 00-orientation/          how the sections are organised, the full section map
│           ├── 01-always-on-law/        stubs for 1.1 to 1.8 (canonical text is in SKILL.md), 1.5 procedures
│           ├── 02-doctrine/             code quality, file and folder law
│           ├── 03-catalogs/             performance, security, test scenarios, clean code
│           ├── 04-routes/               quick mode, full mode, and how one is picked
│           ├── 05-working-references/   phase ledger, goal anchor, voice, mindset, delegation
│           ├── 06-phase-1-clarify/      question contract, six question banks, repo brief
│           ├── 07-phase-2-plan/         gate, worktree, work-doc template and rules
│           ├── 08-phase-2-5-spec-review/
│           ├── 09-phase-3-implement/    stage protocol, checklist, perf and law scouts
│           ├── 10-phase-3b-debug/
│           ├── 11-phase-4-verify/       three verify layers, ship gate, cross-package checks
│           ├── 12-phase-5-review/       five review checks, the challenge, the decision table
│           ├── 13-phase-6-finish/       land, cleanup sweep, archive, self-audit, update log
│           ├── 14-anti-patterns/        seven worked examples
│           ├── 15-design/               visual law, spec contract, twelve directions, composition, tells, scout
│           ├── 16-other-routes/         shaping, triage, audit, walkthrough, skill authoring, update log
│           └── 17-ready-made-specs/     twelve complete DESIGN.md files
├── tests/
│   ├── catalog-ids.test.sh              every catalog id, tell id and coarse rule id cited anywhere has a row
│   ├── design-scout.test.sh             runs the design scout's block against planted AI tells and their allowed forms
│   ├── harness.sh                       shared by every test: repo root, scratch dir, the three assertions
│   ├── hook-caps.test.sh                every shell file under 500 lines, every function under 40
│   ├── hooks-wiring.test.sh             every wired script exists, every event script is wired, eight events
│   ├── law-scout.test.sh                runs the law scout's block against planted bans and their equivalents
│   └── no-control-bytes.test.sh         fails on any raw control byte in a tracked file
└── README.md
```

Every reference filename starts with its section number, so a bare "6.13" or "section 16.5"
in the text resolves by looking at the prefix. The full map, with a link per section, is
`references/00-orientation/0.1-how-to-read-this-file.md`.

## The law binds the plugin too

Every file here stays under the 500-line cap the law sets for code, `SKILL.md` included, and
every function in its shell files stays under 40 lines; `tests/hook-caps.test.sh` counts
both and proves it can fail with a planted breach. Section 17's specs are the largest
files at about 470 lines. If a section ever needs more, it is split, not grown.

Six checks run against the plugin itself, all on `tests/harness.sh`:

- `bash tests/no-control-bytes.test.sh` fails on any raw control byte in a tracked file: a
  `\0`, `\b` or `\e` that lost its backslash on the way in reads fine and runs wrong, which is
  how 2.0.1 and 2.1.0 shipped a law scout that scanned nothing.
- `bash tests/law-scout.test.sh` runs the law scout's block straight out of `9.5` against a
  throwaway repo with one planted file per ban and per banned equivalent, and expects every
  hit under its own rule id, every allowed line left alone and every secret redacted. Since
  the edit guard runs the same block, this test covers what the guard refuses.
- `bash tests/design-scout.test.sh` does the same for the design scout's block in `15.29`.
- `bash tests/catalog-ids.test.sh` fails on any `perf.*`, `sec.*`, `test.*`, `style.*` or
  `tell.*` id cited anywhere with no row in its catalog, and on any coarse rule id with no row
  in `16.4`, and proves it can fail by planting one of each.
- `bash tests/hooks-wiring.test.sh` fails when `hooks.json` names a script that is not there,
  when a script that reads an event is not wired, when a command does not go through
  `CLAUDE_PLUGIN_ROOT`, or when one of the eight events is missing.
- `bash tests/hook-caps.test.sh` is the size cap above.

`bash hooks/tests/<name>.test.sh` covers each hook script with fixtures: the git guard's
denies, asks, evasions, allowed commands, reasons and log lines; the edit guard's nine rules,
the law's exemptions, the test-file rows, the grew-versus-kept decision and the missing-law
path; the file cap; the re-anchor on compact and resume; the notifier's five events; the
status line. Every one of them can be pointed at a mutated copy of its script through an
environment variable (`GIT_GUARD_SH`, `EDIT_GUARD_SH`, `FILE_CAP_SH`, `RE_ANCHOR_SH`,
`PROGRESS_NOTIFY_SH`, `STATUSLINE_SH`; `HOOKS_JSON` and `CAP_DIR` for the two repo checks),
so a run that watches the failure is one line. `shellcheck -x -P SCRIPTDIR -S style
hooks/*.sh hooks/tests/*.sh tests/*.sh` is clean, and `claude plugin validate --strict .`
passes.

## Install

Three ways. A machine registers the marketplace name once, so pick GitHub **or** a local
clone as its source, and never combine either with the symlink, or the skill loads twice
under one name.

**From GitHub** (any machine):

```
claude plugin marketplace add nadyshalaby/engineering-rules-plugin
claude plugin install engineering-rules@engineering-rules-marketplace
```

**From a local clone** (the machine you edit on):

```
claude plugin marketplace add ~/engineering-rules-plugin
claude plugin install engineering-rules@engineering-rules-marketplace
```

Either way the plugin is copied into `~/.claude/plugins/cache/engineering-rules-marketplace/`,
so later edits are not seen until the copy is refreshed, and the refresh only happens when
the version changes. After editing anything:

1. bump `version` in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
   (same value in both), re-count the sections with
   `find skills/engineering-rules/references -name '*.md' | wc -l` (that number goes in
   `plugin.json` and the table above; minus the eight always-on stubs, in
   `marketplace.json`), and for the GitHub source commit and push it;
2. run `claude plugin marketplace update engineering-rules-marketplace`;
3. run `claude plugin update engineering-rules@engineering-rules-marketplace`;
4. start a new session, or run `/reload-plugins` in the current one.

Running `claude plugin update` without a version bump reports "already at the latest
version" and copies nothing. Hooks and agents come from the installed copy, so a session
started before the refresh runs the old ones.

**As a live skill** (the fastest editing loop for the law itself): symlink the skill into
your personal skills folder, and every edit is picked up on the next `/reload-plugins` with
no version bump. The hooks and agents do not come along; they need the plugin install.

```
ln -s ~/engineering-rules-plugin/skills/engineering-rules ~/.claude/skills/engineering-rules
```

If the marketplace copy is installed as well, remove it first with
`claude plugin uninstall engineering-rules@engineering-rules-marketplace`.

## Section 17 is droppable

The last group is twelve complete, ready-to-drop `DESIGN.md` specs, about a quarter of the
whole package. Only group 15 (the picker in `15.6`, the direction library in `15.4`) and the
map in `0.1` point into them, and nothing in the working method depends on them. Delete
`references/17-ready-made-specs/` and everything else still works; group 15 still names all
twelve directions and still says how to author a spec from the contract in `15.3`.

## History

- **1.0.0**: a mechanical split of the original `CLAUDE.md`, one section per file, text
  unchanged.
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
