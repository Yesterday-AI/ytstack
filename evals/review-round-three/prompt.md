---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Agent, Bash, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. When a skill says to stop and put something to the human, stop there and make it your final message, complete. End with one line listing the files you wrote."
expected_outcome: code-review fires, finds two review rounds already recorded in the task plan and does not dispatch a third reviewer. It stops with a diagnosis of why the review does not converge (the plan never says whether a row changed on the since date is included, so the two rounds asked for opposite things and the comparison flipped from < to <= and back) and puts that to the human.
---

The last fix is in. Review it again.
