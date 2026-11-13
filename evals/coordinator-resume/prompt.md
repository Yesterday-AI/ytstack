---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The coordinate skill (or resume-session) fires and the answer is built from .ytstack/ alone. It names the three lanes M001-S01 (merged), M001-S02 (running) and M001-S03 (in review, round 1), repeats the next action of the running lane (compare the downloaded file with docs/export-sample.csv), and names the open question Q001 that blocks S05. It states nothing about pull requests, because the repository has no host.
---

The context was compacted and I lost the thread. Where do we stand, and what is next for each lane?
