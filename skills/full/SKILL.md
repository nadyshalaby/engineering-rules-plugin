---
name: full
description: "Full mode of the engineering-rules law, picked by your word: quick mode plus a written plan you approve first, a spec review and a durable work-doc. Usage: /engineering-rules:full <what you want done>"
argument-hint: "[what you want done]"
disable-model-invocation: true
---

# Full mode, by the user's word

The user typed `/engineering-rules:full`. That picks full mode (4.3), the default route,
outright by the user's word. The classifier in 4.1 does not run, and no other route is
considered.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the request.** It is the whole invocation. When it is empty, it is the most recent
   ask in this conversation, in the user's own words; when there is none either, ask for it
   through the wizard tool as 4.4 says, and ask nothing else.
3. **Say the route and the mode in one line** (1.7, step 2): *"Full mode, because you asked for it."*, then
   *"Agentless."* with the cost line 4.4 names, agentless being the default, unless helpers
   were switched on by `/engineering-rules:agents` earlier in this conversation or named in
   the request, then *"Agents on, because you asked for it."*.
4. **Run the task start** (1.7, from step 3): the base commit, the ledger with full mode's
   ten items (5.1), the helper line as 1.8 records it, then 6.1 read from disk. The plan is
   the gate; nothing is built before the user's go through the wizard tool (7.1).

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
