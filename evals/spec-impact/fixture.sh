#!/usr/bin/env bash
# Fixture: M001 sliced, T01 unplanned, and a technical spec whose area
# `export` describes the code the task will change (new requirement case).
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p .ytstack/spec src tests
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

**Status:** M001 / S01 sliced (1 task). Nothing planned yet.

## Next action

Plan T01.
EOF
printf '# Decisions\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: step\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
cat > .ytstack/M001-CONTEXT.md <<'EOF'
---
milestone: M001
project: csvexport
created: 2026-11-02T09:00:00Z
size: S
---
# M001 -- Context

## Goal

Users can export only what changed since a date.
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

**Goal:** Users can export only what changed since a date.

## Slices

- [ ] S01 -- Incremental export
EOF
cat > .ytstack/M001-S01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
project: csvexport
created: 2026-11-02T09:30:00Z
status: planned
task_count: 1
completed_tasks: 0
---
# M001-S01 -- Slice Plan

**Goal:** Incremental export.

## Tasks

- [ ] T01 -- GET /export accepts `since` and exports only rows changed on or after that date
EOF
printf 'export function toCsv(rows: string[][]): string { return rows.map(r => r.join(",")).join("\\n"); }\n' > src/export.ts
printf 'export function listUsers(): string[] { return []; }\n' > src/users.ts
printf '// tests for the export\n' > tests/export.test.ts
printf '#!/usr/bin/env bash\necho "1 test passed"\n' > tests/run.sh
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
V=$(git rev-parse --short HEAD)
cat > .ytstack/spec/SPEC.md <<'EOF'
---
project: csvexport
updated: 2026-11-03
---

# csvexport -- technical spec

## What this is

A small web app. Signed-in users export their data as CSV.

## Areas

| Area | Covers | Status | File |
|---|---|---|---|
| export | The CSV export endpoint | implemented | [export.md](export.md) |
| users | Accounts and sign-in | implemented | [users.md](users.md) |

## Build and test

`bash tests/run.sh`

## Keeping this true

- A task plan names its **Spec impact**: the area and section it changes, or `none`.
- A task that changes behaviour updates the area file, or the source the area file names, in the same commits. A task that restores the described behaviour, a refactoring and a trivial edit close with `none`.
EOF
cat > .ytstack/spec/export.md <<EOF
---
area: export
status: implemented
paths:
  - src/export.ts
  - tests/export.test.ts
verified_at: $V
---

# export

## Purpose

The CSV export of a signed-in user's rows.

## Behavior

- GET /export returns all rows of the signed-in user as CSV, with a header line.
- The endpoint takes no parameters.
- An account without rows gets the header line only.

## Where implemented

- \`src/export.ts\` -- \`toCsv\`. Tests: \`tests/export.test.ts\`.

## How to verify

\`bash tests/run.sh\` prints "1 test passed".

## Decisions that apply now

None.
EOF
cat > .ytstack/spec/users.md <<EOF
---
area: users
status: implemented
paths:
  - src/users.ts
verified_at: $V
---

# users

## Purpose

Accounts and sign-in.

## Where implemented

- \`src/users.ts\`

## How to verify

\`bash tests/run.sh\`

## Decisions that apply now

None.
EOF
git add -A && git commit -qm "docs: technical spec"
