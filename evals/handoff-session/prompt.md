---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The handoff-session skill fires and writes .ytstack/HANDOFF.md carrying the in-flight note.
---

Let's do a handoff, I'm switching machines. In flight: the settings-page download button is half done, and the test for empty rows is still red because of a timezone issue. Open decision: whether to gzip the CSV above 10 MB.
