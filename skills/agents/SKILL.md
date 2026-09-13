---
name: agents
description: "Agents on for the engineering-rules law: agentless is the default, and this switch sends the helper shapes (readers, the stage-end scouts, the fresh-eyes reviewers, a mechanic, a builder) to subagents through the agent tool, for the task in flight and every task after it in this conversation, until you say off. Usage: /engineering-rules:agents [what you want done | off]"
argument-hint: "[what you want done | off]"
disable-model-invocation: true
---

# Agents on, by the user's word

The user typed `/engineering-rules:agents`. Agentless is the default helper mode (4.4, 1.8):
every helper shape (5.5) runs in this session and nothing is sent to the agent tool. This
switch sends those shapes to subagents instead, for the task in flight and for every task
that starts in this conversation, until they switch back. It picks no route; the routes have
sub-commands of their own, and this one combines with any of them.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. Its intake does not
   fire from here.
2. **Read the invocation.**
   - The single word `off` switches back to agentless: print the helper line
     `Helpers: agentless, the default; every shape runs in this session.` with the cost line
     4.4 names, and from the next run point of the task in flight every mandated send is the
     same work done here; nothing already done is re-done. Then stop.
   - Empty, with a task in flight (a ledger is open): switch that task now. Probe the runtime
     once as 1.8 says, print `Helpers: available, by user choice.` (or the unavailable line),
     and the sends resume from the next run point; nothing already done is re-done.
   - Empty, with no task in flight: say in one line that agents are on for this
     conversation, probe once and print the helper line, then wait for the task or a route
     sub-command. Nothing else starts, and nothing is asked.
   - Anything else is the request. Agents are on for it, and it classifies under 4.1
     exactly as prose typed into `/engineering-rules:engineering-rules` does: full mode
     unless the words name another route.
3. **With a request, say the route and the mode in one line** (1.7, step 2), *"Agents on,
   because you asked for it."* included, then **run the task start** (1.7, from step 3): the
   base commit, the ledger for the route, the helper line as 1.8 records it, then 6.1 from
   disk.

Everything after that is the law, unchanged. Agents on moves the reading out and removes
nothing: not a check, not a scout, not a gate.
