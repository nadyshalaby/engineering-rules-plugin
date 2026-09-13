# capture-verify.jq: a capture.json against the trace it claims to belong to. Every anchor
# must name a hop the trace has, sit in that hop's file and inside its range, every branch
# line must sit inside that range too, every call must carry its arguments and exactly one
# outcome, and the run must have reached at least one call. Prints one line per problem,
# `capture: ...` or `anchor <id>: ...`, and nothing when the capture is sound; capture-run.sh
# and build-page.sh refuse the capture on any output. Run as
#   jq -r --slurpfile trace trace.json -f capture-verify.jq capture.json
def hopOf($id): first($trace[0].hops[] | select(.id == $id)) // null;
def isNum: type == "number";
def outcomes: [has("out"), has("threw"), has("void"), has("unfinished")] | map(select(.)) | length;
def callProblems($a; $c):
  (if ($c.in | type) != "array" then "anchor \($a.id): call \($c.id) has no argument list" else empty end),
  (if ($c | outcomes) != 1 then "anchor \($a.id): call \($c.id) must carry exactly one of out, threw, void, unfinished" else empty end),
  (if ($c.unfinished | not) and ($c.ms | isNum | not) then "anchor \($a.id): call \($c.id) has no duration" else empty end);
def branchProblems($a; $h; $b):
  (if ($b.kind | IN("branch", "switch") | not) then "anchor \($a.id): branch at line \($b.line) has kind \($b.kind), not branch or switch" else empty end),
  (if ($b.line | isNum | not) or $b.line < $h.range[0] or $b.line > $h.range[1] then "anchor \($a.id): branch line \($b.line) is outside hop \($h.id)'s range \($h.range)" else empty end);
def anchorProblems($a):
  hopOf($a.hop) as $h
  | if $h == null then "anchor \($a.id): hop \($a.hop) is not in the trace"
    else
      (if $a.file != $h.file then "anchor \($a.id): file \($a.file) is not hop \($h.id)'s file \($h.file)" else empty end),
      (if ($a.line | isNum | not) or $a.line < $h.range[0] or $a.line > $h.range[1] then "anchor \($a.id): line \($a.line) is outside hop \($h.id)'s range \($h.range)" else empty end),
      (if ($a.calls | type) != "array" then "anchor \($a.id): calls must be an array" else ($a.calls[] | callProblems($a; .)) end),
      (if ($a.branches | type) != "array" then "anchor \($a.id): branches must be an array" else ($a.branches[] | branchProblems($a; $h; .)) end)
    end;

(if .version != 1 then "capture: version must be 1" else empty end),
(if (.run.mode | IN("test", "live") | not) then "capture: run.mode must be test or live" else empty end),
(if (.anchors | type) != "array" then "capture: anchors must be an array" else empty end),
(if (.anchors | type) == "array" and ([.anchors[] | .calls[]?] | length) == 0 then "capture: no call was recorded; the command did not run the traced code" else empty end),
(if (.anchors | type) == "array" then (.anchors[] | anchorProblems(.)) else empty end)
