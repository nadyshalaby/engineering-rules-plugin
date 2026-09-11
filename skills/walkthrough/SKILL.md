---
name: walkthrough
description: "Code walkthrough under the engineering-rules law, picked by your word: one execution path traced to its leaves, for code nobody in the room wrote. Usage: /engineering-rules:walkthrough [agentless] <the entry point>"
argument-hint: "[agentless] [the entry point]"
arguments: [mode]
disable-model-invocation: true
---

# Code walkthrough, by the user's word

The user typed `/engineering-rules:walkthrough`. That picks the walkthrough (16.9)
outright: one execution path, traced to its leaves.

- **Mode token:** `$mode`
- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the mode token.** `agentless` or `--agentless` switches agentless mode on for the
   whole task (4.4, 1.8): every helper shape runs in this session and nothing is sent to the
   agent tool. Any other word is not a mode; it is the first word of the request.
3. **Read the entry point.** It is the whole invocation with the mode token removed. When
   nothing is left, ask for it through the wizard tool (4.4), one question; 16.9 stops on an
   ambiguous entry point anyway, so it is settled before anything is read.
4. **Say the route and the mode in one line** (1.7, step 2): *"Walkthrough."*, then
   *"Agentless."* with the cost line 4.4 names when it is on.
5. **Read 16.9 from disk and run it**, with 16.10 and 16.11 as it names them. The always-on
   law binds throughout, the wizard tool for every question included. The route edits
   nothing, so no ledger opens unless the user turns a finding into a task, which then
   starts under 1.7.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
