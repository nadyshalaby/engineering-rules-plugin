---
schema_version: "1"
name: agentless-quick
description: The agentless token on a sub-command keeps every helper shape in the main conversation, so the Agent tool is never called, while the ledger, the scouts and the review still run.
tags: [skill, routes, agentless]
runs: 2
max_turns: 25
timeout_seconds: 900
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill, Agent]
expected_outcome: The sub-command loads the skill, states quick mode and agentless with its one-line cost, records "Helpers: agentless" on the ledger line, never calls the Agent tool at any point, and still prints the phase ledger, runs the scouts and the review in the main conversation.
---
/engineering-rules:quick agentless add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`
