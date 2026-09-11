---
name: log
description: "Prints the engineering-rules update log for the task in flight: the plain-language summary, on demand, mid-flight (16.13). Usage: /engineering-rules:log"
disable-model-invocation: true
---

# The update log, on demand

The user typed `/engineering-rules:log`. That picks the update log (16.13) outright. It takes
no mode token and no request: printing a summary is not a task, and it sends no helper.

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. Its intake does not
   fire; the route is already picked (4.4).
2. **Read 16.13 from disk** and print the log with `{{invocation_phase}}` set to
   `mid-flight`, from the ledger, the evidence and the commits of the task in flight in this
   conversation. Every claim in it has a proof row behind it (1.5, 1.7).
3. **When no task is in flight**, say so in one line and print nothing else. The ledger does
   not move, nothing is ticked, and nothing else starts.
