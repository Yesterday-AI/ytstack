---
milestone: M031
slice: S04
task: T03
project: ytstack
closed: 2026-11-15T13:00:00Z
verification: passed
---

# M031-S04-T03 -- Summary

## Commits

- The commit that carries this file (`M031-S04-T03: point README at the setup guide and state what ran on a real host`).

## Outcome

README's Quickstart paragraph links "Setting up the factory tools" and "Upgrading from 0.x"; the "Coordinating many lanes" table is followed by a link to the setup guide. The sentence "Nothing in this group has run against a real host" became what the sources show: `ytstack-review-escapes` read 30 merged pull requests of one repository read-only (M030-S01 notes); no unattended merge and no `ytstack-watch release` against a real target yet; the field case of issue #54 (2026-11-14, two production releases with post-checks by hand) as the steps a "Release" section is meant to take over. The QUICKSTART gotcha says the same in one line.

## Deviations from plan

- The PR watch's field use (CHANGELOG 0.9.1) is not named in the README sentence: the PR watch is not part of the "Coordinating many lanes" table that sentence is about.
- The README Status paragraph ("Coordinator mode, the risk route and the release watch have run only against a stand-in") is left as it is: still true for those three.

## Follow-ups

- None.

## Spec

- None: `README.md` and `QUICKSTART.md` belong to no area.

## Verification

Command: `bash /tmp/m031-s04-doccheck.sh QUICKSTART.md README.md && bin/ytstack-check` -- `doccheck: 3 problem(s)`, all three false positives, none in the new text: `REVIEW.md` is the example link line inside backticks in step 1 ("`[Review policy](REVIEW.md)`", relative to `.ytstack/spec/SPEC.md`), `docs/adr/` and `docs/plans/` are older references to a consumer project's directories in "Adopting ytstack". Anchors `#setting-up-the-factory-tools` and `#upgrading-from-0x` resolve; every `bin/ytstack-*` named exists and is executable; every tool and subcommand pair (`ytstack-risk check|floor|route`, `ytstack-pr-watch enable|disable|install-worker|register|handover|migrate|status`, `ytstack-runtime check|sections|get|signals|up|down`, `ytstack-watch release`, `ytstack-plans scan`, `ytstack-spec lint`, `ytstack-check --standing`) is in the tool's usage text. `ytstack-check`: see the slice report.

Not checked: the GitHub rendering of the anchors (computed with GitHub's rule, not looked at on github.com).
