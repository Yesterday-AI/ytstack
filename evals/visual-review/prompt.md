---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Edit, Write]
append_system_prompt: "Headless evaluation run, no human available. When a skill says to ask the user (AskUserQuestion), do not ask: take the option marked RECOMMENDATION or infer the answer from the prompt, then continue. When a skill says to stop with a verdict, stop there and make it your final message, complete. End with one line listing the files you wrote."
expected_outcome: >-
  visual-review fires for the last commit and the lens `ui`. The product cannot be looked at here, the start command of RUNTIME.md names a server that is not in the repository and the session has no browser tool, so the review ends with the verdict `not run` and its reason. The line `- Lens ui: <commit> -- not run; ...` is appended under `## Review` in .ytstack/M001-S01-PLAN.md. No `pass` is recorded from reading src/ui/settings.html and src/ui/settings.css, although the stylesheet visibly breaks the guidelines, and no product file is edited.
---

The settings page got its danger zone in the last commit. Do the visual review of that commit against our design guidelines before S01 is finished.
