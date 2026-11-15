---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: >-
  The reconcile skill fires, its preamble reports the plan in plans/ (one plan file with 9 open board rows plus 2 checklist items, the retro file has no open rows), and the agent takes option A. It writes M001-CONTEXT.md, M001-ROADMAP.md with one slice per open board row (EXP-03 to EXP-11) and a slice plan per slice whose Source line points at plans/2026-11-01-export-v2.md with the row id; the EXP-04 slice is blocked by the EXP-03 slice and no slice is blocked by the done EXP-02. PREFERENCES.md records `external_plans: plans mapped <date>`. Nothing under plans/ changes. ytstack-frontier list --milestone M001 lists the slices.
---

Our export v2 plan lives in plans/ and the lane list (ytstack-frontier) shows nothing for it, so we track lanes by hand. Clean up our ytstack setup so the open work shows up there. Do not touch the plan files themselves.
