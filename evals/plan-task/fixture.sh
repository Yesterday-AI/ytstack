#!/usr/bin/env bash
# Fixture: M001 sliced, S01 has two unplanned tasks.
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
active_task: none
---
# State

**Status:** M001 / S01 sliced (2 tasks). Nothing planned yet.

## Next action

Plan T01.
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
size: S
---
# M001 -- Context

## Goal

Users can export their data as CSV.
EOF
cat > .ytstack/M001-ROADMAP.md <<'EOF'
---
milestone: M001
project: csvexport
size: S
created: 2026-11-02T09:00:00Z
status: planned
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
status: planned
task_count: 2
completed_tasks: 0
---
# M001-S01 -- Slice Plan

**Goal:** Export endpoint + settings button.

## Tasks

- [ ] T01 -- GET /export streams the user's rows as CSV
- [ ] T02 -- Settings page gets a "Download CSV" button that calls /export
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
