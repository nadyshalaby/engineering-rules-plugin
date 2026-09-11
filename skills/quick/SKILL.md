---
name: quick
description: "Quick mode of the engineering-rules law, picked by your word: every check, every scout, the full review and the ship gate, with no written plan. Usage: /engineering-rules:quick <what you want done>"
argument-hint: "[what you want done]"
disable-model-invocation: true
---

# Quick mode, by the user's word

The user typed `/engineering-rules:quick`. That picks quick mode (4.2) outright: the
classifier in 4.1 does not run, and no other route is considered.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the request.** It is the whole invocation. When it is empty, it is the most recent
   ask in this conversation, in the user's own words; when there is none either, ask for it
   through the wizard tool as 4.4 says, and ask nothing else.
3. **Say the route and the mode in one line** (1.7, step 2): *"Quick mode."*, then
   *"Agentless."* with the cost line 4.4 names when agentless is on: switched on by
   `/engineering-rules:agentless` earlier in this conversation, or named in the request.
4. **Run the task start** (1.7, from step 3): the base commit, the ledger with quick mode's
   six items (5.1), the helper line as 1.8 records it, then 6.1 read from disk.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
