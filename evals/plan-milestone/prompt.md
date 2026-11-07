---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The plan-milestone skill fires and writes M001-CONTEXT.md and M001-ROADMAP.md.
---

Plan the next milestone. Goal: users can export their data as CSV. Exit criteria: GET /export returns a CSV with all rows of the signed-in user; a button on the settings page downloads it. Size: small.
