# Worked example: two places endpoints

A small case showing every convention once. The codebase is a places API with a nearby
endpoint and a name-search endpoint that share a filter and a ranking routine. Everything
below was read from source in the session that wrote it; the ledger came first.

## The reading ledger

Kept in the scratchpad while reading, one row per routine. Every citation on the page is
copied from here, never typed from memory.

```
ref: 3f2a9c1 on main

routine         | file:lines              | calls                                 | runtime-decided        | literals
MAIN (nearby)   | src/http/nearby.ts:14-29 | RESOLVE_ANCHOR CLAMP_RADIUS ...      | -                      | 400, limit*3
CLAMP_RADIUS    | src/config.ts:9-14       | -                                     | PLACES_RADIUS_M (env)  | 1500, 100, 5000
NEARBY_ROWS     | src/db/queries.ts:11-32  | SQL                                   | -                      | $1..$4
RANK_ROWS       | src/rank/score.ts:9-17   | SCORE                                 | RANK_V2 (env)          | 0.6 0.3 0.1 / 0.5 0.3 0.1 0.1
GEOCODE         | src/geo/geocode.ts:7-13  | fetch (external)                      | geocoder's own ranking | 800 ms, limit=1
```

## MAIN, with the INPUT block, the gutter, a phase divider, a link and a note

```html
<article class="routine" id="a-main">
  <h3>MAIN <span class="src">src/http/nearby.ts:14–29</span></h3>
  <pre><code>INPUT
  lng, lat                <span class="c">── required unless near is given</span>
  near                    <span class="c">── optional, a place name</span>
  radius_m, limit         <span class="c">── optional</span>

 1  anchor = <a class="ref" href="#s-resolve-anchor">RESOLVE_ANCHOR</a>(lng, lat, near)
 2  <span class="kw">IF</span> anchor is null
      <span class="kw">RETURN</span> <span class="lit">400</span> <span class="lit">"lng and lat, or near, are required"</span>
 3  radius = <a class="ref" href="#a-clamp-radius">CLAMP_RADIUS</a>(radius_m)
    <span class="c">── the query ──</span>
 4  rows = <a class="ref" href="#a-nearby-rows">NEARBY_ROWS</a>(anchor, radius, <button class="an" data-i="overfetch">limit × 3</button>)
 5  rows = <a class="ref" href="#s-apply-filters">APPLY_FILTERS</a>(rows, open_now)   <span class="c">── nearby passes open_now only</span>
 6  rows = <a class="ref" href="#s-rank-rows">RANK_ROWS</a>(rows, anchor, radius)
 7  <span class="kw">RETURN</span> <span class="lit">200</span> first limit of rows, each through <a class="ref" href="#s-present">PRESENT</a></code></pre>
</article>
```

Step numbers are right-aligned in a two-space gutter, so ` 1` and `10` line up. A call to a
routine on the page is a link; the target's id says which flow owns it (`a-`, `b-`) or that
it is shared (`s-`).

## A query routine: the bind list and the CTE skeleton, not the SQL

```html
<pre><code>NEARBY_ROWS(anchor, radius, limit):
  binds  <span class="lit">$1</span> anchor.lng  <span class="lit">$2</span> anchor.lat  <span class="lit">$3</span> radius  <span class="lit">$4</span> limit
  <span class="kw">WITH</span> candidates <span class="kw">AS</span>
    places <span class="kw">WHERE</span> deleted_at <span class="kw">IS NULL</span>
       <span class="kw">AND</span> <button class="an" data-i="dwithin">within $3 metres of ($1, $2)</button>
    <span class="c">── no visibility predicate here; search has one ──</span>
  <span class="kw">RETURN</span> candidates <span class="kw">ORDER BY</span> distance <span class="kw">LIMIT</span> $4</code></pre>
```

The lines shown are the ones that change which rows come back. The join columns, the casts
and the projection are not, so they are not here.

## Scoring as arithmetic, and a flag written as the fork it is

```html
<pre><code>RANK_ROWS(rows, anchor, radius):
  <span class="kw">IF</span> flag <button class="an" data-i="rank-v2">RANK_V2</button> is on          <span class="c">── read from the environment at start-up</span>
    score = <span class="lit">0.5</span> × closeness
          + <span class="lit">0.3</span> × rating / 5
          + <span class="lit">0.1</span> × has_hours
          + <span class="lit">0.1</span> × recency
  <span class="kw">ELSE</span>
    score = <span class="lit">0.6</span> × closeness
          + <span class="lit">0.3</span> × rating / 5
          + <span class="lit">0.1</span> × has_hours
  closeness = max(0, 1 − distance / (radius <span class="kw">OR</span> <span class="lit">5000</span>))
  rating    = row.rating <span class="kw">OR</span> <button class="an" data-i="unrated">3</button>
  <span class="kw">RETURN</span> rows sorted by score, highest first</code></pre>
```

Both arms stay on the page. "The weights are 0.5/0.3/0.1/0.1" would be flattening a flag
into a fact; a reader on a deployment without the flag would be reading the wrong formula.

## A fallback ladder and an error branch

```html
<pre><code>RESOLVE_ANCHOR(lng, lat, near):
  <span class="kw">RUNG</span> 1  <span class="kw">IF</span> lng <span class="kw">AND</span> lat are finite numbers inside ±180 / ±90
            <span class="kw">RETURN</span> point(lng, lat), source <span class="lit">"coords"</span>
  <span class="kw">RUNG</span> 2  <span class="kw">IF</span> near has at least <span class="lit">3</span> characters
            hit = <a class="ref" href="#s-geocode">GEOCODE</a>(near)
            <span class="kw">RETURN</span> hit's point, source <span class="lit">"geocoded"</span>, <span class="kw">OR</span> null when there is no hit
            <span class="kw">ON FAILURE</span> the error is not caught here   <span class="c">── a timeout becomes a 500</span>
  <span class="kw">RETURN</span> null</code></pre>
```

## A good note beside a bad one

The line: `radius = clamp(radius_m, 100, 5000)`.

Bad, because it repeats the line in English:

```js
"clamp": { t: "The radius is clamped", b: "<p>The radius is limited to between 100 and 5000 metres.</p>" }
```

Good, because it says why, and what breaks:

```js
"clamp": {
  t: "Why the radius stops at 5 km",
  b: "<p>Above 5 km the distance index stops paying for itself and the query scans most of a city. 100 m is the floor because phone GPS is rarely better than that, so a smaller radius mostly returns nothing.</p><p>Raise the ceiling and the nearby query's cost grows with the square of the radius.</p>"
}
```

Written for someone who has never seen the codebase: the consequence first, plain verbs,
the numbers from the source, a gloss for nothing because nothing here is jargon. If neither
the source nor its history says why 5000, the note says "5000 is the number in the code; no
reason is recorded for it", or the phrase is not shaded at all.

## A finding that traces to a line

```html
<article class="fin">
  <h3>Nearby returns private places; search never does <span class="sev">changes results</span></h3>
  <div class="body">
    <p><a class="ref" href="#b-search-rows">SEARCH_ROWS</a> keeps only rows whose visibility is public. <a class="ref" href="#a-nearby-rows">NEARBY_ROWS</a> has no such line, so a private place inside the radius comes back from nearby with its name and location.</p>
    <p>Nothing downstream removes it: <a class="ref" href="#s-present">PRESENT</a> drops the visibility column but keeps the row.</p>
  </div>
</article>
```

Every sentence names the routine it rests on, and the line it names is in the listing
above. A finding that needed a line the page did not show would first add the line.

## The colophon, plain and unhedged

> **What was read.** Every file named beside a routine, opened in this session at `3f2a9c1`
> on `main`: the two route files, `config.ts`, `queries.ts`, `filters.ts`, `hours.ts`,
> `score.ts`, `anchor.ts`, `geocode.ts`, `normalize.ts`, `present.ts`.
> **How it was verified.** Each routine was read in full before it was written; the
> surprising lines (the missing visibility predicate, the UTC clock, the uncaught timeout)
> were opened a second time before they went into a finding.
> **Flag defaults.** Every default on this page is the code's own, read from the source. A
> deployment can override any of them through its environment, and no such override is
> known here.
> **Not verified.** How the geocoder ranks an ambiguous name; the database's trigram
> similarity threshold, which decides what the search predicate matches.

## A page about one flow

Same masthead, one `section.part`, no shared section, and the findings keep only the second
and third groups. The lede still says what only this flow has, compared with nothing: what
it takes in, what it never does.

## The chat form, when a page would only pad the answer

One routine, nothing to expand, no flag, no external call, no SQL: the answer goes in chat,
in a fenced block, with the citation and the ref on the first line and the kit's markup
left out. Run-confirmed gotchas follow as bullets that say they came from a run, and one
line says a page is not being made.

```
PATH_KIND(path):                                hooks/path-kind.sh:9-24, read at b5a8e60 on main
  name = everything after the last "/"
  ── 1. the name alone can settle it ──
  IF name ends in .md .txt .csv .svg or starts with LICENSE   RETURN prose
  IF name matches *.generated.* *.min.js *.lock *.snap        RETURN generated
  ── 2. then the directories in the path ──
  IF a segment is exactly docs                                 RETURN prose
  IF a segment is node_modules dist build vendor migrations    RETURN generated
  IF a segment is exactly tests test spec __tests__            RETURN test
  ── 3. then the name again ──
  IF name matches *.test.* *.spec.* *_test.* *_spec.* test_*   RETURN test
  RETURN code
```

- Prose and generated win before test: `tests/README.md` is prose, `dist/foo.test.js` is
  generated (run on 36 sample paths, not read).
- A directory counts only as an exact segment: `x.test.y/foo.js` and `mytests/foo.js` are code.

Not making a page for this one; it would be these lines with a masthead on top.
