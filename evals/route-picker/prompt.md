---
schema_version: "1"
name: route-picker
description: A bare invocation of the skill, with nothing after it, opens the guided intake through AskUserQuestion and starts nothing.
tags: [skill, routes]
runs: 2
max_turns: 4
timeout_seconds: 180
allowed_tools: [Skill, AskUserQuestion, Read]
expected_outcome: After the skill loads, the very next move is one AskUserQuestion that opens the intake of 4.4, asking what the user is here for with the build option (quick or full mode) first, and no task is classified or started before the intake ends.
---
/engineering-rules:engineering-rules
