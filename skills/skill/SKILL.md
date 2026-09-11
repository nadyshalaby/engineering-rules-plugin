---
name: skill
description: "Skill authoring under the engineering-rules law, picked by your word: a new reusable skill, written last, that passes its structural checks. Usage: /engineering-rules:skill <what the skill should do>"
argument-hint: "[what the skill should do]"
disable-model-invocation: true
---

# Skill authoring, by the user's word

The user typed `/engineering-rules:skill`. That picks skill authoring (16.12) outright: a
new reusable skill, invoked by name later, not a one-off script.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the request**: what the skill should do, and for whom. It is the whole invocation.
   When it is empty, it is what this conversation was last discussing; when there is
   nothing, ask through the wizard tool (4.4), one question.
3. **Say the route and the mode in one line** (1.7, step 2): *"Skill authoring."*, then
   *"Agentless."* with the cost line 4.4 names when agentless is on: switched on by
   `/engineering-rules:agentless` earlier in this conversation, or named in the request.
4. **Read 16.12 from disk and run it.** Writing a skill is a substantive task: the task start
   in 1.7 runs first, and the file is written last, in the order 16.12 fixes.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
