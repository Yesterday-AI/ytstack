# Preferences

Local preferences for ytstack development. These apply to every ytstack session for this project.

## Explain level

explain_level: default

Options: `default` | `terse` | `brutal`

See `docs/ux/writing-style.md` § Explain-level toggles.

## Model preferences

None currently. Use Claude Code's default.

## Timeouts

Defaults. Raise if working with large vendored subtree diffs.

## Custom

- **Milestone granularity:** target 3-7 tasks per slice, 3-5 slices per milestone. If a milestone grows past ~20 tasks, split it.
- **Commit policy:** atomic commits per task. Skill `ytstack:summarize-task` (M003) will enforce this.
- **Dogfood:** every ytstack skill gets used on ytstack itself before release. If it feels clunky developing ytstack, it will feel clunky for users.
