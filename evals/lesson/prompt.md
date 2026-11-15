---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The lesson skill fires. It classifies the incident as the class it already has (area ci, flaky-order) and records it through bin/ytstack-signals lesson new, which counts the second incident on the open lesson F001 (count 2) instead of writing a new lesson file. The lesson stays a machine check (target check:..., tests/order.test.sh or a similar check that runs the suite in another order), built or described as work; it is not answered with a sentence in AGENTS.md, which keeps its one line.
---

Main went red again this morning: tests/export.test.sh failed because it read the temp file that tests/import.test.sh leaves behind, and import happened to run after it. That is the second time this week. I already fixed the test by hand (the last commit). Make sure we actually learn from this one, I do not want a third time.
