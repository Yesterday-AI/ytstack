---
milestone: M025
slice: S03
task: T03
project: ytstack
closed: 2026-11-13T19:24:08Z
verification: passed
---

# M025-S03-T03 -- Summary

## Commits

- The commit that carries this file (`M025-S03-T03: the skill visual-review`).

## Outcome

`skills/visual-review/SKILL.md` was written as a native procedure skill with nine steps. Its preamble printed where `bin/ytstack-runtime` and `bin/ytstack-risk` are, `RUN_SECTION`, `RUN_NEEDS`, `EVIDENCE_DIR`, `EVIDENCE_ROOT` (the main checkout of the repository, also from a linked worktree), `HEAD` and the lenses of `REVIEW.md` with `evidence: visual`.

The procedure tells the reviewer to establish commit, lens, lane and its own name, to read the documents of the lens at the commit, and to stop with the verdict `not run` when it is the author, a document is missing, `RUNTIME.md` has no "Run" section, the session has no browser tool that renders a page and returns a screenshot, or the product does not come up. It adds a worktree of its own at the reviewed commit, starts the product there with `bin/ytstack-runtime up` and compares `COMMIT:`. It lists views, states, widths and themes before the browser opens, takes its own screenshots, opens each image and judges it against sentences of the documents. It stores images and `MANIFEST` under the evidence root, stops the product, removes its worktree, and writes the lens line. A dispatched reviewer returns the line in its report; a session a person asked appends it to the plan of the lane. The skill edits no product file and invokes no other ytstack skill. Its two anti-patterns are "The diff looks fine, so the UI is fine" and "The author attached screenshots".

`tests/skill-preambles.test.sh` lists the skill and pins its preamble with nine assertions of its own. `evals/visual-review/` was written: a visual lens, design guidelines the stylesheet visibly breaks, and a "Run" section whose start command names a server that is not in the repository.

## Deviations from plan

- Two more ways to `not run` than the three of the brief: the reviewer is the author (`by: self`), and a `reads` document is missing at the commit. Both are rules of every lens in the format document.
- A changed view that cannot be reached makes the verdict `not run`, not `pass`: a partial look is no pass. What was seen is stored all the same.
- The skill asks no question. Without a visual lens and without a document named by the person the verdict is `not run`.
- `git worktree remove --force` is allowed for the worktree the run added, after a look at what changed in it: a product writes build output while it runs.
- A `not run` of a dispatched reviewer is `Status: blocked` with the reason under `Blockers:`.

## Follow-ups

- Nothing checks that a screenshot was taken by the reviewer and not copied from the author. The script checks hashes, lines and the reviewer's name; the rest is this skill's hard gate.
- The skill names kinds of browser tools and binds to none. Which tool a host offers, and whether a dispatched reviewer inherits it, is not known before a real run.
- The viewports 390x844 and 1440x900 are a default of the skill, not of the format.

## Spec

- skills: area file updated by the coordinator in the closing task
- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- the suite passed at the working tree on top of `0a8c0de` in the local checkout (macOS, bash 3.2), last line `497 passed, 0 failed`, exit 0; the checker exited 2 with no `[fail]` line and 32 warnings, none about the new skill. `python3 -m unittest discover -s tests -p 'codex*_test.py'` ran 13 tests, OK.

The fixture of `evals/visual-review/` was built once in a temporary directory: `bin/ytstack-runtime check` printed `runtime ok: Run`, `bin/ytstack-risk check` and `bin/ytstack-spec lint` passed, `floor` named the lens `ui` for the last commit, the preamble of the skill printed `RUN_SECTION: yes` and the lens line, and `bin/ytstack-runtime up` in a worktree at the commit exited 1 with "No such file or directory".

Not checked: the skill was never run by an agent, and no real product was started, operated in a browser and captured through it. The eval case was not run (the coordinator runs the evals). The Linux containers ran once for the whole branch, see the report.
