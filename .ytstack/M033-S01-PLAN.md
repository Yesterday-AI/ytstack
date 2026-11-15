---
milestone: M033
slice: S01
project: ytstack
created: 2026-11-15T00:50:00Z
status: in-progress
task_count: 4
completed_tasks: 1
---

# M033-S01 -- Slice Plan

**Goal:** Agents feed their experience with ytstack back upstream through one channel with a setting (`upstream_feedback: suggest | file | off`, default `suggest`): what goes there and when, the rules a machine can check before anything is posted, and an "Upstream" section at the end of `retro` and `lane-retro`.

**Blocked by:** none (M032's `lesson` skill is on the base branch)

## Tasks

- [x] T01 -- The setting and the helper: `yt_prefs` reads `upstream_feedback` from `PREFERENCES.md`, then from `~/.ytstack/config` (`upstream_feedback=...`), default `suggest`, an invalid value reads as `suggest`; `bin/ytstack-upstream` with `mode` (the effective setting, `file` falls back to `suggest` without `gh` auth), `draft` (an issue body with version, host and placeholders; never posts) and `check` (placeholders left, no evidence, no search line, an email address, a token-looking string, a home directory path). Tests in `tests/git-ctx.test.sh` and a new `tests/ytstack-upstream.test.sh`.
- [ ] T02 -- The channel: `docs/ux/upstream-feedback.md` (what goes upstream, when, the rules, the three settings, the helper); `using-ytstack` "Reporting ytstack issues" becomes a short pointer to it within the SessionStart budget; the `PREFERENCES.md` templates of `init-project` and `adopt-brownfield` carry the key.
- [ ] T03 -- `retro` and `lane-retro` end with an "Upstream" section filed per the setting; `lesson` routes a lesson that concerns ytstack itself to the channel. Preamble flags pinned in `tests/skill-preambles.test.sh`.
- [ ] T04 -- Eval cases `upstream-suggest` and `upstream-file` (not run), `evals/README.md` rows, the `skills`, `checks-and-evals` and `artifacts` area files, a `DECISIONS.md` entry.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Source: issue #55; `M033-CONTEXT.md` (exit criteria, the locked default `suggest`, the open question on duplicates and `gh` auth, answered in T01 and T02).
- The helper never posts. Posting is the agent's `gh issue create` / `gh issue comment` after `ytstack-upstream check` passed, so a machine sees the body before anything is public.
- `using-ytstack` is injected in full at every session start and this repository's injection sits near the 9,500-character guard (KNOWLEDGE, M031-S03): the paragraph stays about as long as it is, the rules live in the doc.
- README, QUICKSTART, CHANGELOG, STATE and the ROADMAP files are written by the coordinating session; their text is proposed in the report.
