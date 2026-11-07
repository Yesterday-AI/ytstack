---
milestone: M017
slice: S01
project: ytstack
created: 2026-11-07T14:00:00Z
status: planned
task_count: 2
completed_tasks: 1
---

# M017-S01 -- Slice Plan

**Goal:** `vendor/superpowers/` tracks upstream v7.0.2 and the three wrappers render its text without leaking upstream namespaces or relative links; the checker guards against future leaks.

## Tasks

- [x] T01 -- Pull the subtree: verify `gh api repos/obra/superpowers/git/ref/tags/v7.0.2` resolves to `22f0b46`; `git subtree pull --prefix vendor/superpowers https://github.com/obra/superpowers.git v7.0.2 --squash`; confirm the three wrapped `skills/*/SKILL.md` exist and show the expected diff shape (TDD suite-wide rule added, persuasion prose removed); `tests/run-all.sh` + `bin/ytstack-check` green; record upstream SHA + tag in DECISIONS/KNOWLEDGE (vendor hold note updated).
- [ ] T02 -- Leak handling: `bin/ytstack-check` gets a FAIL rule scanning each wrapper's inlined vendor SKILL.md for `superpowers:<skill>` namespace references and relative `.md` links (`](writing-good-tests.md)` style) that do not resolve inside the wrapper; the three superpowers wrappers gain a short "Namespace note" postamble telling the agent that `superpowers:verification-before-completion` means `ytstack:verification-before-completion` and that relative links resolve under `vendor/superpowers/skills/<skill>/`; test in `tests/ytstack-check.test.sh` with a fixture wrapper.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: `git log -1 --format=%s vendor/superpowers` names 22f0b46; `bin/ytstack-check` 0 fails.

## Notes

- Upstream facts from `docs/research/2026-11-07-notes/vendor-upstream-drift.md`: all three wrapped files kept their paths and two-field frontmatter; systematic-debugging now contains a literal `superpowers:verification-before-completion`; TDD links `writing-good-tests.md` relatively.
