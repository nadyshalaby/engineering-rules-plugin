---
name: shape
description: "Shaping under the engineering-rules law, picked by your word: one Socratic conversation, one or two forking questions a turn, until the idea is a task and the build starts. Usage: /engineering-rules:shape <the idea>"
argument-hint: "[the idea]"
disable-model-invocation: true
---

# Shaping, by the user's word

The user typed `/engineering-rules:shape`. That picks shaping (16.1) outright: the idea is
not a task yet, and the trigger phrases 16.1 lists no longer matter.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the idea.** It is the whole invocation. When it is empty, it is what this
   conversation was last discussing; when there is nothing, ask what is on their mind
   through the wizard tool (4.4), one question, and nothing else.
3. **Say the route and the mode in one line** (1.7, step 2): *"Shaping."*, then
   *"Agentless."* with the cost line 4.4 names, agentless being the default, unless helpers
   were switched on by `/engineering-rules:agents` earlier in this conversation or named in
   the request, then *"Agents on, because you asked for it."*.
4. **Read 16.1 from disk and run it**: one or two forking questions per turn, every one
   through the wizard tool, nothing edited, until the user signals intent to build. The
   handoff runs the task start in 1.7 under the route 16.1 names, full mode unless the user
   named quick, with the helper mode carried into the build.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
