---
milestone: M025
slice: S03
task: T02
project: ytstack
closed: 2026-11-13T19:19:06Z
verification: passed
---

# M025-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M025-S03-T02: bin/ytstack-brief renders the brief of a lens`).

## Outcome

`bin/ytstack-brief render --task|--slice <ref> --kind review --lens <name> --head <sha>` printed a review brief with a section "Lens" after "Kind": the lens line of `REVIEW.md`, its `reads` documents as a list, the three rules of every lens, and by the `evidence` of the lens either the visual rules or the sentence that the lens asks for none. For a visual lens the brief named the skill to load (`ytstack:visual-review`, and the path of its file for a host without a skill tool), the evidence directory `<evidence_dir>/<ref>/<short sha>/<lens>` and the root that path starts at: the main checkout of the repository, also when the brief is rendered in a linked worktree. A lens with a `skill` got the sentence to load it. "Kind" said that this is a lens review with the verdict `pass`, `fail` or `not run`, and asked for no class.

The command ended with exit 1 and no brief for a lens the policy does not define, for a `reads` document that is not at the reviewed commit, for a head that is no commit of the repository and for a project without `REVIEW.md`. `--lens` without `--kind review` and a name that is no lowercase slug ended with exit 64.

`bin/ytstack-brief check` read `Lens:` and `Evidence:` as labels: a report that carries one has to carry both, `Lens:` is `<name> -- pass`, `fail` or `not run`, `Evidence:` is `none` or `<directory> (<n> images)`.

## Deviations from plan

- The lens and its documents are read from the reviewed commit (`git show <head>:.ytstack/spec/REVIEW.md`), not from the working tree. The reviewer works at that commit, and `bin/ytstack-risk route` checks the documents there too. A document that exists only in the working tree of the session that renders the brief is refused.
- The lens report does not carry the four labels of the class. A lens answers one question and states no class; the round line has no place for a second one.
- The fixed sentences of a lens live in `brief-template.md` under the names `lens-kind`, `lens-intro`, `lens-reads`, `lens-rules`, `lens-visual`, `lens-none`, `lens-skill` and `lens-report`. A template without one of them that the lens needs ends the command without a brief.
- A value inserted into a sentence is quoted in the substitution: bash 5.2 and later read a bare `&` in a replacement as the matched text.

## Follow-ups

- `lens_def` in `bin/ytstack-brief` reads a lens line the way `review_parse` in `bin/ytstack-risk` does. Two readers of one line format: a third caller should move the reader into the library.
- The count in `Evidence: <directory> (<n> images)` is not compared with the directory.
- A `.ytstack` in user scope is not in git: `--lens` finds no policy there and refuses, as `bin/ytstack-risk` answers `person` there.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-brief.test.sh` -- passed at the working tree on top of `71e44f3` in the local checkout (macOS, bash 3.2). Last line `189 passed, 0 failed`, exit 0. `python3 bin/ytstack-check` exited 2 with no failure and 32 warnings.

Not checked: a reviewer that received a lens brief and reported with the two labels. The quoted substitution was tried by hand on bash 3.2.57 and bash 5.3.9 with a value that holds `&`; the suite has no such value. The Linux containers ran once for the whole branch, see the report.
