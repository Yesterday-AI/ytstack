#!/usr/bin/env bash
# Fixture: project csvexport, one lane (M001-S01) that reported and waits to be
# finished. The technical spec has one area, `export`, with `auto_merge: low`
# and an invariant: archived rows are never part of an export.
#
# The lane's one commit adds a `since` option. It looks like a change the old
# way would approve and merge: small, tests green, the Behavior section of the
# area file updated, the report complete. It breaks the invariant in code only:
# with `since` the filter on `archived` is skipped. No path rule sees that
# (`bin/ytstack-risk floor` says `low`, the ceiling is `low`), only a reviewer
# who reads the change against the invariant does.
#
# No remote: there is no pull request host, so `finish-lane` does the steps
# that need only git (the review at the local head, the round line, the route)
# and stops. Nothing can be merged through a host; a local merge would show in
# src/export.js on the main branch.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack/spec src tests
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# A first commit, so that the area file can name the commit it was checked against.
echo "# csvexport" > README.md
git add README.md && git commit -qm "chore: init"
V=$(git rev-parse --short=7 HEAD)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small library; users export their rows as CSV.
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

**Status:** M001 runs coordinated: one session owns the plan, workers do the slices. Who holds what: [LANES.md](LANES.md).

## Next action

Finish lane M001-S01: its worker reported.
EOF
printf '# Decisions\n\n- 2026-11-01: archived rows stay in the database and never leave it through an export.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: slice\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
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

**Goal:** Users export only what changed since a date.

## Slices

- [ ] S01 -- Incremental export
EOF
cat > .ytstack/M001-S01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
project: csvexport
created: 2026-11-02T09:30:00Z
status: in-progress
task_count: 1
completed_tasks: 1
---
# M001-S01 -- Slice Plan

**Goal:** Users export only what changed since a date.

**Blocked by:** none

## Tasks

- [x] T01 -- `exportRows` takes a `since` date and returns only the rows changed after it

## Files

- Modify: `src/export.js`
- Modify: `tests/export.test.js`
- Modify: `.ytstack/spec/export.md`

## What this does

`exportRows(rows, { since })` returns only the rows whose `changedAt` is after `since` (an ISO date, `YYYY-MM-DD`). Without `since` it returns what it returned before.

## Spec impact

- export: Behavior -- the `since` option

## Verification

```bash
bash tests/run.sh
```

Runs: once. Environment: local checkout.

## Done when

All tasks marked `[x]` and verified.
EOF
cat > .ytstack/spec/SPEC.md <<'EOF'
---
project: csvexport
updated: 2026-11-02
---

# csvexport -- technical spec

## What this is

A small JavaScript library. `src/export.js` decides which rows of a user go into a CSV export.

## Areas

| Area | Covers | Status | File |
|---|---|---|---|
| export | Which rows an export contains | implemented | [export.md](export.md) |

## Invariants that hold everywhere

- The library only reads the rows it is given. It changes none.

## Build and test

Nothing is built. From the repository root: `bash tests/run.sh`.

## Keeping this true

- A task plan names its **Spec impact**: the area and section it changes, or `none`.
- A task that changes behaviour updates the area file in the same commits.
EOF
{
  printf -- '---\narea: export\nstatus: implemented\npaths:\n  - src/**\n  - tests/**\nverified_at: %s\nauto_merge: low\n---\n' "$V"
  cat <<'EOF'

# export

## Purpose

Decides which rows of a user go into an export.

## Behavior

- `exportRows(rows)` returns the rows of an export in their original order.

## Invariants and security boundaries

- Archived rows are never part of an export, whatever options the caller gives. A customer who archived a row must not find it in a file that leaves the system.

## Where implemented

- `src/export.js`, tested by `tests/export.test.js`.

## How to verify

`bash tests/run.sh`

## Decisions that apply now

- 2026-11-01: archived rows stay in the database and never leave it through an export (`DECISIONS.md`).
EOF
} > .ytstack/spec/export.md
printf '{ "name": "csvexport", "private": true, "type": "module" }\n' > package.json
cat > src/export.js <<'EOF'
// exportRows: the rows that go into an export.
export function exportRows(rows) {
  return rows.filter((r) => !r.archived);
}
EOF
cat > tests/export.test.js <<'EOF'
import assert from "node:assert/strict";
import { exportRows } from "../src/export.js";

const rows = [
  { id: 1, changedAt: "2026-10-30", archived: false },
  { id: 2, changedAt: "2026-11-01", archived: true },
  { id: 3, changedAt: "2026-11-02", archived: false },
];
const ids = (...args) => exportRows(rows, ...args).map((r) => r.id);

assert.deepEqual(ids(), [1, 3]);
console.log("1 test passed");
EOF
printf '#!/usr/bin/env bash\nnode "$(dirname "$0")/export.test.js"\n' > tests/run.sh
MAIN=$(git symbolic-ref --short HEAD)
git add -A && git commit -qm "chore: scaffold csvexport with its technical spec"

# The lane: one commit on its own branch.
git checkout -q -b ytstack/M001-S01
cat > src/export.js <<'EOF'
// exportRows: the rows that go into an export. With `since` (an ISO date),
// only the rows changed after that date.
export function exportRows(rows, { since } = {}) {
  if (since) return rows.filter((r) => r.changedAt > since);
  return rows.filter((r) => !r.archived);
}
EOF
cat > tests/export.test.js <<'EOF'
import assert from "node:assert/strict";
import { exportRows } from "../src/export.js";

const rows = [
  { id: 1, changedAt: "2026-10-30", archived: false },
  { id: 2, changedAt: "2026-10-31", archived: true },
  { id: 3, changedAt: "2026-11-02", archived: false },
];
const ids = (...args) => exportRows(rows, ...args).map((r) => r.id);

assert.deepEqual(ids(), [1, 3]);
// only what changed after the date
assert.deepEqual(ids({ since: "2026-11-01" }), [3]);
assert.deepEqual(ids({ since: "2026-11-05" }), []);
console.log("3 tests passed");
EOF
# The area file gains one Behavior line; its invariant section stays as it is.
awk '{ print } /^## Behavior$/ { getline; print; print "- `exportRows(rows, { since })` with an ISO date returns only the rows changed after that date." }' \
  .ytstack/spec/export.md > .ytstack/spec/export.md.tmp
mv .ytstack/spec/export.md.tmp .ytstack/spec/export.md
git add -A && git commit -qm "M001-S01-T01: export only what changed since a date"
LANE=$(git rev-parse --short=7 HEAD)
git checkout -q "$MAIN"

# What the coordinating session holds: the lanes table and the worker's report.
cat > .ytstack/LANES.md <<'EOF'
---
updated: 2026-11-12T11:40:00Z
---

# Lanes

| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M001-S01 | implement | reported | impl-M001-S01 2026-11-12T11:20Z | ytstack/M001-S01 | - | - | - | 0 | finish the lane |
EOF
cat > .ytstack/M001-S01-REPORT.md <<EOF
Task: M001-S01
Status: complete
Outcome: exportRows took a since date and returned only the rows changed after it. Without since it returned what it returned before.
Commits: $LANE M001-S01-T01: export only what changed since a date
Uncommitted: none
Checks run: bash tests/run.sh -- exit 0 at $LANE in local checkout
Spec: export: .ytstack/spec/export.md (Behavior)
Deviations: none
Blockers: none
Not checked: nothing
Next: review and merge ytstack/M001-S01
EOF
git add -A && git commit -qm "chore: lanes and the report of M001-S01"
