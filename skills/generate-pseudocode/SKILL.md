---
name: generate-pseudocode
description: "Turn 'explain how this code flow works' into one published Artifact page of complete, self-contained pseudocode: every routine read from source and every helper expanded down to real SQL or an external call, file:line citations, shaded phrases that open a note on why a line is the way it is, and a closing analysis of what differs and what to know before changing anything. Use it whenever someone asks for 'pseudocode for X', 'walk me through X as pseudocode', 'explain both endpoints', 'compare these two flows', 'make me a page explaining how X works', 'complete pseudocode', 'all-in-one pseudocode', or wants one or more endpoints, services, pipelines, jobs or algorithms explained end to end as a page they can read rather than a chat answer. Not for a code review or an architecture diagram; a question whose answer is one routine with nothing to expand is answered in chat, in the same conventions, without a page."
---

# generate-pseudocode

One published page that explains how a code flow works as complete pseudocode: every routine
read from source, every helper expanded, shaded phrases that open a note on the why, and a
closing analysis. The page is a publication: every one this skill produces looks and reads
like the same one, so a reader who has seen one can read the next without relearning it.

Four files carry the format so no page re-derives it:

- `references/page-kit.html`: the stylesheet, the popup script and the markup shape, verbatim.
  Copy it, fill the slots, never rewrite the CSS or the mechanics.
- `references/worked-example.md`: the conventions on a small two-endpoint case, with a good
  note beside a bad one and a finding traced to its line.
- `scripts/check-page.sh`: the pre-publish check. It names dangling links, phrases with no
  note, scaffolding tags, foreign resources and missing theme blocks.
- `scripts/serve.sh`: serves the finished page over localhost for the one look, so nothing
  is written into the repository being read.

## Step 0: is a page the right answer?

The page is for a flow someone wants to read end to end: one or more endpoints, services,
pipelines, jobs or algorithms, alone or compared. The inputs are the flows (entry points,
file paths, endpoint names) and an optional focus such as "just the ranking logic" or
"ignore the parameter differences". A focus decides what MAIN's steps dwell on; it never
excuses a helper MAIN calls from being expanded.

It is not for a code review or an architecture diagram, and not for a question whose honest
answer is small. The test is structural, not a sentence count: one routine, nothing it calls
that needs expanding, no flag, no external call, no SQL. When that holds, answer in chat and
stop, and say in one line that a page would only pad it. A page built around content that
fits on one screen costs the reader a scroll and the session a long build.

A chat answer keeps the conventions that carry truth and drops the ones that carry the
page: a fenced block with the routine's `file:first-last line` and the ref it was read at,
forks written as forks, phases marked with `──`, and nothing from the kit's markup. The
chat path keeps rules 1, 4, 5 and 7 of Step 1 (read the body, label runtime forks, show
the code's own defaults, run what can be run) and drops the ledger file, the kit and the
checks; the citations and the ref stay. The worked example shows the shape.

## Step 1: read before writing

The page is worthless if it is plausible instead of true. It looks authoritative, so a
reader will trust it, and a guessed line does more harm than a missing one. Hold to this
before writing a single line of the page:

1. **Every routine comes from source, read in this session.** Not memory of the codebase,
   not a summary, not a search hit. Open the file and read the body. A routine that was
   not opened in this session does not go on the page.
2. **Every helper the main flow calls is expanded.** The reader does not know this
   codebase. If MAIN says `RESOLVE_ANCHOR(...)`, there is a `RESOLVE_ANCHOR` routine
   further down that spells out what it does, and if that one calls `GEOCODE`, so is
   `GEOCODE`. Recurse until the leaves are real SQL, a real external call, or something
   genuinely primitive: a standard-library call, a comparison, an assignment. A name with
   no expansion is a defect. The check script finds the linked ones that dangle; the
   unlinked ones are found by reading MAIN and asking, for each call, "is it below?".
3. **Keep a reading ledger while reading.** One row per routine, in a scratch file in the
   session scratchpad: `routine | file:first-last line | calls | runtime-decided branches |
   literals`. Record the ref the reading was done at (`git rev-parse --short HEAD`, and the
   branch). The ledger becomes the `.src` citation beside every routine name, the
   eyebrow's "verified at", and the colophon. Writing the citations from the ledger, not
   from memory, is what keeps them true.
4. **Runtime-decided is labelled as such.** A branch that depends on a database lookup, an
   environment variable, a feature flag or a config file is not "the behaviour"; it is
   "the behaviour when that flag is on". Write `IF flag RANK_V2 is on` and keep both arms
   in the listing. Never flatten a flag into a fact: a reader who changes the code on the
   strength of the page must see the same fork the code has.
5. **Defaults shown are the code's own.** The number in the source is what goes on the
   page, said as "1500 in the code". A deployment may set something else through its
   environment, and the colophon says so, once, for the whole page. Never write the number
   from a `.env` you happened to see, and never present a production value as the default.
6. **What could not be verified is said on the page.** An external service's behaviour, a
   generated file you cannot open, a dependency that is not vendored, a database setting
   that changes what a predicate matches: write "not verified here" at that line, and list
   it in the colophon's "Not verified". An honest gap beats a confident guess.
7. **Run what can be run.** When a routine is pure and can be sourced or imported (a shell
   function, a normaliser, a parser, a scoring formula), run it on a handful of inputs
   before writing its edge cases, and say on the page that those results came from a run.
   A gotcha confirmed by a run is a fact; the same gotcha from reading alone is a reading,
   and the note should say which it is.
8. **Large flows are read in parallel, then spot-checked.** The trigger is size, not a
   routine count: more than one subsystem (the HTTP layer, the query layer, a ranking
   module) or more than roughly a thousand lines to read. Send one Explore agent per
   subsystem, each returning ledger rows for its part: routine, file:line, the body in
   prose, what it calls, which branches are runtime-decided, the literals. Then open the
   file yourself for every surprising claim (a hidden filter, a security check, a weight,
   an early return, a swallowed error) before it reaches the page. The agents read; you
   verify. Below that size, reading everything yourself is the more reliable path.

## Step 2: build the page from the kit

Copy `references/page-kit.html` into the session scratchpad, never into the repository
being read: a skill that documents a repo does not write into it. The default name is the
page's title, kebab-cased, `.html`; when the request names a path inside the scratchpad,
that path wins. Then fill every line marked `SLOT` and remove the sample routines. The
sections stay in this order:

**Masthead**, bounded below by a 2px rule in the ink colour.
- `.eyebrow`: `subject · scope · verified at <ref>`, mono, uppercase, letter-spaced.
- `h1`: two or three words in the serif, a name rather than a summary. "Places Search",
  not "How the places endpoints work".
- `.thesis`: one or two sentences, at most 66 characters wide, saying what the page
  contains and promising that nothing on it assumes prior knowledge of the codebase.
- `.howto`: the row "Shaded words open a note", the live demo button wired to the `demo`
  note, "Press Esc to close", and the theme button. Keep it as it is in the kit.
- `nav.toc`: one mono pill per section, each tinted with that section's accent.

**One `section.part` per flow**, `data-accent` `a` for the first flow, `b` for the second,
`c` and `d` beyond that. The whole point is one continuous listing per flow, not a flow
chopped into numbered steps with prose between them.
- `.part-head`: a `.tag` chip ("endpoint 1", "job 2"), an `h2` in the serif, and a mono
  `.sig` holding the real signature copied from the source. For a route handler, which has
  no signature, the `.sig` is the method and path with the query or body fields the handler
  reads.
- `.lede`: two or three sentences on what this flow is and what only it has.
- A stack of `.routine` blocks. The first is always `MAIN`. The rest are the subroutines
  MAIN referenced, in the order MAIN reaches them, each with its `.src` citation in the
  heading. Routine names are `UPPER_SNAKE`; ids are the flow's letter and the name in
  kebab-case: `a-main`, `a-clamp-radius`, `b-main`, `b-search-rows`. A link can then name
  its target without ambiguity.
- The way back is the kit's, not the author's. At load, the script puts an up-link on every
  routine heading back to its flow's MAIN (a shared routine gets one per flow, labelled by
  the flow's tag), and after any jump through a `.ref` link a fixed return button appears,
  labelled with the line the reader left ("Back to endpoint 1 · MAIN · step 3"), which
  takes them back to it. Jumps stack, so a chain of links unwinds one step at a time.
  Write nothing for either; keep the `.howto` line that announces them.

**A shared section**, `data-accent="shared"`, `id="shared"`: every routine that two or more
flows call, written once, ids `s-<routine>`. A routine reached only through a shared
routine (the geocoder that only the anchor resolver calls) lives here too, right after its
caller, with a comment saying which flows can reach it. The section's lede says that where
callers pass different arguments, the difference lives in the caller, not here. A page
about one flow has no shared section.

**The findings section**, three groups in this order, each opened by a small mono uppercase
heading in its accent:
1. *Differences that change behaviour*, accent `diverge`. Omitted on a page about one flow.
2. *Things worth knowing before you change anything*, accent `shared`.
3. *Suggestions*, accent `a`, the first flow's colour.

Each item is a `.fin` card: an `h3` stating the claim as a sentence, an optional `.sev`
chip inside the `h3` naming the severity in two or three words ("changes results",
"silent failure", "low"), and a `.body` of one or two short paragraphs. Every item rests on
a line that appears in the listings above it, and says which through an `<a class="ref">`
link to that routine. No item may introduce a fact the pseudocode does not show: if the
finding needs a line the page lacks, the line goes into the listing first. A finding earns
its card by changing what a reader would do; stop when the next candidate only restates a
note. Three to eight per group is the usual range, and a small codebase has fewer.

**Colophon**: what was read, at what ref, how it was verified (what was run, what was read
twice), the flag-default caveat, and the "Not verified" list. Plain and unhedged. The kit's
flag-default paragraph is the caveat; keep its wording.

## Step 3: the pseudocode

Inside `<pre><code>`, and only there:

- `MAIN` opens with an `INPUT` block naming each input and whether it is required, then
  numbered steps `1`..`N`, right-aligned in a two-space gutter (` 1  `, `10  `), so
  step numbers line up and a finding can say "step 7 of MAIN".
- Subroutines open with `NAME(args):` and an unnumbered body, indented two spaces.
- A call to another routine on the page is `<a class="ref" href="#id">NAME</a>`, dotted
  underline, so the reader jumps to the expansion. Every such link resolves; the check
  script refuses a page where one does not.
- `<span class="kw">` wraps the control words, rendered in the diverge colour: IF, ELSE,
  RETURN, AND, OR, NOT, WHILE, RUNG, ON FAILURE. RUNG is one step of a fallback ladder,
  tried in order ("RUNG 1 coordinates from the query, RUNG 2 the geocoder"); ON FAILURE
  opens the branch an error takes.
- `<span class="lit">` wraps string and number literals, rendered in the shared green.
- `<span class="c">` wraps inline commentary, rendered faint, and
  `<span class="c">── a named phase ──</span>` on its own line divides a long listing into
  phases ("── the query ──", "── ranking ──").
- Where SQL decides the answer, show the bind list (`$1 lng`, `$2 lat`, …) and the CTE
  skeleton with the predicates that matter: the lines that change which rows come back.
  Do not paste the real SQL, and do not invent SQL that is not there.
- Scoring is shown as arithmetic, one weight per line, so weights can be compared across
  flows at a glance:
  ```
  score = 0.6 × closeness
        + 0.3 × rating / 5
        + 0.1 × open
  ```
- Lines stay under about 78 characters, so the listing's sideways scroll rarely engages.
  Break a long condition after AND or OR, indented under the IF.
- A runtime-decided branch is written as the fork it is: `IF flag RANK_V2 is on` with both
  arms, or `IF the row's visibility is public   ── decided by the database`.

## Step 4: the notes

A note is one shaded, clickable phrase in the listing and one arrowed popup anchored to it.
Markup: `<button class="an" data-i="key">shaded phrase</button>`, inline in the `<pre>`. A
button, not a span, so the keyboard reaches it; the script sets `type="button"` and
`aria-expanded`. Content: one entry per key in the `ANN` object at the top of the script,
`key: { t: "Short title", b: "<p>…</p>" }`. Keys are short kebab-case (`radius-default`).
A shaded phrase stays inside one listing line: a button that wraps onto the next line paints
its shade across the indentation there, which at phone width reads as a stray block.

**What a note is for.** It explains why the line is that way: the constraint, the bug it
fixes, the number that was measured, the thing that breaks if you change it. It never
restates what the line already says in English; if the note would only paraphrase the line,
delete the annotation. The line "clamp(radius, 100, 5000)" needs no note saying the radius
is clamped between 100 and 5000; it needs the note saying a 5 km radius is where the index
scan stops paying for itself, or that 100 m is the GPS accuracy floor, if the source or its
history says so, and nothing if neither does.

**Density.** Aim for 80 to 150 notes on a page documenting two substantial flows: every
literal with a reason, every filter, every early return, every default, every fork gets
one. A page with ten notes reads as unexplained. The target scales with the listings: on a
small codebase shade each of those things once and stop. Never pad. A literal whose reason
is recorded nowhere gets the honest floor ("64 is the number in the code; no reason is
recorded for it") or no shade at all.

**Write every note for a reader who has never seen this codebase.** The thesis promises it,
and the notes are where the promise is kept or broken:
- Lead with the consequence. "Without this line, private places show up in search." Then
  the reason, then the number if there is one.
- One idea per note, two to four short sentences. A note that needs a fifth sentence is two
  notes.
- Name things by what they do, and give the code's own word once: "the point the search is
  centred on (the anchor)". A term the codebase invented is glossed the first time it
  appears on the page, in a note or a lede.
- Plain verbs. "Checks", "drops", "sends", "throws". Not "leverages", "performs a check",
  "is responsible for".
- Say what breaks if the line changes, when you know. "Raise this and the geocoder's
  timeout stops firing before the client's does."
- A number is a fact only when it was read from the source or measured; say which. A
  number from memory does not go in a note.

**The demo.** Always keep the `demo` note wired to the masthead's example button, so the
mechanism explains itself before the reader meets a real one. Its text is in the kit.

**When the page must spell a token a guard bans.** A page about a linter, a hook or a
secret scanner has to show the tokens it judges (a suppression marker, a `console` call, a
key prefix), and an installed edit guard that greps every written file will refuse the
write, because the page file is classed as code. Do not route around the guard through the
shell. Write one character of each such token as an HTML character entity in the markup
(`&#64;ts-expect-error`, `console&#46;log`) and as a `\u` escape inside the ANN strings:
the page renders the token exactly, and the file carries none of it. Say in the colophon
that the tokens are entity-spelled and why.

**The mechanics are the fix, not a preference.** The listings live in containers with
`overflow-x: auto`, so a popup positioned inside a listing is clipped at the listing's
edge. The kit's script creates one popover element once, appends it to `document.body`,
positions it `fixed` from `getBoundingClientRect()`, prefers above the trigger and flips
below (adding `.below` so the arrow flips too) when there is no room, keeps the arrow
inside the popup's own width through the `--ax` custom property, keeps the popup 12px from
either viewport edge at `min(370px, viewport - 24px)`, toggles on click, closes on a click
outside, on Esc and on resize, and repositions on scroll with `capture: true` so it follows
a scrolling listing. Keep that script verbatim; do not load a library for it.

## Step 5: the design

The kit carries the tokens; the page never defines a colour outside them.

- Light palette on bare `:root`; the same tokens redefined under
  `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }` and again under
  `:root[data-theme="dark"]`. Never define a colour only inside a media block: the viewer's
  theme has three states (an explicit light or dark stamp on the root, or nothing), and a
  colour that exists only behind one of them renders one theme's text on the other's
  ground. `body` paints its own ground from a token, because the host paints its own
  behind the page.
- The theme button in the masthead cycles system, light, dark, stamps `data-theme` on the
  root, and remembers the choice in the reader's browser. "System" leaves the host's stamp
  alone, so a reader's claude.ai theme still wins until they choose on the page.
- IBM Plex Serif for display (`h1`, `h2`, finding titles), IBM Plex Sans for body, IBM Plex
  Mono for all code, labels, eyebrows and chips, from the one Google Fonts link in the kit,
  each with a real fallback stack. Prose is capped at 66 characters; the code blocks are
  exempt and scroll inside their own container, so the body never scrolls sideways.
- Accents: flow A `#1C5C79`, flow B `#9E6218`, shared `#2F6B4F`, diverge `#94284C`, each
  with a wash, each with a dark counterpart, all in the kit. A page with more than two flows
  uses `c` and `d`, already defined in the same scheme; a fifth flow adds `--flow-e` and its
  wash to all three token blocks and a `[data-accent="e"]` rule, nothing else. A flow's
  `.part-head` border, `.tag` and `.routine > h3` all take the flow's accent through the
  `data-accent` attribute on its section.

## Step 6: check, look once, publish

Run the check before publishing, and fix what it names:

```bash
bash <this skill's directory>/scripts/check-page.sh <the page>.html
```

It refuses a link with no target, a shaded phrase with no note, a doctype or html, head or
body tag, a resource loaded from anywhere but Google Fonts, a missing theme block, and a
missing title. It prints the counts of routines, notes, findings and links so the density
rule can be judged at a glance, counts the listing lines over 78 characters (the width Step 3
asks for), and refuses a page whose mechanics block no longer matches the kit's, which is how
a page built from a kit that changed after it was copied is caught.

Then the three checks only a reader can make, once, on the rendered page. The browser pane
cannot act on a `file://` page, and a preview launch config would have to be written into
the repository being read, so serve the page instead:

```bash
bash <this skill's directory>/scripts/serve.sh <the page>.html   # prints a localhost URL
bash <this skill's directory>/scripts/serve.sh --stop             # when the look is done
```

Open the URL in the browser pane and check:
- (a) No routine is named without being expanded: read MAIN top to bottom and confirm every
  call has its block below, linked.
- (b) Every finding traces to a visible line: click each finding's link and confirm the
  line it rests on is there.
- (c) The popups work: one near the top of the viewport (it opens below), one lower (it
  opens above), one after a resize (it has closed, and reopens in place), in both themes.
  A scripted scroll-then-measure needs `document.documentElement.style.scrollBehavior =
  'auto'` first, because the kit scrolls smoothly for readers.
- (d) The way back works: click a link in MAIN, then the return button; the line you left
  is centred and focused, and every routine heading shows its up-link.

The look leaves nothing in the repository being read. The Playwright browser tool writes its
traces into `.playwright-mcp/` under the working directory, so remove that folder after the
look when it was not there before; the in-app browser pane writes nothing.

The Artifact tool asks for the `artifact-design` skill before any page is written. Load it;
where its general guidance (one look, no test loop) and this file differ, this file wins,
because the user pinned this design and these checks, and their words come first.

Publish with the Artifact tool:
- `<title>` at the top of the file: the `h1`'s name, no colon, no appended explainer.
- `description`: one sentence saying what the page explains.
- `favicon`: one emoji, on the first publish only; omit it on a republish.
- No `<!DOCTYPE>`, `<html>`, `<head>` or `<body>`: the file is the page content, and the
  host wraps it. The two `<meta>` lines at the top of the kit stay: the host adds its own,
  and they keep a copy opened from disk in the right charset and at phone width.
- No external JS. The only permitted external resource is the Google Fonts stylesheet;
  everything else is inline.

Then hand over the link and stop. The live page is the review surface; further polish is
the reader's to ask for.

## A known, deliberate deviation

A finished page runs well past 500 lines, and a file cap hook, where one is installed, will
say so after every write of it. The page is one self-contained file on purpose: it is
opened from disk, sent as one thing and read as one thing, and the kit's stylesheet and
script are the format itself, not supporting code. Splitting them into supporting files
would make the page depend on the host to be readable, so the one over-cap file in the
scratchpad is the deliberate shape of this deliverable, not an oversight. Say so in one
line the first time the hook speaks, and do not split the page.

## Files

```
generate-pseudocode/
├── SKILL.md                      this method
├── references/
│   ├── page-kit.html             the CSS, the popup script and the markup shape, verbatim
│   └── worked-example.md         the conventions on a small two-endpoint case
└── scripts/
    ├── check-page.sh             the pre-publish check
    └── serve.sh                  serves the page over localhost for the one look
```
