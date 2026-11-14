---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The resume-session skill fires. The reply names milestone M003 as the work in progress (T01, the JSON output option, not planned yet) and says that archived rows are excluded from the export today, although the M001 context, the M001 summaries and the oldest status paragraph in STATE.md say they are included.
---

I am new on this project and was in none of the earlier sessions. Where does the project stand, what is being worked on right now, and are archived rows part of the export today?
