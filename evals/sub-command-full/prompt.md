---
schema_version: "1"
name: sub-command-full
description: The full-mode sub-command picks full mode by the user's word, with no classification and no picker, and opens the ten-item ledger before any code.
tags: [skill, routes, sub-commands]
runs: 2
max_turns: 20
timeout_seconds: 600
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill, Agent]
expected_outcome: The sub-command loads the engineering-rules skill, states "Full mode, because you asked for it." without putting a route menu to the user, prints a phase ledger with ten items before any file is written, and asks its clarify round through AskUserQuestion.
---
/engineering-rules:full add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`
