---
milestone: M025
slice: S03
task: T01
project: ytstack
closed: 2026-11-13T18:45:06Z
verification: passed
---

# M025-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M025-S03-T01: lenses in bin/ytstack-risk`).

## Outcome

`floor` and `route` printed `lenses:`, the lenses of the base's `REVIEW.md` whose `applies` match a changed path. `route` required for each of them a newest lens line under `## Review` that said `pass`, named a reviewer other than `--author` and was valid for the head. `fail` and `not run` were no pass. A lens line stayed valid after a commit outside its `applies` and lost its validity with a commit under them. A `reads` document that was gone at the head meant the lens could not run.

For a lens with `evidence: visual`, `route` read the `MANIFEST` in the directory the line names: at least one image line, every listed image present with the listed SHA-256, every line with `url`, `viewport` and `shows`. `bin/ytstack-risk manifest <dir>` wrote the hash and the name per image and kept what a line already said.

## Deviations from plan

- `bin/ytstack-risk manifest` was added. The verification side needs the choice between `sha256sum` and `shasum` anyway, and a reviewer that writes the two columns by hand in another form sends a correct review to a person.
- A manifest line has to state `url`, `viewport` (as `<w>x<h>`) and `shows`. The format lists the four parts of a line; a line the helper wrote and nobody filled in is not one.
- A manifest names files of its own directory only; a name with a `/` fails.
- `route` also prints `lenses:`.
- A reason about one image has the image's path as its subject, so that many broken images collapse into five lines and a count.

## Follow-ups

- The script cannot tell who took an image. "Images supplied by the author do not count" stays a rule for the reviewer and for the skill `visual-review`.
- The count in `(<n> images)` of a lens line is not compared with the manifest.
- A lens reviewer may be the same as the code reviewer. The format asks only for somebody other than the author.
- An evidence directory that is not committed lives in one working tree. `route` reads the working tree it is started in, so the reviewer's images have to be there: committed with the lane, or under an absolute `evidence_dir`.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-risk.test.sh` -- passed at the working tree on top of `5e494d0` in the local checkout (macOS, bash 3.2). Last line `151 passed, 0 failed`, exit 0. `bash tests/run-all.sh` ended with `ALL SUITES PASSED` at the same tree; `python3 bin/ytstack-check` exited 2 with no failure and 30 warnings: the 27 of the baseline and three spec drift warnings about this branch (checks-and-evals, dependencies, hooks-and-state).

Not checked: real screenshots from a browser, and a lens line written by a skill; the skills follow in M025-S03-T03 and T04. The Linux containers ran once for the whole branch, see the report.
