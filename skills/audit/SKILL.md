---
name: audit
description: "Codebase audit under the engineering-rules law, picked by your word: the whole codebase against its own rules and the catalogs, not a per-diff review. Usage: /engineering-rules:audit [a project root or directory]"
argument-hint: "[a project root or directory]"
disable-model-invocation: true
---

# Codebase audit, by the user's word

The user typed `/engineering-rules:audit`. That picks the audit (16.3) outright: the whole
codebase against its rules, never a per-diff review.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. It binds this session
   in full from that moment. Its intake does not fire; the route is already picked (4.4).
2. **Read the scope.** It is the whole invocation: a project root or a directory. Empty
   means the current project, which the preflight in 16.3 confirms; nothing is asked before
   it has looked.
3. **Say the route and the mode in one line** (1.7, step 2): *"Codebase audit."*, then
   *"Agentless."* with the cost line 4.4 names, agentless being the default, unless helpers
   were switched on by `/engineering-rules:agents` earlier in this conversation or named in
   the request, then *"Agents on, because you asked for it."*.
4. **Read 16.3 from disk and run it**; it reaches 16.4 to 16.8 as it goes. The always-on law
   binds throughout: the remediation phase proposes and confirms per finding through the
   wizard tool, and every fix taken is a task that starts under 1.7.

Everything after that is the law, unchanged. A sub-command picks the row; it never waives a
phase, a check or a gate.
