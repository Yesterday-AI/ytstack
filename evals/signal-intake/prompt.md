---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The signal-intake skill fires, reads the one declared source once and records through bin/ytstack-signals. The error nobody recorded (5101) becomes a new finding, the sighting of the open finding F001 (4812) raises its count from 3 to 4 without a new file, and the sighting of the fixed finding F002 (3990) becomes a new finding with reopens F002. Nothing outside .ytstack/ changes; in particular src/export.js, which holds the obvious cause of 5101, is not edited, and no task is opened.
---

This is the morning run and nobody is at the keyboard. Look at what production reported over the last day and write down whatever needs somebody's attention, so that the team finds it when they start.
