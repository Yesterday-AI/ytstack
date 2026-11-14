---
milestone: M025
slice: S02
task: T02
project: ytstack
closed: 2026-11-13T18:30:04Z
verification: passed
---

# M025-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M025-S02-T02: bin/ytstack-risk floor and check`).
- `M025-S02-T02: a verified_at stamp alone does not route to a person`.

## Outcome

`bin/ytstack-risk floor --base <sha> --head <sha>` printed `floor:`, one `reason:` line per path and rule, `areas:` and `ceiling:`. It returned `person` for a rule document, an instruction file at any depth, a workflow or the GitLab pipeline, the frontmatter and the two rule sections of an area file, the invariants section of `SPEC.md`, a spec file that was added or deleted, a path no area covers and a path on the project's list. It returned `normal` for each group of the built-in list `NEVER_LOW`, the project's list and a change over the size limit. Process records were exempt from coverage and from the size count.

The policy was read at the base commit. `bin/ytstack-risk check` validated the `REVIEW.md` of the working tree, and `bin/ytstack-spec lint` counted each of its lines as a failure. `tests/ytstack-risk.test.sh` pins one case per rule on fixture repositories.

## Deviations from plan

- The policy is read at the base commit, not from the working tree. The format did not say where. A working tree can hold an edit nobody committed, and a script started in the coordinator's checkout would read another policy than one started in the lane's worktree.
- Globs are matched by git (`:(glob)` pathspecs over the diff), the semantics of `lint` and `drift`. `bin/ytstack-spec areas` was not reused: its shell pattern lets `*` cross directories, which would count `src/*.ts` as covering `src/deep/x.ts`.
- Process records do not count towards the size limit. A slice lane with five tasks carries about a dozen record files, which would leave eight files for the change itself.
- An area file counts as covered by its own area and touches it; `SPEC.md` needs no area. Without that, the ordinary edit of "Behavior" the format asks for would be a path no area covers.
- A spec file the change adds or deletes is `person`, also `SPEC.md`.
- `M###-ROADMAP.md` is a process record, beside the context, plan and summary files.
- `check` also fails on a lens name that is not a lowercase slug and on a lens field outside the five.
- The frontmatter reader is a copy of the one in `bin/ytstack-spec`; a comment in each script names the other.

## Follow-ups

- Resolved in a second commit of this task (`M025-S02-T02: a verified_at stamp alone does not route to a person`): as first built, a `verified_at` stamp was a frontmatter change and routed to a person, although the stamp is the sanctioned answer to a drift report. `floor` now compares the frontmatter without the `verified_at` line; `area`, `status`, `paths`, `sources` and `auto_merge` stay `person`.
- An instruction file that is a symlink to a file with another name (`CLAUDE.md -> docs/rules.md`) is not followed: a change to the target alone is not caught by the instruction-file rule. The project can list the target under "Always a person".
- `bin/ytstack-spec areas` still matches wider than git does. It is a hint for `plan-task`, not a gate.
- The two frontmatter readers could move into `hooks/lib/git-ctx.sh`.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-risk.test.sh && /bin/bash tests/ytstack-spec.test.sh` -- passed at the working tree on top of `f1fbe9f` in the local checkout (macOS, bash 3.2). Last lines `91 passed, 0 failed` and `69 passed, 0 failed`, exit 0. `bash tests/run-all.sh` ended with `ALL SUITES PASSED` at the same tree; `python3 bin/ytstack-check` exited 2 with 27 warnings and no failure.

Not checked: a real project's diff. The Linux containers ran once for the whole branch, see the report.
