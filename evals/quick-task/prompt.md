---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The quick-task skill fires (not plan-task), fixes the typo and writes .ytstack/quick/Q001-PLAN.md + Q001-SUMMARY.md.
---

Fix the typo "recieve" in README.md, it should be "receive". Verify with grep.
