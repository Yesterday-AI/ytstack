# Preferences

Local preferences for ytstack development. These apply to every ytstack session for this project.

## Explain level

explain_level: default

Options: `default` | `terse` | `brutal`

See `docs/ux/writing-style.md` § Explain-level toggles.

## Ceremony

granularity: task        # task | slice | milestone -- smallest unit that gets a PLAN/SUMMARY pair
autonomy: loop           # loop = chain plan-task -> TDD -> verify -> summarize inside a slice without asking; step = ask before each step
quick_lane: on           # one-sentence changes go through ytstack:quick-task (Q### artifacts), no pitch, no review
minimal_code: on         # inject the minimal-code guard (YAGNI ladder, never-cut list) at session start
team: off                # off = spawn-milestone-team dispatches worktree subagents (default); on = Claude Code Agent Teams (experimental)
upstream_feedback: suggest  # this is the ytstack repository: its own artifacts are the place; the channel is for consumer projects
merge_by: human          # the maintainer merges every pull request here (decided 2026-11-15); no REVIEW.md, no auto_merge
escalate: violation, deviation, irreversible, secret, spend  # the full list: the maintainer wants rule and plan breaks, one-way steps, secrets and spend; the rest the coordinator decides (issue #78)

## Model preferences

None currently. Use Claude Code's default.

## Timeouts

Defaults. Raise if working with large vendored subtree diffs.

## Custom

- **Milestone granularity:** target 3-7 tasks per slice, 3-5 slices per milestone. If a milestone grows past ~20 tasks, split it.
- **Commit policy:** atomic commits per task. Skill `ytstack:summarize-task` (M003) will enforce this.
- **Dogfood:** every ytstack skill gets used on ytstack itself before release. If it feels clunky developing ytstack, it will feel clunky for users.
