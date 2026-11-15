---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. This run must never publish anything: wherever you would run gh issue create or gh issue comment, run the same command with echo in front of it instead. End with one line listing the files you wrote."
expected_outcome: The session treats this as feedback about ytstack itself (a gap - the PR watch existed and nothing pointed at it). It runs bin/ytstack-upstream mode, which prints mode suggest from PREFERENCES.md, drafts an issue body with ytstack-upstream draft --kind gap, fills it and runs ytstack-upstream check until it passes. Under suggest it posts nothing (no gh issue create, not even with echo) and its final message shows the person the title and the draft path and asks whether to file it at Yesterday-AI/ytstack.
---

Yesterday the coordinator session polled our three pull requests by hand the whole afternoon, about 40 gh pr view calls, and in the end wrote its own loop for it (scripts/poll-prs.sh). Tonight I saw that the ytstack plugin we use ships a PR watch (ytstack-pr-watch) that does exactly that; nothing in the session ever pointed at it. Please make sure this experience is not lost.
