---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The slice-milestone skill fires and writes M001-S01-PLAN.md with two tasks.
---

Slice milestone M001. One slice: goal "export endpoint + settings button". Tasks: (1) GET /export streams the user's rows as CSV; (2) settings page gets a "Download CSV" button that calls /export.
