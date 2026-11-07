---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The reassess-roadmap skill fires, reads the S01 summaries and reports on S02 (keep as is).
---

Slice S01 is done. Does the roadmap still fit reality? If nothing material changed, keep S02 as it is.
