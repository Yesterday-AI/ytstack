---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The plan-task skill fires and writes M001-S01-T01-PLAN.md with a "Spec impact" section that names the export area, because the task changes behaviour that .ytstack/spec/export.md describes.
---

Plan the next task. Files: modify src/export.ts and tests/export.test.ts. GET /export gets an optional query parameter `since` (an ISO date): only rows changed on or after that date are exported, and a value that is not a date answers 400. Without the parameter nothing changes. Verification: bash tests/run.sh.
