#!/usr/bin/env bash
# Fixture: T01 planned and implemented (one task-ref commit), not yet summarized.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p .ytstack src tests
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
active_task: T01
---
# State

**Status:** M001 / S01 / T01 planned -- ready to execute.

## Next action

Execute T01, then summarize it.
EOF
printf '# Decisions\n' > .ytstack/DECISIONS.md
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
completed_tasks: 0
---
# M001-S01 -- Slice Plan

**Goal:** Export endpoint + settings button.

## Tasks

- [ ] T01 -- GET /export streams the user's rows as CSV
- [ ] T02 -- Settings page gets a "Download CSV" button that calls /export
EOF
cat > .ytstack/M001-S01-T01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
task: T01
project: csvexport
created: 2026-11-02T10:00:00Z
status: in-progress
---
# M001-S01-T01 -- Task Plan

**Summary:** GET /export streams the user's rows as CSV

## Files

- Create: `src/export.ts`
- Create: `tests/export.test.ts`

## What this does

GET /export selects all rows of the signed-in user and streams them as CSV with a header line.

## Verification

```bash
bash tests/run.sh
```
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
printf 'export function toCsv(rows: string[][]): string { return rows.map(r => r.join(",")).join("\\n"); }\n' > src/export.ts
printf '#!/usr/bin/env bash\necho "1 test passed"\n' > tests/run.sh
git add -A && git commit -qm "M001-S01-T01: add CSV export endpoint"
