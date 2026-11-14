---
milestone: M022
slice: S01
task: T04
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S01-T04 -- Summary

## Commits

- The commit that carries this file (`M022-S01-T04: ytstack's own technical spec, checked by ytstack-check`).

## Outcome

ytstack got its own technical spec: `.ytstack/spec/SPEC.md` (52 lines) and the six area files `skills`, `artifacts`, `hooks-and-state`, `host-adapters`, `dependencies` and `checks-and-evals`, each `status: implemented` with `verified_at: f4f54ab`. `bin/ytstack-check` got `check_spec`, which runs `bin/ytstack-spec lint` and `drift` on the plugin root (format error: `[fail]`; drift line: `[warn]`; no spec: skipped), and `check_keeping_block`. `tests/ytstack-check.test.sh` got the block "technical spec".

The six area files were written by three dispatched agents against commit `f4f54ab`, one file set each, every statement read against the code. The lead read two of the files in full, spot-checked the other four against the code and then updated them for what this milestone itself changed: the spec steps in the loop (`skills.md`), the spec rows and the closure rules (`artifacts.md`), the spec tool and the two checks (`checks-and-evals.md`), the `SPEC.md` hint in the injection (`hooks-and-state.md`).

Parts of these files belong to M023, which is built in the same worktree: the section "The work contract" in `skills.md`, the lines about `Runs:`, `## Gates` and `## Review` in `artifacts.md`, and the `bin/ytstack-brief` paragraphs in `checks-and-evals.md`.

## Deviations from plan

- `bin/ytstack-check` also got `check_keeping_block`, which the task line does not name. The "Keeping this true" block is copied into two scaffolding skills, and a copy that drifts from `docs/ux/spec-format.md` would ship a different rule into every new project. The check fails on a difference.

## Follow-ups

- The six stamps name `f4f54ab`, the commit the branch started from, as the format asks for a branch that will be squash-merged. The descriptions include what M022 and M023 changed after that commit. Set `verified_at` to the merge commit once the branch is on `main`.
- What the area agents found wrong outside the spec and what was not fixed is listed in `M022-S01-T05-SUMMARY.md`. The area files carry the same points under "Known limits" and as `Unknown` lines.

## Spec

checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("`bin/ytstack-check`: static contracts")

`bin/ytstack-spec impact` saw the file as an uncommitted change when this summary was written. `SPEC.md` and the other five area files are new in this task as well.

## Verification

Command: `bash bin/ytstack-spec lint && /bin/bash tests/ytstack-check.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout: `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`; `45 passed, 0 failed`.

Not checked: four of the six area files were spot-checked by the lead, not read line by line. `bin/ytstack-spec drift` printed `no area to look at` for this repository because the area files are not committed yet; its first real answer comes after the commit. The statements marked `Unknown` in the area files (what the host does with exit 2 on TaskCreated, with stderr of an exit-0 hook, with the Codex context limit) were not reproduced in a live session.
