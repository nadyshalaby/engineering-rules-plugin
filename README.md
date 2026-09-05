# engineering-rules

The engineering law and working method, packaged as one Claude Code skill.

It began as a single 1 MB `CLAUDE.md`, split one section per file behind progressive
disclosure. Version 2.0.0 is a hardening pass over that split. The always-on law now has one
canonical copy, inlined in `SKILL.md`. The seams the split left behind were closed: dangling
references to tooling that never shipped, two competing phase lists, rules restated in
several places with different wording. And a run discipline was added so the law is applied
the same way in every session, whatever the circumstances: a phase ledger that refuses to
advance without its exit artifact, a task-start and phase-boundary protocol, loop-back rules,
a fixed list of what a user may waive and what nobody may, git safety, and a ten-line law
self-audit before any task is called done.

## What loads when

| Level | What | Cost |
|---|---|---|
| 1 | `name` + `description` | Always in context, about 100 words |
| 2 | `SKILL.md`: definitions, precedence, the always-on law (`1.1` to `1.7`), the route table, the group map | Loads when the skill triggers, about 280 lines |
| 3 | `references/**`: all 106 sections, one file each | Only when a phase names one |

The seven always-on sections live in `SKILL.md` because they bind from the moment the skill
loads, and a reference you have to go fetch is a reference you might not fetch. The files
under `references/01-always-on-law/` are short stubs that point back to `SKILL.md`, except
`1.5`, which carries the claim-integrity procedures the laws call for (proving a zero, the
tells of silent failure, the depth tiers). If a stub and `SKILL.md` ever differ, `SKILL.md`
wins.

## How a task runs

Every substantive ask goes through the same phases:
1 Clarify, 2 Plan and gate, 2.5 Spec review, 3 Implement (3b Debug when stuck), 4 Verify,
5 Review, 6 Finish. Quick mode, the default, drops the written plan, the spec review and the
landing menu, and nothing else: every check, both scouts, all three verify layers, the five
review checks and the ship gate still run. Full mode runs when the user names it. The other
routes (shaping, walking one execution path, auditing a whole codebase, review triage,
authoring a skill, authoring a design spec, printing the update log) are picked by the rules
in `4.1`.

The phase ledger (`5.1`) is the order-enforcer. Every phase is an item with an exit artifact,
a phase is ticked only when that artifact exists, and the ledger is re-printed at every
boundary, so a session that lost its context can pick the work up from the ledger alone.
Every question to the user goes through the `AskUserQuestion` tool. Every claim of "done",
"passes" or "clean" has a proof row behind it.

## Layout

```
engineering-rules-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── hooks/
│   ├── hooks.json                       Stop and Notification hooks, live the moment the plugin is installed
│   ├── ledger-position.sh               the ledger heading both scripts read, kept in one place
│   ├── progress-notify.sh               one log line per turn, desktop notification on a boundary or a wait
│   ├── statusline.sh                    status line with the ledger position, opt-in by one settings line
│   └── tests/                           fixture tests for both scripts: bash hooks/tests/<name>.test.sh
├── skills/
│   └── engineering-rules/
│       ├── SKILL.md                     the canonical always-on law, routes, map
│       └── references/
│           ├── 00-orientation/          how the sections are organised, the full section map
│           ├── 01-always-on-law/        stubs for 1.1 to 1.7 (canonical text is in SKILL.md), 1.5 procedures
│           ├── 02-doctrine/             code quality, file and folder law
│           ├── 03-catalogs/             performance, security, test scenarios
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
│           ├── 15-design/               visual law, spec contract, twelve directions
│           ├── 16-other-routes/         shaping, triage, audit, walkthrough, skill authoring, update log
│           └── 17-ready-made-specs/     twelve complete DESIGN.md files
└── README.md
```

Every reference filename starts with its section number, so a bare "6.13" or "section 16.5"
in the text resolves by looking at the prefix. The full map, with a link per section, is
`references/00-orientation/0.1-how-to-read-this-file.md`.

## The law binds the plugin too

Every file here stays under the 500-line cap the law sets for code, `SKILL.md` included.
Section 17's specs are the largest at about 470 lines. If a section ever needs more, it is
split, not grown.

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
   `plugin.json` and the table above; minus the seven always-on stubs, in
   `marketplace.json`), and for the GitHub source commit and push it;
2. run `claude plugin marketplace update engineering-rules-marketplace`;
3. run `claude plugin update engineering-rules@engineering-rules-marketplace`;
4. start a new session, or run `/reload-plugins` in the current one.

Running `claude plugin update` without a version bump reports "already at the latest
version" and copies nothing.

**As a live skill** (the fastest editing loop): symlink the skill into your personal skills folder,
and every edit is picked up on the next `/reload-plugins` with no version bump:

```
ln -s ~/engineering-rules-plugin/skills/engineering-rules ~/.claude/skills/engineering-rules
```

If the marketplace copy is installed as well, remove it first with
`claude plugin uninstall engineering-rules@engineering-rules-marketplace`.

## Progress while you are away

Installing the plugin installs two hooks from `hooks/hooks.json`; nothing to configure.

- **`Stop`**, every time Claude finishes a turn: one line goes to `~/.claude/progress.log`
  (`time | project | stop | (3 of 6, Phase 4) | first line of the reply`), and when that turn
  ends on a ledger re-print a desktop notification says so. Back from a break, run
  `tail ~/.claude/progress.log`.
- **`Notification`**, whenever Claude is blocked on you (a permission prompt, a question, an
  idle wait): a desktop notification saying what it is waiting for, and a `waiting` log line.
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

Desktop notifications use `osascript` on macOS and `notify-send` on Linux; both hooks and
the status line need `jq`. Every exit of the notifier is 0, so a missing tool never fails a
turn. The log is append-only and never trimmed; trim it yourself when it gets long. On macOS
a turn that ends on a ledger re-print is announced twice, once by Claude's notification tool
(the rule in `1.4`) and once by the Stop hook; the hook is the one that cannot be forgotten
under load, so silence the tool's desktop alerts in Claude Code's settings if you want one
alert, or comment out the `notify_desktop` call in `on_stop` for the other.

## Section 17 is droppable

The last group is twelve complete, ready-to-drop `DESIGN.md` specs, about a quarter of the
whole package. Only group 15 (the picker in `15.6`, the direction library in `15.4`) and the
map in `0.1` point into them, and nothing in the working method depends on them. Delete
`references/17-ready-made-specs/` and everything else still works; group 15 still names all
twelve directions and still says how to author a spec from the contract in `15.3`.

## History

- **1.0.0**: a mechanical split of the original `CLAUDE.md`, one section per file, text
  unchanged.
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
