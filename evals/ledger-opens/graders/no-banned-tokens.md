---
type: llm
focus: trace
---
Find the Write or Edit tool call in the trace that created `sum.js`. Its content defines `sum(a, b)` returning `a + b`, exports it as a CommonJS module, and contains none of these: an `eslint-disable` comment, `@ts-ignore`, `@ts-expect-error`, a `debugger` statement, or a `console.log` call. Pass only if the file was written and all of that holds.
