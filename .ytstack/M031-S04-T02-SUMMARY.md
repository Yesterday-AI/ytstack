---
milestone: M031
slice: S04
task: T02
project: ytstack
closed: 2026-11-15T12:40:00Z
verification: passed
---

# M031-S04-T02 -- Summary

## Commits

- The commit that carries this file (`M031-S04-T02: add "Upgrading from 0.x" checklist to QUICKSTART`).

## Outcome

`QUICKSTART.md` has "Upgrading from 0.x" after the setup section, and the gstack paragraph under Prerequisites points at it. Four steps after every update (`claude plugin marketplace update yesterday-public-plugins && claude plugin update ytstack`, restart running sessions, nothing for the PR watch worker, one `ytstack-upkeep` run), then ten blocks by the version a project comes from, newest first, each from a CHANGELOG entry or upgrade note: 0.10.x (M031: `handover`, review records on the host and `route --pr`, `ytstack-plans scan`), 0.9.x (standing directory), 0.9.0/0.9.1 (bare session id), 0.9.0 or older (restart, `--all-open`), 0.8.x (own reviewers), 0.8.0/0.8.1 with a shim (`install-worker --yes` again), 0.7.x (PR watch, `migrate --from`), 0.6 or older (spec, `merge_by: risk` default, Spec impact), 0.5 or older (gstack removal), 0.3 or older (Ceremony block, sentinel files).

## Deviations from plan

- The 0.10.x block names "the release after 0.10.0" instead of a version number: the coordinating session picks the number at release.

## Follow-ups

- At release, replace "the release after 0.10.0" with the version.

## Spec

- None: `QUICKSTART.md` belongs to no area.

## Verification

Command: `bin/ytstack-check; echo "check exit $?"; grep -c '—' QUICKSTART.md` -- `check exit 2`, `OK (with 9 warning[s])`, 0 `[fail]` lines; em-dash count `0`. `claude plugin update --help` and `claude plugin marketplace --help` list `update`.

Not checked: an actual plugin update; command and link existence is checked in T03.
