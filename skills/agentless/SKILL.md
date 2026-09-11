---
name: agentless
description: "Agentless mode of the engineering-rules law: every helper shape runs in this chat and nothing is sent to the agent tool, for the task in flight and every task after it in this conversation, until you say off. Usage: /engineering-rules:agentless [what you want done | off]"
argument-hint: "[what you want done | off]"
disable-model-invocation: true
---

# Agentless mode, by the user's word

The user typed `/engineering-rules:agentless`. That switches agentless mode on (4.4, 1.8):
every helper shape (5.5) runs in this session and nothing is sent to the agent tool, for the
task in flight and for every task that starts in this conversation, until they switch it
off. It picks no route; the routes have sub-commands of their own, and this one combines
with any of them.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. Its intake does not
   fire from here.
2. **Read the invocation.**
   - The single word `off` switches agentless mode off: print `Helpers: available.` on its
     own line, probe the runtime once as 1.8 says, and the sends resume from the next run
     point of the task in flight; nothing already done is re-done. Then stop.
   - Empty, with a task in flight (a ledger is open): switch that task now. Print the helper
     line `Helpers: agentless, by user choice; every shape runs in this session.` and the
     cost line 4.4 names, and carry on from the next run point; nothing already done is
     re-done.
   - Empty, with no task in flight: say in one line that agentless mode is on for this
     conversation, with the cost line, and wait for the task or a route sub-command. Nothing
     else starts, and nothing is asked.
   - Anything else is the request. Agentless is on for it, and it classifies under 4.1
     exactly as prose typed into `/engineering-rules:engineering-rules` does: quick mode
     unless the words name another route.
3. **With a request, say the route and the mode in one line** (1.7, step 2), *"Agentless."*
   and the cost line included, then **run the task start** (1.7, from step 3): the base
   commit, the ledger for the route, the helper line as 1.8 records it, then 6.1 from disk.

Everything after that is the law, unchanged. Agentless moves the reading here and removes
nothing: not a check, not a scout, not a gate.
