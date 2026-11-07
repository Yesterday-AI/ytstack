#!/usr/bin/env bash
# Fixture: S01 fully summarized, S02 still planned.
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

## Tasks

- [x] T01 -- GET /export streams the user's rows as CSV
- [x] T02 -- Settings page gets a "Download CSV" button that calls /export
EOF
for t in T01 T02; do
cat > ".ytstack/M001-S01-$t-SUMMARY.md" <<EOF
---
milestone: M001
slice: S01
task: $t
project: csvexport
closed: 2026-11-03T12:00:00Z
verification: passed
---
# M001-S01-$t -- Summary

## Outcome

$t shipped as planned.

## Deviations from plan

$( [ "$t" = T02 ] && echo 'The button needed a loading state; added a small spinner component (src/ui/spinner.tsx) not in the plan.' || echo None. )

## Follow-ups

$( [ "$t" = T02 ] && echo '- The spinner should be reused by the weekly email settings in S02.' || echo '- None.' )
EOF
done
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
