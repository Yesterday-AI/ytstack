---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The summarize-task skill fires, writes M001-S01-T01-SUMMARY.md and flips the T01 checkbox in the slice plan.
---

Task done. GET /export now streams all rows of the signed-in user as CSV with a header line; empty accounts get the header only. No deviations from the plan, no follow-ups. Verification `bash tests/run.sh` passed (exit 0, "1 test passed"). Close the task.
