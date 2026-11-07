---
milestone: M017
slice: S02
task: T03
project: ytstack
closed: 2026-11-07T13:13:22Z
verification: passed
---

# M017-S02-T03 -- Summary

## Commits

- `4a79393` -- M017-S02-T03: plan vendor/gstack removal + checker + docs
- `02b8562` -- M017-S02-T03: remove vendor/gstack subtree; ytstack-check enforces the installed-gstack wrapper contract; docs/NOTICE/README/QUICKSTART/concept/methodology/inventory updated

## Outcome

`vendor/gstack/` is gone (641 files, 231k lines removed; history keeps the `aeea57f` squash). `bin/ytstack-check` gained `check_gstack_wrappers`: each of the three planning wrappers must call `yt_gstack_ctx`, carry `GSTACK_INSTALL_CMD`, say "Invoke the Skill tool with `<name>`", have a `## HARD-GATE`, and must not reference `vendor/gstack`; the cross-ref and sibling checks tolerate the absent vendor root (warnings 109 -> 19). Docs now describe the model consistently: AGENTS.md (vendored rule narrowed to superpowers + new "gstack is an installed dependency, never vendored or inlined" rule), NOTICE (required install, not redistributed), README (prerequisites with the pinned install one-liner; "one namespace, upstreams consumed the way they want to be"), QUICKSTART (Prerequisites section), `docs/concept.md` (§2.1 + §3.3 second wrapper shape), `docs/methodology.md`, `.ytstack/VENDOR-INVENTORY.md` (gstack table marked as 2026-04-24 snapshot, pointer to the drift notes). The ytstack-check suite (19 cases) covers the contract on a copied tree.

## Deviations from plan

The copied-tree test harness now symlinks superpowers skill dirs individually and only links `vendor/gstack` when it exists; the "vendor/gstack reference flagged" case counts the new rule's message, because `check_cross_refs` adds a second fail for the missing file.

## Follow-ups

- Historical mentions of `vendor/gstack` remain in `.ytstack/` records (DECISIONS, REVIEW-NOTES, KNOWLEDGE, earlier summaries) and `docs/research/`; intentional.
- README repo-layout line still lists `vendor/` as "read-only subtrees (superpowers, gstack)" -- fix in T05 with the release pass.

## Verification

Command: `test ! -d vendor/gstack && /bin/bash tests/ytstack-check.test.sh && bin/ytstack-check && bash tests/run-all.sh` -- passed (19/19; checker 0 fails, 19 warnings; ALL SUITES PASSED).
