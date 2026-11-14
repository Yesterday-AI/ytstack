---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: A ytstack skill takes the report (quick-task or systematic-debugging). src/export.sh filters archived rows out also when --since is given, tests/run.sh gains a test for archived rows together with --since, and .ytstack/spec/export.md still says that archived rows are excluded, because the fix restores the described behaviour and changes no requirement.
---

A user reports: when they export with a since date, the output contains archived rows. Fix it.
