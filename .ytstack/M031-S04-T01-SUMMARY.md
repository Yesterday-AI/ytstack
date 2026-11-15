---
milestone: M031
slice: S04
task: T01
project: ytstack
closed: 2026-11-15T12:20:00Z
verification: passed
---

# M031-S04-T01 -- Summary

## Commits

- The commit that carries this file (`M031-S04-T01: add "Setting up the factory tools" to QUICKSTART`).

## Outcome

`QUICKSTART.md` has "Setting up the factory tools" after "Optional: PR watch" (which now points at it): how to find the installed plugin's `bin/`, which steps a new and an adopted or upgraded project needs, then five numbered setups with a check each. 1 risk routing (`REVIEW.md` with "Always a person", a lens and "Own reviewers", the `SPEC.md` link, `auto_merge`, `merge_by: risk`, merging the policy change yourself, `ytstack-risk check`, `spec lint`, and a dry `ytstack-risk route --pr` with how to get base and head and how to read the output). 2 PR watch (`enable`, `install-worker` plan and `--yes`, the asdf/mise shim refusal and its fix, restart, `register --all-open` without `--session` for a coordinator, `handover --from` on rotation, heartbeat check with `status`). 3 `RUNTIME.md` "Release" and "Signals" (`runtime check`, `sections`, `get`, `signals`, a `watch release` on the live commit). 4 upkeep on a schedule (recipe link, workflow dispatch as check). 5 standing instructions (`ytstack-check --standing`) and external plans (`ytstack-plans scan`, `reconcile`). A table explains the four SessionStart "Factory tools" lines with fix and silencer, and a paragraph explains the version notice.

## Deviations from plan

- None.

## Follow-ups

- None.

## Spec

- None: `QUICKSTART.md` belongs to no area.

## Verification

Command: `bin/ytstack-check; echo "check exit $?"; grep -c "$(printf '\342\200\224')" QUICKSTART.md` -- `check exit 2`, `OK (with 9 warning[s])`, 0 `[fail]` lines; em-dash count `0`.

Also run once: the `REVIEW.md` example in a throwaway fixture (`/tmp/m031-s04-fixture.sh`): `ytstack-risk check` exit 0, `review policy ok: 1 lens(es), 1 own reviewer(s)`; `ytstack-watch release` without a "Release" section exit 4. The dry route on this repository's PR #64 (`--pr 64 --base d39267c --head 6928c8c`): `route: person`, exit 10, with `round: none` and three `reason:` lines, the shape the guide describes.

Not checked: `install-worker --yes`, `register --all-open`, `handover` and the upkeep workflow were not run for this task (they change user state); their command lines are checked against the usage text in T03.
