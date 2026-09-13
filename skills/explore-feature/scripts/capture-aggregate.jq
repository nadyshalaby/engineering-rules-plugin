# capture-aggregate.jq: the JSON lines the sink wrote, slurped, into capture.json, the
# contract in 16.10 ("capture.json, written by capture-run.sh"). One anchor per instrumented
# function with its calls (arguments in, value out or error thrown or a void return, the
# time it took) and its branches (per line, how often each way was taken, or which values a
# switch saw), plus one row per hop and the run's own record. capture-run.sh runs it as
#   jq -s --arg root R --arg mode M --arg command C --arg runtime T --arg started S --arg exit E -f capture-aggregate.jq capture.jsonl
# with exit "" when the process was stopped rather than waited for.
def rel($root): if startswith($root + "/") then .[($root | length) + 1:] else . end;
def endOf($ends; $c): $ends[$c | tostring];
def outcome($end):
  if $end == null then { unfinished: true }
  elif $end.k == "throw" then { threw: $end.err, ms: $end.ms }
  elif $end.void == true then { void: true, ms: $end.ms }
  else { out: $end.out, ms: $end.ms } end
  + (if $end != null and $end.async == true then { async: true } else {} end);
def callsOf($enters; $ends):
  [ $enters[] | . as $e | { id: $e.c, seq: $e.seq, in: $e.in } + outcome(endOf($ends; $e.c)) ];
def branchRows($events):
  [ $events[] | select(.k == "branch") ] | group_by(.line) | map({
      line: .[0].line, kind: "branch",
      true: map(select(.v == true)) | length, false: map(select(.v == false)) | length,
      outcomes: map(.v) });
def switchRows($events):
  [ $events[] | select(.k == "switch") ] | group_by(.line) | map({
      line: .[0].line, kind: "switch", values: (map(.v) | unique), seen: length });
def anchorRecord($a; $byAnchor; $ends; $root):
  ($byAnchor[$a.a | tostring] // []) as $events
  | { id: $a.a, hop: $a.hop, file: ($a.file | rel($root)), line: $a.line, name: $a.name, kind: $a.kind,
      calls: callsOf([ $events[] | select(.k == "enter") ]; $ends),
      branches: (branchRows($events) + switchRows($events) | sort_by(.line)) };
def hopRows($anchors):
  $anchors | group_by(.hop) | map({
      hop: .[0].hop, anchors: length,
      calls: (map(.calls | length) | add),
      threw: (map([.calls[] | select(has("threw"))] | length) | add),
      ms: (map([.calls[] | .ms // 0] | add) | add) });

. as $events
| ([ $events[] | select(.k == "anchor") ] | sort_by(.a)) as $anchors
| ([ $events[] | select(.k == "exit" or .k == "throw") ] | map({ key: (.c | tostring), value: . }) | from_entries) as $ends
| ([ $events[] | select(.k == "enter" or .k == "branch" or .k == "switch") ] | group_by(.a) | map({ key: (.[0].a | tostring), value: . }) | from_entries) as $byAnchor
| ([ $anchors[] | anchorRecord(.; $byAnchor; $ends; $root) ]) as $records
| { version: 1,
    run: { mode: $mode, command: $command, runtime: $runtime, started: $started,
           exit: (if $exit == "" then null else ($exit | tonumber) end),
           events: ([ $events[] | select(.k != "anchor") ] | length),
           truncated: ([ $events[] | select(.k == "truncated") ] | length > 0) },
    anchors: $records,
    hops: hopRows($records) }
