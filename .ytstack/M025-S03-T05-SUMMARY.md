---
milestone: M025
slice: S03
task: T05
project: ytstack
closed: 2026-11-14T09:00:00Z
verification: passed_with_caveats
---

# M025-S03-T05 -- Summary

Closes M025 and, in the same pass, M026-S02-T03 and M027-S02-T03 (their summaries point here).

## Commits

- The commit that carries this file (`M025-S03-T05: docs, area files, decisions, eval record; close M025, M026, M027`), on top of the merges of the worker branches `risk-gate-a`, `risk-gate-b1`, `risk-gate-b2`, `risk-gate-c`, `risk-gate-d`.

## Outcome

Five worker branches were merged into `risk-gate`; two merges had a conflict (the checkbox of M026-S01-T02, the skill list of `tests/skill-preambles.test.sh`), both resolved by keeping both sides. README, QUICKSTART, CHANGELOG, `docs/concept.md`, `docs/ux/coordinator-format.md` (a `review` lane changes no product file; a visual lens writes its evidence), `skills/using-ytstack/SKILL.md` and `evals/README.md` were brought in line. The area files `artifacts`, `skills`, `checks-and-evals` and `hooks-and-state` state what applies now; four DECISIONS entries and five KNOWLEDGE gotchas were added; STATE, ROADMAP and the milestone files were closed.

The two workers B2 and D hit a usage limit during their final verification and wrote no report; their commits were complete and their trees clean. The closing pass took their summaries as the report and ran their checks itself on the merged tree.

Exit criteria of M025:

| Criterion | Evidence |
|---|---|
| `bin/ytstack-runtime` starts and stops the product per worktree; `check` fails on a malformed section and a token | `tests/ytstack-runtime.test.sh`, 129 cases, live against a real server |
| `floor` returns `person` for rule documents, invariant sections, checks, uncovered paths; at least `normal` for never-low and size | `tests/ytstack-risk.test.sh`, 155 cases |
| `route` is `unattended` only under all its conditions; every other case `person` with reasons | the same suite; eval `risk-route` 5/5 |
| A visual lens passes only with a matching manifest; `not run` never counts | the same suite; eval `visual-review` 3/3 |
| `merge_by: risk` is the default; without declarations the behaviour of `human` | `tests/git-ctx.test.sh`, `tests/ytstack-finish-lane.test.sh` (a project without `auto_merge` routes `person`) |
| `code-review` records class and invariants; `finish-lane` merges alone only when unattended and gates hold | skill text, `tests/skill-preambles.test.sh`; eval `risk-route`. No real merge without a person yet |
| Suites on macOS and both Linux images, checker without failure, `vendor/` untouched | see Verification |

## Deviations from plan

- The closing pass is one task for three milestones; M026-S02-T03 and M027-S02-T03 have no plan or summary of their own.
- `docs/research/**` and `docs/ux/*.md` are covered by no area `paths`: under ytstack's own policy a change there goes to a person. ytstack declares no `auto_merge`, so every change goes to a person anyway.
- The `dependencies` area keeps a drift warning: `hooks/lib/git-ctx.sh` changed (`yt_prefs`, `yt_epoch`) without touching what that area describes (the gstack precheck). It is answered by a `verified_at` stamp once the branch has a commit that survives the merge.

## Follow-ups

- Under `merge_by: risk` only the hard gate of `finish-lane` keeps a session from calling `merge` after `route: person`; a `merge` that reads the route would close it (recorded under Known limits of `skills`).
- The first real lane through the route, the first real visual review with a browser, the first real release watch and incident.

## Spec

- artifacts, skills, checks-and-evals, hooks-and-state: updated in this commit (see Files of the plan).

## Verification

Command: `bash tests/run-all.sh` -- exit 0, `ALL SUITES PASSED`, 24 suites, at the merged tree in the local checkout (macOS, bash 3.2); the same at an export of commit `8500a88` in `ubuntu:26.04` and in plain alpine (BusyBox only, no coreutils). `python3 bin/ytstack-check` -- exit 2, no `[fail]`, 28 warnings (27 as on `main` plus the `dependencies` drift). `python3 -m unittest discover -s tests -p 'codex*_test.py'` -- OK. `claude plugin validate .` -- passed. `bash bin/ytstack-spec lint` -- 0 failures. Evals: the four new cases 4/4, $2.36 (`KNOWLEDGE.md`, "Eval runs").

Not checked: no session used any of this against a real project, host, browser or target. The 21 older eval cases were not run again.
