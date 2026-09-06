---
schema_version: "1"
name: ledger-opens
description: A small code task opens the phase ledger before any code is written, asks its clarify round through AskUserQuestion, and writes no banned token.
tags: [skill, ledger]
runs: 2
max_turns: 20
timeout_seconds: 600
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill]
expected_outcome: The engineering-rules skill fires, a block headed "## 0. Phase ledger" is printed before the first file is written, any clarifying question goes through AskUserQuestion, and sum.js lands without a suppression, a debugger statement or a console call.
---
Add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`.
