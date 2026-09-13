# The structural checks of a trace, 16.10 checks 2, 3, 4, 9 and 10 plus the shape of every
# range and citation: everything jq settles without opening a cited file. Prints one line per
# problem, `trace: ...` or `hop <id>: ...`, and nothing when the shape is sound.
# verify-trace.sh runs it with the caps as arguments and refuses the trace on any output.
def entryKinds: ["http", "cli", "job", "ui", "event", "other"];
def hopKinds: ["entry", "call", "middleware", "dispatch", "io", "external", "type"];
def statuses: ["verified", "unresolved"];
def isPosInt: type == "number" and . == floor and . >= 1;
def nonEmpty: type == "string" and length > 0;
def citationProblems($label; $c):
  (if ($c.file | nonEmpty | not) then "\($label): file must be a non-empty string" else empty end),
  (if ($c.line | isPosInt | not) then "\($label): line must be a positive integer" else empty end),
  (if ($c.evidence | nonEmpty | not) then "\($label): evidence must be a non-empty string" else empty end);
def rangeProblems($h):
  if ($h.range | type) != "array" or ($h.range | length) != 2 or ($h.range | all(isPosInt) | not)
  then "hop \($h.id): range must be [start, end], two positive integers"
  elif $h.range[0] > $h.range[1] then "hop \($h.id): range start \($h.range[0]) is after its end \($h.range[1])"
  else empty end;
def hopProblems($earlier; $i; $h):
  (if ($h.title // "" | length) > $maxHopTitle then "hop \($h.id): title is over \($maxHopTitle) characters" else empty end),
  (if ($h.kind | IN(hopKinds[]) | not) then "hop \($h.id): kind \($h.kind) is not one of \(hopKinds | join(", "))" else empty end),
  (if ($h.status | IN(statuses[]) | not) then "hop \($h.id): status must be verified or unresolved" else empty end),
  (if $h.status == "unresolved" and (($h.reason // "") == "") then "hop \($h.id): an unresolved hop needs a reason" else empty end),
  (if $h.status == "unresolved" and (($h.candidates // []) | length) == 0 then "hop \($h.id): an unresolved hop needs at least one candidate" else empty end),
  citationProblems("hop \($h.id)"; $h),
  (if $i > 0 and $h.from == null then "hop \($h.id): from is null on a non-entry hop" else empty end),
  (if $i > 0 and $h.from != null and ($h.from | IN($earlier[]) | not) then "hop \($h.id): from \($h.from) is not an earlier hop" else empty end),
  (if $i > 0 and (($h.call | type) != "object") then "hop \($h.id): call must be an object with file, line and evidence" else empty end),
  (if $i > 0 and (($h.call | type) == "object") then citationProblems("hop \($h.id) call site"; $h.call) else empty end),
  rangeProblems($h);
def refProblems($ids):
  ((.pseudocode // [])[] | .step as $s | (.hops // [])[] | select(IN($ids[]) | not) | "trace: pseudocode step \($s) points at unknown hop \(.)"),
  ((.branches // [])[] | select(.at | IN($ids[]) | not) | "trace: branch \(.name) is at unknown hop \(.at)"),
  ((.failure | if type == "object" then (.hops // []) else [] end)[] | select(IN($ids[]) | not) | "trace: failure path points at unknown hop \(.)"),
  ((.shapes // [])[] | select(.at | IN($ids[]) | not) | "trace: shape \(.label) is at unknown hop \(.at)"),
  ((.decisions // []) | to_entries[] | .key as $d | (.value.hops // [])[] | select(IN($ids[]) | not) | "trace: decision \($d + 1) points at unknown hop \(.)"),
  ((.questions // []) | to_entries[] | .key as $d | (.value.hops // [])[] | select(IN($ids[]) | not) | "trace: question \($d + 1) points at unknown hop \(.)");
def fileProblems:
  ([.files[]?.path] | unique) as $listed
  | ([.hops[].file] | unique) as $cited
  | (($cited - $listed)[] | "trace: hop file \(.) is not listed in files"),
    (($listed - $cited)[] | "trace: files entry \(.) is cited by no hop");
. as $t
| (.hops | length) as $n
| [.hops[].id] as $ids
| (.entry | if type == "object" then .kind else null end) as $entryKind
| [
    (if $n < 1 or $n > $maxHops then "trace: hops must have 1 to \($maxHops) entries, has \($n)" else empty end),
    (if ($ids | unique | length) != $n then "trace: hop ids are not unique" else empty end),
    (if $n > 0 and .hops[0].id != "h0" then "trace: the first hop must be h0, is \(.hops[0].id)" else empty end),
    (if $n > 0 and .hops[0].from != null then "hop h0: from must be null on the entry hop" else empty end),
    (if $n > 0 and .hops[0].call != null then "hop h0: call must be null on the entry hop" else empty end),
    (if (.title // "") == "" then "trace: title is missing" elif (.title | length) > $maxTitle then "trace: title is over \($maxTitle) characters" else empty end),
    (if ($entryKind | IN(entryKinds[]) | not) then "trace: entry.kind \($entryKind) is not one of \(entryKinds | join(", "))" else empty end),
    (.hops | to_entries[] | .key as $i | hopProblems([$t.hops[:$i][].id]; $i; .value)),
    (((.pseudocode // []) | length) as $steps | if $steps < 1 or $steps > $maxSteps then "trace: pseudocode must have 1 to \($maxSteps) steps, has \($steps)" else empty end),
    (((.questions // []) | length) as $q | if $q < $minQuestions or $q > $maxQuestions then "trace: questions must have \($minQuestions) to \($maxQuestions) entries, has \($q)" else empty end),
    (if (.unreached | type) != "array" then "trace: unreached must be an array, [] when nothing was left out" else empty end),
    (if (.failure | type) != "object" then "trace: failure must be an object with title, hops and steps" else empty end),
    fileProblems,
    refProblems($ids)
  ]
| .[]
