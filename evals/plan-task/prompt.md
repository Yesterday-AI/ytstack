---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The plan-task skill fires, writes M001-S01-T01-PLAN.md and sets STATE active_task to T01.
---

Plan the next task. Files: create src/export.ts and tests/export.test.ts. The endpoint GET /export selects all rows of the signed-in user, writes a header line and one CSV line per row, and streams the response with content-type text/csv. Verification: npm test.
