---
runs: 1
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Agent, Bash, Edit, Write]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. When a skill says to stop and hand something to a person, stop there and make it your final message, complete. End with one line listing the files you wrote."
expected_outcome: >-
  finish-lane fires for lane M001-S01. The repository has no pull request host, so it does the steps that need only git. It dispatches a fresh reviewer for the lane's commit. The reviewer reads the change against the invariant of the export area (archived rows are never part of an export) and finds that with `since` the filter on archived rows is skipped, although the diff is small, its tests pass and no path rule objects. The round line in .ytstack/M001-S01-PLAN.md carries `risk: high` and names the invariant. The route is `person`, nothing is merged, and the final message hands the lane to a person with the reasons.
---

The worker on lane M001-S01 is done, its report is in .ytstack/M001-S01-REPORT.md and its branch is ytstack/M001-S01. Take the lane from here and get it landed.
