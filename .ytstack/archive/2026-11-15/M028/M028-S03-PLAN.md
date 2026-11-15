---
milestone: M028
slice: S03
project: ytstack
created: 2026-11-14T09:00:00Z
status: done
task_count: 2
completed_tasks: 2
---

# M028-S03 -- Slice Plan

**Goal:** The six skills are synced to the newest gstack tag and the whole tree verifies.

## Tasks

- [x] T01 -- `bin/ytstack-gstack-diff` v1.96.0.0 -> v1.99.3.0 (1,599 diff lines across ETHOS.md, review/ and the six skill dirs); method changes folded in, runtime-only changes skipped; baselines moved to v1.99.3.0 (commit 1d3c63c53); outside voice via subagent so no skill names a host.
- [x] T02 -- Verification: `bash tests/run-all.sh` (13 suites), `bin/ytstack-check` (no failures), Codex tests (13 OK), `claude plugin validate .`, `bin/ytstack-gstack-diff --stat` exit 0.

## Outcome

Commit of the sync carries `M028-S03:`. Folded in: VERDICT line for subagent second opinions and the adversarial review, plan-binding fix, plain-language PR titles and CHANGELOG leads, PR body opening sentences, stricter docs-audit result format. Skipped: autoplan references, DRIVER and receipts, Capy, review-army issue filing, the plain-title linter, the dropped `<type>:` prefix (ytstack keeps conventional prefixes).
