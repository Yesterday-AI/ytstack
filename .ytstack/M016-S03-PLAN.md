---
milestone: M016
slice: S03
project: ytstack
created: 2026-11-07T11:05:00Z
status: planned
task_count: 4
completed_tasks: 1
---

# M016-S03 -- Slice Plan

**Goal:** The #26 acceptance criteria are executable tests, the docs describe the new state model, and 0.2.0 ships with issues #24 and #27 closed on evidence.

## Tasks

- [x] T01 -- `tests/hooks-worktree.test.sh`: builds a fixture repo with `.ytstack/` (STATE pointing at an active task, committed hand-written `HANDOFF.md`), adds a linked worktree, snapshots main (`git status --porcelain` + sha256 of every file under `.ytstack/`), then invokes `pre-compact`, `session-end`, `post-tool-use-bash` with realistic payloads for: (a) session in main, (b) session in the worktree, (c) `CLAUDE_PROJECT_DIR`=main while `cwd`=worktree; asserts main byte-identical, `HANDOFF.md` unchanged, output confined to the state dir (or the committing worktree for the stub).
- [ ] T02 -- `tests/hooks-concurrency.test.sh`: two session ids firing `pre-compact` + `session-end` interleaved, asserts both session dirs exist with their own handoff and journal and `latest-handoff` points at the newest; repeated events are idempotent (second `post-tool-use-bash` on the same task creates nothing new). Add `tests/run-all.sh` that runs every `*.test.sh` and exits non-zero on the first failure; wire it into `bin/ytstack-check --tests`.
- [ ] T03 -- Docs: README + QUICKSTART section "Where ytstack writes" (tracked `.ytstack/` artifacts vs. out-of-tree session state, `HANDOFF.md` is user-owned, `.ytstack/.local/` fallback), `docs/concept.md` hook table updated, `KNOWLEDGE.md` gotchas (`CLAUDE_PROJECT_DIR` does not follow worktrees; `%G?` shows `N` for SSH signatures without `allowedSignersFile`; macOS has no `flock`), `CHANGELOG.md` 0.2.0 entry, `plugin.json` 0.1.6 -> 0.2.0 AND `.claude-plugin/marketplace.json` entry version (was stale at 0.1.5; `claude plugin validate` warns) plus a `ytstack-check` rule that both agree, `.ytstack/ROADMAP.md` M013 note (worktree-per-teammate now unblocked).
- [ ] T04 -- Release + closure: run `tests/run-all.sh` + `bin/ytstack-check` + `claude plugin validate .` from a clean checkout and paste the output into closing comments on #24 and #27; tag `v0.2.0` locally; push + `/plugin update` note are operator actions and are listed in STATE.md as such.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: `tests/run-all.sh` green on macOS bash 3.2 and on Linux bash 5 (container or CI runner).

## Notes

- Test fixtures must use `mktemp -d` under `$TMPDIR` and canonicalise with `pwd -P` (macOS `/tmp` -> `/private/tmp`).
- Issue #26 is already closed as a duplicate; its acceptance list is the test spec for T01/T02.
