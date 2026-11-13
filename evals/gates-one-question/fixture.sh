#!/usr/bin/env bash
# Fixture: S01 closed by work (both tasks summarized), S02 still planned, and two
# open gates in the S01 slice plan. G01 needs a person (the product owner). G02
# can no longer be met: its lapse condition (the switch to the new endpoint) is
# recorded with a date in the slice plan's Notes and in the T02 summary.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack docs
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport
EOF
cat > .ytstack/STATE.md <<EOF
---
project: csvexport
last_updated: $NOW
current_milestone: M001
active_slice: S01
active_task: none
---
# State

**Status:** M001 / S01 -- 2/2 tasks done. Slice complete; reassess before S02.

## Next action

Reassess the roadmap, then slice S02.
EOF
printf '# Decisions\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
cat > .ytstack/M001-CONTEXT.md <<'EOF'
---
milestone: M001
project: csvexport
created: 2026-11-02T09:00:00Z
size: M
---
# M001 -- Context

## Goal

Users can export their data as CSV and schedule a weekly export email.
EOF
cat > .ytstack/M001-ROADMAP.md <<'EOF'
---
milestone: M001
project: csvexport
size: M
created: 2026-11-02T09:00:00Z
status: in-progress
total_slices: 2
completed_slices: 1
---
# M001 Roadmap

**Goal:** Users can export their data as CSV and schedule a weekly export email.

## Slices

- [x] S01 -- Export endpoint + settings button
- [ ] S02 -- Weekly export email (scheduler + template)
EOF
cat > .ytstack/M001-S01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
project: csvexport
created: 2026-11-02T09:30:00Z
status: done
task_count: 2
completed_tasks: 2
---
# M001-S01 -- Slice Plan

**Goal:** Export endpoint + settings button.

## Tasks

- [x] T01 -- GET /export streams the user's rows as CSV
- [x] T02 -- Settings page "Download CSV" button switches from /legacy/download to the new /export endpoint

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Gates

- [ ] G01 -- The export format is accepted after a look at a real sample | decides: the product owner | how: opens the sample file linked in the T02 summary (`docs/export-sample.csv`) and says yes or no | lapses: when S02 ships a different format
- [ ] G02 -- p95 latency of GET /export is under 200 ms, measured before the settings page switches to the new endpoint | decides: the measurement | how: load test against /export before the switch | lapses: when the switch has been made

## Notes

- 2026-11-03: the settings page was switched from /legacy/download to the new /export endpoint (T02). /legacy/download is no longer called.
EOF
cat > .ytstack/M001-S01-T01-SUMMARY.md <<'EOF'
---
milestone: M001
slice: S01
task: T01
project: csvexport
closed: 2026-11-03T10:00:00Z
verification: passed
---
# M001-S01-T01 -- Summary

## Outcome

GET /export streams all rows of the signed-in user as CSV with a header line; an account without rows gets the header only.

## Deviations from plan

None.

## Follow-ups

- None.
EOF
cat > .ytstack/M001-S01-T02-SUMMARY.md <<'EOF'
---
milestone: M001
slice: S01
task: T02
project: csvexport
closed: 2026-11-03T12:00:00Z
verification: passed
---
# M001-S01-T02 -- Summary

## Outcome

The "Download CSV" button on the settings page calls the new /export endpoint. The switch away from /legacy/download was made on 2026-11-03. A sample of the file the button delivers is at `docs/export-sample.csv`.

## Deviations from plan

The button needed a loading state; added a small spinner component (src/ui/spinner.tsx) not in the plan. No load test ran before the switch.

## Follow-ups

- The spinner should be reused by the weekly email settings in S02.
EOF
printf 'id,name,email,created_at\n1,Ada Lovelace,ada@example.test,2026-10-01\n2,Grace Hopper,grace@example.test,2026-10-14\n' > docs/export-sample.csv
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
