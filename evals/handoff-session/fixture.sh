#!/usr/bin/env bash
# Fixture: project csvexport, M001 in progress (T01 summarized, T02 planned).
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p .ytstack
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small web app; users export their data as CSV.
EOF
cat > .ytstack/STATE.md <<EOF
---
project: csvexport
last_updated: $NOW
current_milestone: M001
active_slice: S01
active_task: T02
---
# State

**Status:** M001 / S01 -- 1/2 tasks done. T02 in progress.

## Next action

Finish T02 (settings-page download button), then summarize it.
EOF
printf '# Decisions\n\n- 2026-11-01: CSV via a streaming endpoint, not a background job.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
cat > .ytstack/M001-ROADMAP.md <<'EOF'
---
milestone: M001
project: csvexport
size: S
created: 2026-11-02T09:00:00Z
status: in-progress
total_slices: 1
completed_slices: 0
---
# M001 Roadmap

**Goal:** Users can export their data as CSV.

## Slices

- [ ] S01 -- Export endpoint + settings button
EOF
cat > .ytstack/M001-S01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
project: csvexport
created: 2026-11-02T09:30:00Z
status: in-progress
task_count: 2
completed_tasks: 1
---
# M001-S01 -- Slice Plan

## Tasks

- [x] T01 -- GET /export streams the user's rows as CSV
- [ ] T02 -- Settings page gets a "Download CSV" button that calls /export
EOF
cat > .ytstack/M001-S01-T01-SUMMARY.md <<'EOF'
---
milestone: M001
slice: S01
task: T01
project: csvexport
closed: 2026-11-02T12:00:00Z
verification: passed
---
# M001-S01-T01 -- Summary

## Outcome

GET /export streams all rows of the signed-in user as CSV with a header line.
EOF
cat > .ytstack/M001-S01-T02-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
task: T02
project: csvexport
created: 2026-11-02T13:00:00Z
status: in-progress
---
# M001-S01-T02 -- Task Plan

**Summary:** Settings page gets a "Download CSV" button that calls /export

## Files

- Modify: `src/pages/settings.tsx`
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
