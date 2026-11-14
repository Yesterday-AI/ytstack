---
runs: 1
max_turns: 90
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Agent, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: adopt-brownfield fires (not office-hours, not init-project), .ytstack/PROJECT.md references the existing docs, and .ytstack/spec/SPEC.md lists the areas with area files that point at docs/architecture.md instead of copying it.
---

Set up ytstack here.
