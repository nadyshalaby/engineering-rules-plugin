---
name: design
description: "The design-spec route of the engineering-rules law, picked by your word: author, extract or refresh the project's design spec. Usage: /engineering-rules:design [agentless] [author|extract|refresh] [a direction]"
argument-hint: "[agentless] [author|extract|refresh] [a direction]"
arguments: [mode]
disable-model-invocation: true
---

# Design spec, by the user's word

The user typed `/engineering-rules:design`. That picks the design-spec route (15.19)
outright: author, extract or refresh the project's design spec.

- **Mode token:** `$mode`
- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the mode token.** `agentless` or `--agentless` switches agentless mode on for the
   whole task (4.4, 1.8): every helper shape runs in this session and nothing is sent to the
   agent tool. Any other word is not a mode; it is the first word of the request.
3. **Read the request**: the mode 15.19 names (author, extract or refresh) and a direction
   from the library (15.4) when the user named one. It is the whole invocation with the mode
   token removed. Nothing left means 15.19 detects the mode from the repository; nothing is
   asked before it has looked.
4. **Say the route and the mode in one line** (1.7, step 2): *"Design spec."*, then
   *"Agentless."* with the cost line 4.4 names when it is on.
5. **Read 15.19 from disk and run it**, with 15.1 to 15.6 as it names them. Writing or
   changing the spec is a substantive task: the task start in 1.7 runs first.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
