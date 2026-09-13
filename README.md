# engineering-rules

The engineering law and working method, packaged as one Claude Code plugin: a skill that
carries the law, hooks that enforce the parts of it a hook can see, the prompts that bind
Claude Code's own agent types to the helper shapes the law sends work to, and eval cases
that state what the plugin promises.

It began as a single 1 MB `CLAUDE.md`, split one section per file behind progressive
disclosure. Version 2.0.0 was a hardening pass over that split: one canonical copy of the
always-on law, inlined in `SKILL.md`; the seams the split left behind closed; a run discipline
so the law is applied the same way in every session, with a phase ledger that refuses to
advance without its exit artifact, loop-back rules, a fixed list of what a user may waive and
what nobody may, git safety, and a law self-audit before any task is called done. Version
2.5.0 moves the enforceable part of that law from the prompt into the runtime: a git command
the law bans is refused before it runs, an edit that adds a banned token is refused before it
lands, a file that crosses the line cap is reported the moment it is written, and a session
that lost its context is re-anchored on the law and the ledger before its next step. Version
2.6.0 takes the git guard back out: the shell is no longer judged at the tool boundary, and
the git safety law binds through the skill alone. Version 2.11.0 splits the route parameter
into nine sub-commands, turns the bare invocation into a guided intake, and adds an agentless
mode that keeps every helper shape in the main conversation; 2.12.0 makes that mode a
sub-command of its own; 2.13.0 makes it the default, with full mode, and 2.13.1 renames the
switch to `/engineering-rules:agents`.

## What loads when

| Level | What | Cost |
|---|---|---|
| 1 | `name` + `description` | Always in context, about 100 words |
| 2 | `SKILL.md`: definitions, precedence, the always-on law (`1.1` to `1.8`), the route table, the group map | Loads when the skill triggers, about 400 lines |
| 2 | `skills/<name>/SKILL.md`: the ten sub-commands, nine routes and the agents switch, about 35 lines each | Only when the user types one; the model cannot invoke them, so they cost it nothing |
| 3 | `references/**`: all 122 sections, one file each | Only when a phase names one |
| hooks | `hooks/hooks.json`: eight events, three guard and anchor scripts plus the notifier | Live from install, no prompt cost; up to half a second per edit of a code file |

The eight always-on sections live in `SKILL.md` because they bind from the moment the skill
loads, and a reference you have to go fetch is a reference you might not fetch. The files
under `references/01-always-on-law/` are short stubs that point back to `SKILL.md`, except
`1.5`, which carries the claim-integrity procedures the laws call for (proving a zero, the
tells of silent failure, the depth tiers). If a stub and `SKILL.md` ever differ, `SKILL.md`
wins.

## How a task runs

Every substantive ask goes through the same phases:
1 Clarify, 2 Plan and gate, 2.5 Spec review, 3 Implement (3b Debug when stuck), 4 Verify,
5 Review, 6 Finish. Full mode, the default, adds a written plan the user approves first, a
spec review and a durable work-doc; quick mode, when the user names it, drops exactly those
and the landing menu, and nothing else: every check, every scout, all three verify layers,
the five review checks and the ship gate still run. The other
routes (shaping, walking one execution path, auditing a whole codebase, review triage,
authoring a skill, authoring a design spec, printing the update log) are picked by the rules
in `4.1`. Every route also has a sub-command that picks it by the user's word, and the bare
invocation walks the user through the options before anything starts (`4.4`, below).

The phase ledger (`5.1`) is the order-enforcer. Every phase is an item with an exit artifact,
a phase is ticked only when that artifact exists, and the ledger is re-printed at every
boundary, so a session that lost its context can pick the work up from the ledger alone.
Every question to the user goes through the `AskUserQuestion` tool. Every claim of "done",
"passes" or "clean" has a proof row behind it. Every stage sweeps its own leftovers both
ways before it commits, removes the dead code already in the files it touched in a commit of
its own, and shows the search behind every new symbol (`1.1`, `9.1`). Work the law sends out of the session (a
reader, the stage-end scouts, the fresh reviewer, a mechanic, a builder; `5.5`) goes through
the `Agent` tool on the agent types Claude Code ships itself (`fork`, `Explore`, `Plan`,
`general-purpose`); `5.5` carries the prompt each shape is sent, pasted whole on every send.
Agentless mode (`4.4`) is the default: nothing is sent unless the user switched helpers on,
by `/engineering-rules:agents` or in their own words; the same work runs in the main
conversation, in the same order, and the ledger records that instead of a send.

## The sub-commands, the intake and agentless mode

The route used to be a parameter of the one skill. Since 2.11.0 every route is a sub-command
of its own: a skill under `skills/<route>/` that only the user can invoke, so the model can
never pick quick mode by itself. Each one loads the law, names its route and hands over the
request:

| Sub-command | Route | What follows it |
|---|---|---|
| `/engineering-rules:quick` | Quick mode (`4.2`) | the request |
| `/engineering-rules:full` | Full mode (`4.3`) | the request |
| `/engineering-rules:shape` | Shaping (`16.1`) | the idea |
| `/engineering-rules:explore-feature` | Explore a feature (`16.9`) | the entry point |
| `/engineering-rules:audit` | Codebase audit (`16.3`) | a project root or directory, or nothing for the current project |
| `/engineering-rules:triage` | Review triage (`16.2`) | the pasted findings |
| `/engineering-rules:skill` | Skill authoring (`16.12`) | what the skill should do |
| `/engineering-rules:design` | Design spec (`15.19`) | the mode or a direction, or nothing to detect it |
| `/engineering-rules:log` | Update log (`16.13`) | nothing |

`/engineering-rules:engineering-rules <request>` still works and classifies the request as
prose; it carries no route token any more. Typed bare, it runs the intake through the wizard
tool: what you are here for, then which route, then helpers or agentless, then the request,
and the flow starts only when all three are settled (`4.4`). The old picker asked for nine
options in one question, which the wizard tool cannot hold; the intake reaches them in two.

**Agentless mode is the default**: every helper shape (`5.5`) runs in the main conversation.
Helpers are switched on by the tenth sub-command, `/engineering-rules:agents`: bare, it
holds for the task in flight and every task that starts in this conversation until
`/engineering-rules:agents off`; with a request after it, that request classifies as prose
(full mode unless the words name another route) and starts with helpers. The same words in
your own message, or the intake's helper question, switch them on too; the size of the task
never does. Under the default every send the law mandates (`1.8`) is the same work done in
the session, in the same order: the question batch, the scouts at every stage end, the spec
review, the five review checks, every count. The ledger records
`Helpers: agentless, the default` once, each affected item carries
`helper skipped: agentless, the default`, and the one-line cost is said at task start: the
review loses its fresh eyes, and the reading lands in the session's context. Nothing else
moves. `/engineering-rules:agents off`, or saying so, switches back to the default: the
session prints the agentless line and the cost again. Nothing at the tool
boundary enforces the mode; the law text does.

## The law at the tool boundary

Installing the plugin installs `hooks/hooks.json`; nothing to configure. Every hook is a
plain shell script that reads the event on stdin, needs `bash`, `jq`, `git` and the usual `awk`, `sed` and coreutils, and exits 0
whatever happens: a hook that cannot read its input has no opinion, and a missing tool never
fails a turn. Nothing here calls a model.

| Event | Script | What it does |
|---|---|---|
| `PreToolUse` on `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | `edit-guard.sh` | Runs the law scout's own block (`9.5`) over the edit and refuses it when it adds a banned token. |
| `PostToolUse` on the same four | `file-cap.sh` | Tells Claude when the file it just wrote is over 500 lines (`1.1`). |
| `SessionStart` on `compact` or `resume` | `re-anchor.sh` | Puts the re-read instruction (`1.7`, step 7) and the last ledger position into the new context. |
| `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `Notification` | `progress-notify.sh` | One log line per event, a desktop notification on a boundary, a wait or an error. |

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
guard | edit | deny | ban.suppression | src/a.ts | line 3 of the new text
cap | file-lines | src/big.ts | 512 lines
anchor | compact | (3 of 6, Phase 4)
stop | (3 of 6, Phase 4) | first line of the reply
waiting | permission_prompt | what it is waiting for
error | rate_limit | the message
helper | start | general-purpose | the brief
helper | stop | general-purpose | first line of the return
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

## The helper shapes

The plugin ships no agents. The four shapes the delegation rule (`5.5`) sends work to run on
the agent types Claude Code ships itself, and `5.5` carries the prompt each shape is sent,
pasted whole on every send: a built-in type holds none of the law, so the prompt is the only
thing between it and drift. Every shape runs on the session's model; no send names one. In agentless mode (`4.4`) none
is sent: the same work runs in the session, in the same order.

| Shape | Agent type | What it may do |
|---|---|---|
| the reader | `fork` for the scouts, the question batch and a catalog lookup (it inherits the conversation and needs no prompt); `Explore` with the reader prompt for a wide read-only search | Returns only the rows that apply, each with `file:line`, and a coverage line. Never edits. |
| the fresh reviewer of Phase 5 | `general-purpose` with the reviewer prompt, never a fork | Reads the five review checks (`12.3` to `12.7`) at the paths the brief names, runs them over the diff, returns findings in the review's shape. Never edits, never asks, never spawns. |
| the spec reviewer of Phase 2.5 (full mode) | `Plan` with the spec-reviewer prompt, read-only by construction, never a fork | Reads `8.2`, `5.2`, `2.1`, `2.2` and the plan, returns the execution order and findings by lens with severities. Never edits the work-doc, never asks, never spawns. |
| the mechanic | `general-purpose` with the mechanic prompt | Runs the command it was given and returns the raw output, nothing summarized. |
| a builder | `general-purpose` with the builder prompt, or a fork for a single stage | Loads the skill, builds one stage inside the file allowlist it was handed, never commits, never spawns. Isolation is chosen on the send. |

Every hook fires inside an agent too, so a builder is under the same guards as the session.

## The evals

`evals/` holds five cases in the plugin-eval shape (`prompt.md` plus graders): `git-safety`
(a prompt that invites a destructive git command; the run must refuse and name the law),
`ledger-opens` (a small code task; the skill must fire, the ledger must be printed, every
question must go through the wizard tool, no banned token may land), `route-picker` (the
bare slash invocation; the intake must open through the wizard tool and nothing may start),
`sub-command-full` (`/engineering-rules:full` with a task; full mode by the user's word, a
ten-item ledger, no route menu) and `agentless-default` (`/engineering-rules:quick` with a
task; the Agent tool is never called while the ledger, the scouts and the review still run).
The runner,
`claude plugin eval`, is in early access at the time of writing; until it runs here, the cases
are the written statement of what the plugin promises, and the headless boots below are the
proof.

## Layout

```
engineering-rules-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── evals/
│   ├── git-safety/                      prompt.md + graders/
│   ├── ledger-opens/
│   ├── route-picker/
│   ├── sub-command-full/
│   └── agentless-default/
├── hooks/
│   ├── hooks.json                       eight events, live the moment the plugin is installed
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
│   ├── quick/ full/ shape/ audit/ triage/ skill/ design/ log/ agents/
│   │                                    one SKILL.md each: the route sub-commands and the agents switch, user-invocable only
│   ├── explore-feature/
│   │   ├── SKILL.md                     the explore-feature sub-command, user-invocable only
│   │   ├── scripts/                     verify-trace.sh with verify-trace.jq, build-page.sh; tests/ with a sample-repo fixture
│   │   └── assets/                      the page template: page.html, page.css, page.js, page-highlight.js, page-flow.js
│   └── engineering-rules/
│       ├── SKILL.md                     the canonical always-on law, routes, map
│       └── references/
│           ├── 00-orientation/          how the sections are organised, the full section map
│           ├── 01-always-on-law/        stubs for 1.1 to 1.8 (canonical text is in SKILL.md), 1.5 procedures
│           ├── 02-doctrine/             code quality, file and folder law
│           ├── 03-catalogs/             performance, security, test scenarios, clean code
│           ├── 04-routes/               how one is picked, quick, full, the sub-commands, the intake, agentless
│           ├── 05-working-references/   phase ledger, goal anchor, voice, mindset, delegation
│           ├── 06-phase-1-clarify/      question contract, six banks, repo brief, coverage map
│           ├── 07-phase-2-plan/         gate, worktree, work-doc template and rules
│           ├── 08-phase-2-5-spec-review/
│           ├── 09-phase-3-implement/    stage protocol, checklist, perf and law scouts
│           ├── 10-phase-3b-debug/
│           ├── 11-phase-4-verify/       three verify layers, ship gate, cross-package checks
│           ├── 12-phase-5-review/       five review checks, the challenge, the decision table
│           ├── 13-phase-6-finish/       land, cleanup sweep, archive, self-audit, update log
│           ├── 14-anti-patterns/        seven worked examples
│           ├── 15-design/               visual law, spec contract, twelve directions, composition, tells, scout
│           ├── 16-other-routes/         shaping, triage, audit, explore-feature, skill authoring, update log
│           └── 17-ready-made-specs/     twelve complete DESIGN.md files
├── tests/
│   ├── catalog-ids.test.sh              every catalog id, tell id and coarse rule id cited anywhere has a row
│   ├── design-scout.test.sh             runs the design scout's block against planted AI tells and their allowed forms
│   ├── explore-feature-page.test.sh     the page template: five markers once, no host at all, no debug artifact, the theme blocks, the cap
│   ├── harness.sh                       shared by every test: repo root, scratch dir, the three assertions
│   ├── hook-caps.test.sh                every shell file under 500 lines, every function under 40
│   ├── hooks-wiring.test.sh             every wired script exists, every event script is wired, eight events, no hook on Bash
│   ├── law-scout.test.sh                runs the law scout's block against planted bans and their equivalents
│   ├── no-control-bytes.test.sh         fails on any raw control byte in a tracked file
│   └── sub-commands.test.sh             the route table and the sub-command skills agree, each with the shape 4.4 promises
├── README.md
└── CHANGELOG.md                         one entry per version, newest first
```

Every reference filename starts with its section number, so a bare "6.13" or "section 16.5"
in the text resolves by looking at the prefix. The full map, with a link per section, is
`references/00-orientation/0.1-how-to-read-this-file.md`.

## The law binds the plugin too

Every file here stays under the 500-line cap the law sets for code, `SKILL.md` included, and
every function in its shell files stays under 40 lines; `tests/hook-caps.test.sh` counts
both and proves it can fail with a planted breach. Section 17's specs are the largest
files at about 470 lines. If a section ever needs more, it is split, not grown.

Eight checks run against the plugin itself, all on `tests/harness.sh`:

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
  `CLAUDE_PLUGIN_ROOT`, when one of the eight events is missing, or when a hook reaches the
  `Bash` tool.
- `bash tests/hook-caps.test.sh` is the size cap above.
- `bash tests/sub-commands.test.sh` fails when a route row of `SKILL.md` has no
  `skills/<route>/SKILL.md`, when a skill directory is neither a route row nor the agents
  switch, when a sub-command's name, user-only invocation or law load is missing or it takes
  an argument list, when the switch lacks its `off` word, or when a section a route row cites
  has no file, and proves it can fail by planting each.
- `bash tests/explore-feature-page.test.sh` fails when the page template loses one of the
  five markers `build-page.sh` replaces or gains a second, reaches any host at all
  stylesheet's, carries a console call, a `debugger`, an empty catch or an `innerHTML`
  write, loses one of the three theme blocks or the body's own ground, or crosses 500
  lines, and proves it can fail by planting each.

`bash hooks/tests/<name>.test.sh` covers each hook script with fixtures: the edit guard's
nine rules, the law's exemptions, the test-file rows, the grew-versus-kept decision and the
missing-law path; the file cap; the re-anchor on compact and resume; the notifier's five
events; the status line. Every one of them can be pointed at a mutated copy of its script
through an environment variable (`EDIT_GUARD_SH`, `FILE_CAP_SH`, `RE_ANCHOR_SH`,
`PROGRESS_NOTIFY_SH`, `STATUSLINE_SH`; `HOOKS_JSON`, `CAP_DIR`, `SKILLS_DIR` and `ASSETS_DIR`
for the four repo checks), so a run that watches the failure is one line.
`bash skills/explore-feature/scripts/tests/<name>.test.sh` covers the two explore-feature
scripts on a sample-repo fixture: `verify-trace` (the sample trace passes; one mutation per
check is refused with its own line and nothing written; excerpts are copied from disk; an
uncommitted change to a cited file is named) and `build-page` (one self-contained page with
every marker gone, both blobs embedded with `<` escaped and the title escaped; a missing
input, a stale excerpts file, a broken template and a hardcoded secret in an excerpt are
refused, the secret judged by the law scout's own block in `9.5` and never printed), each pointable at a
mutated copy through `VERIFY_TRACE_SH` or `BUILD_PAGE_SH`, the secret scan at another copy of
`9.5` through `LAW_SCOUT_MD`. `shellcheck -x -P SCRIPTDIR
-S style hooks/*.sh hooks/tests/*.sh tests/*.sh skills/*/scripts/*.sh
skills/*/scripts/tests/*.sh skills/*/scripts/tests/fixtures/*.sh` is clean, and
`claude plugin validate --strict .` passes.

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
version" and copies nothing. Hooks come from the installed copy, so a session started
before the refresh runs the old ones.

**As a live skill** (the fastest editing loop for the law itself): symlink the skill into
your personal skills folder, and every edit is picked up on the next `/reload-plugins` with
no version bump. The hooks do not come along; they need the plugin install.

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

One entry per version, newest first, in [CHANGELOG.md](CHANGELOG.md).
