---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion) or to wait for an answer, do not wait: answer the question yourself in the user's stead with the most plausible choice, state the assumption, and continue to the written design. End with one line listing the files you wrote."
expected_outcome: grill fires (not plan-milestone, not office-hours) and writes .ytstack/GRILL-<slug>.md with approaches and the chosen design.
---

Before we plan the next milestone, poke holes in this idea: a weekly scheduled CSV export that is emailed to the account owner. I want the design questioned first, not a milestone yet.
