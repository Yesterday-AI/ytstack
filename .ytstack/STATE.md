---
project: ytstack
slug: ytstack
last_updated: 2026-11-16T09:00:00Z
current_milestone: none
active_slice: none
active_task: none
---

# State

**Status (2026-11-16, 0.12.0):** Release of the issue work since 0.11.0, outside any milestone: PRs #77 (#70, artifacts follow their milestone's directory; #86, `teammate-idle` sum), #87 (#72-#76, standing instructions and the operating path), #88 (#75, #76, spec delta in briefs and `finish-lane`, plan-first briefs, `reconcile` task-plan skeletons), #89 (#85, PR watch on own PRs), #90 (#81, #84, progress per phase, lane liveness, worktree inventory, peers), #92 (#91, focus PRs and STALL lines), #93 (#78, escalation policy, question class and context gate), #94 (#82, #83, stale-checkout hooks, coordinator path hints, no PR closes, rotation). The six gstack-derived skills moved their baseline to gstack v1.99.5.0 (no text change). Release PR `chore/release-0.12.0`; merge and tag `v0.12.0` by the maintainer.

**Status (2026-11-15, backlog):** M034 planned (M, 3 slices: the session's current todo item and n/m in each host's status line, optional herdr and terminal-title sinks) and put on the backlog by the maintainer; no milestone is current. Research: `docs/research/2026-11-15-sticky-session-status.md`. When it is picked up: set `current_milestone: M034` and run `ytstack:slice-milestone`.

Released: 0.11.0 (`a783924`, tag `v0.11.0`): M031 factory tools explicit, M032 incident to lesson loop, M033 upstream feedback channel. 0.12.0 is in its release PR (see the status above). Everything earlier: `archive/2026-11-15/STATE-history.md` (moved verbatim by `ytstack:reconcile`).

## Next action

- Merge the 0.12.0 release PR and tag `v0.12.0` (maintainer).
- No milestone is current. Open issues: #79 (tracking files cost one PR per bookkeeping step) and #80 (engine routing and usage limits), both waiting for the maintainer's decision; #95 (the coordinator SessionStart injection has no headroom left and cuts `using-ytstack`), filed during the release; #42 (status-line research, answered by the M034 research note), #34 (coordinator mode; shipped in 0.7.0, issue still open), #28 (OpenCode host), #29 (Mistral Vibe host).
- Open question `Q001` (gate G01 of M024, "the pipeline works against a real pull request host"): decide it from the context-mcp field runs.
- Merges in this repository are by the maintainer (`merge_by: human` in `PREFERENCES.md`).

## Open decisions

None currently. See DECISIONS.md for locked choices.
