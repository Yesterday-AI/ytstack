---
runs: 1
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: The plan-task skill fires and writes M003-S01-T01-PLAN.md with the two files and the verification command. The plan names the contract the task changes, the export area of the technical spec (.ytstack/spec/export.md).
---

Plan the next task. The export gets an option to write JSON instead of CSV: with `--format json` it prints the same rows as a JSON array with one object per row and the keys id, name and changed. Without the option the output stays CSV. Files: modify src/export.sh and tests/run.sh. Verification: bash tests/run.sh.
