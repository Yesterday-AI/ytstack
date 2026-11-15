---
milestone: M031
slice: S05
task: T03
project: ytstack
closed: 2026-11-15T10:50:00Z
verification: passed
---

# M031-S05-T03 -- Summary

## Commits

- The commit that carries this file (`M031-S05-T03: spec, README, eval case and decision for external plans`).

## Outcome

The area `checks-and-evals` names `bin/ytstack-plans` in its paths and behavior and `docs/ux/external-plans.md` as a source; `artifacts` names who writes the mapped milestone files, the one `PREFERENCES.md` line and the reconcile class. Both areas and `skills` (whose description still holds) carry `verified_at: e39198b`; the three files stay at 200 lines (three short lines were merged in each of the two edited areas). The README lists the script in the coordinator tools table and the `bin/` tree. `evals/external-plan/` is a new case: an initialized project without a milestone and a `plans/` board with 9 open and 2 done packages; five free graders (reconcile fired, the roadmap lists the EXP-03 slice, the first slice plan points into `plans/`, `PREFERENCES.md` records `mapped`, the plan row is unchanged). `DECISIONS.md` has the entry "A plan outside `.ytstack/` is detected by a script and mapped by the agent, after one question".

## Deviations from plan

- `skills.md` got only a new `verified_at`: `ytstack-spec drift` named it because `reconcile` and `adopt-brownfield` changed, and nothing it states changed.

## Follow-ups

- Run the eval case `external-plan` (not run: cost).

## Spec

- checks-and-evals, artifacts: updated in this commit
- skills: `verified_at` only

## Verification

See the slice report: `bash tests/run-all.sh` (27 suites), `bin/ytstack-spec lint` (`6 area file(s), 0 failure(s), 0 warning(s)`), `drift` (`no area to look at`), `python3 bin/ytstack-check` (exit 2, `OK (with 9 warning[s])`, no `[fail]`, the 9 warnings are the existing ones), `claude plugin validate .` (`Validation passed`), the Codex (16 tests) and Kimi tests (2 and 9) `OK`. The eval fixture was built once in `/tmp`: `scan` printed `dir=plans files=2 open=11 done=5 verdict=large answer=none`, exit 0, and the five grader patterns compiled.
