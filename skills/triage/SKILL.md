---
name: triage
description: "Review triage under the engineering-rules law, picked by your word: a batch of review findings becomes a per-finding accept, push-back, defer or needs-restatement table. Usage: /engineering-rules:triage <the pasted findings>"
argument-hint: "[the pasted findings]"
disable-model-invocation: true
---

# Review triage, by the user's word

The user typed `/engineering-rules:triage`. That picks review triage (16.2) outright: a
batch of review findings becomes one decision per finding.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the findings.** They are the whole invocation or, when it is empty, the batch
   pasted most recently in this conversation; when there is neither, ask for them through
   the wizard tool (4.4), one question, and nothing else.
3. **Say the route and the mode in one line** (1.7, step 2): *"Review triage."*, then
   *"Agentless."* with the cost line 4.4 names, agentless being the default, unless helpers
   were switched on by `/engineering-rules:agents` earlier in this conversation or named in
   the request, then *"Agents on, because you asked for it."*.
4. **Read 16.2 from disk and run it.** The always-on law binds throughout; a finding accepted
   for a fix is a task, and it starts under 1.7 when the user says go.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
