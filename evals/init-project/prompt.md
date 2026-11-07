---
runs: 1
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: init-project fires (the pitch exists, the repo is not brownfield) and scaffolds .ytstack/ with STATE.md and PROJECT.md.
---

The pitch is validated (OFFICE-HOURS.md). Initialize ytstack for this project, project scope.
