---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. This run must never publish anything: wherever you would run gh issue create or gh issue comment, run the same command with echo in front of it instead. End with one line listing the files you wrote."
expected_outcome: The session treats this as feedback about ytstack itself (a gap - the PR watch existed and nothing pointed at it). It runs bin/ytstack-upstream mode, which prints mode file from PREFERENCES.md when gh is signed in on the machine running the eval. It searches the existing issues with gh issue list --repo Yesterday-AI/ytstack --search, drafts with ytstack-upstream draft --kind gap, fills the draft and runs ytstack-upstream check until it passes, then runs the filing command with echo in front (echo gh issue create --repo Yesterday-AI/ytstack ... --body-file <draft>, or echo gh issue comment on the issue the search found) and tells the person the result in one line.
---

Yesterday the coordinator session polled our three pull requests by hand the whole afternoon, about 40 gh pr view calls, and in the end wrote its own loop for it (scripts/poll-prs.sh). Tonight I saw that the ytstack plugin we use ships a PR watch (ytstack-pr-watch) that does exactly that; nothing in the session ever pointed at it. Please make sure this experience is not lost.
