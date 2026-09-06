---
schema_version: "1"
name: route-picker
description: A bare invocation of the skill, with no task and no route token, puts the route table to the user through AskUserQuestion and starts nothing.
tags: [skill, routes]
runs: 2
max_turns: 4
timeout_seconds: 180
allowed_tools: [Skill, AskUserQuestion, Read]
expected_outcome: After the skill loads, the very next move is one AskUserQuestion carrying the route table (quick, full, shape, walkthrough, audit, triage, skill, design, log) with quick mode as the first option, and no task is classified or started before the answer.
---
/engineering-rules:engineering-rules
