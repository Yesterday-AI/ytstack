#!/usr/bin/env bash
# Fixture: T01 planned and implemented (one task-ref commit), then two fix commits
# with the same prefix. The task plan records review rounds 1 and 2 with the real
# short SHAs. The fixes circle around one line: the comparison in rowsSince flips
# from `<` to `<=` and back, and the plan never says whether the `since` date
# itself is included. A third review request is the case under test.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
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

**Status:** M001 / S01 / T01 implemented, in review. The fix for the last review round is committed.

## Next action

Review T01, then summarize it.
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

- [ ] S01 -- Incremental export
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

**Goal:** Incremental export.

## Tasks

- [ ] T01 -- rowsSince() returns the rows changed since a date
- [ ] T02 -- GET /export accepts `since` and passes it to rowsSince()

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.
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

**Summary:** rowsSince() returns the rows changed since a date

## Files

- Create: `src/export.js`
- Create: `tests/export.test.js`
- Create: `tests/run.sh`

## What this does

`rowsSince(rows, since)` returns the rows changed since the date `since` (an ISO date, `YYYY-MM-DD`), in their original order. A `since` that is not an ISO date throws a RangeError.

## Spec impact

none -- the project has no technical spec

## Verification

```bash
bash tests/run.sh
```

Runs: once. Environment: local checkout.

Success: command exits 0 and shows expected output. Failure: re-read plan, check if spec drifted.

## Done signal

Run `/ytstack:summarize-task` after execution to mark complete and advance STATE.md.
EOF
printf '{ "name": "csvexport", "private": true, "type": "module" }\n' > package.json
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
BASE=$(git rev-parse --short HEAD)

# Implementation: the `since` date itself is excluded, an invalid `since` is accepted.
cat > src/export.js <<'EOF'
// rowsSince: the rows changed since the ISO date `since`.
export function rowsSince(rows, since) {
  return rows.filter((r) => since < r.changedAt);
}
EOF
cat > tests/export.test.js <<'EOF'
import assert from "node:assert/strict";
import { rowsSince } from "../src/export.js";

const rows = [
  { id: 1, changedAt: "2026-10-30" },
  { id: 2, changedAt: "2026-11-01" },
  { id: 3, changedAt: "2026-11-02" },
];
const ids = (since) => rowsSince(rows, since).map((r) => r.id);

assert.deepEqual(ids("2026-10-31"), [2, 3]);
assert.deepEqual(ids("2026-11-05"), []);
console.log("2 tests passed");
EOF
printf '#!/usr/bin/env bash\nnode "$(dirname "$0")/export.test.js"\n' > tests/run.sh
git add -A && git commit -qm "M001-S01-T01: add rowsSince for the incremental export"
IMPL=$(git rev-parse --short HEAD)

# Fix after review round 1: `<` becomes `<=`, and `since` is validated.
cat > src/export.js <<'EOF'
// rowsSince: the rows changed since the ISO date `since`.
export function rowsSince(rows, since) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(since)) throw new RangeError("since must be an ISO date (YYYY-MM-DD)");
  return rows.filter((r) => since <= r.changedAt);
}
EOF
cat > tests/export.test.js <<'EOF'
import assert from "node:assert/strict";
import { rowsSince } from "../src/export.js";

const rows = [
  { id: 1, changedAt: "2026-10-30" },
  { id: 2, changedAt: "2026-11-01" },
  { id: 3, changedAt: "2026-11-02" },
];
const ids = (since) => rowsSince(rows, since).map((r) => r.id);

assert.deepEqual(ids("2026-10-31"), [2, 3]);
assert.deepEqual(ids("2026-11-05"), []);
// a row changed on the since date is part of the export
assert.deepEqual(ids("2026-11-01"), [2, 3]);
assert.throws(() => rowsSince(rows, "last week"), RangeError);
console.log("4 tests passed");
EOF
git add -A && git commit -q -m "M001-S01-T01: include rows changed on the since date, validate since" \
  -m "Review round 1: a row changed exactly on the since date was missing from the export, and a since that is not a date was accepted."
FIX1=$(git rev-parse --short HEAD)

# Fix after review round 2: `<=` goes back to `<`.
cat > src/export.js <<'EOF'
// rowsSince: the rows changed since the ISO date `since`.
export function rowsSince(rows, since) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(since)) throw new RangeError("since must be an ISO date (YYYY-MM-DD)");
  return rows.filter((r) => since < r.changedAt);
}
EOF
cat > tests/export.test.js <<'EOF'
import assert from "node:assert/strict";
import { rowsSince } from "../src/export.js";

const rows = [
  { id: 1, changedAt: "2026-10-30" },
  { id: 2, changedAt: "2026-11-01" },
  { id: 3, changedAt: "2026-11-02" },
];
const ids = (since) => rowsSince(rows, since).map((r) => r.id);

assert.deepEqual(ids("2026-10-31"), [2, 3]);
assert.deepEqual(ids("2026-11-05"), []);
// a row changed on the since date was already in the previous export
assert.deepEqual(ids("2026-11-01"), [3]);
assert.throws(() => rowsSince(rows, "last week"), RangeError);
console.log("4 tests passed");
EOF
git add -A && git commit -q -m "M001-S01-T01: exclude rows changed on the since date again" \
  -m "Review round 2: two consecutive exports, the second with since set to the date of the first, both contained the row changed on that date."

# The two recorded rounds, with the real ranges. Round 1 covered the whole
# change, round 2 the first fix. The second fix (the commit just made) is not
# reviewed yet.
cat >> .ytstack/M001-S01-T01-PLAN.md <<EOF

## Review

- Round 1: $BASE..$IMPL -- changes requested; blocking: 2; follow-ups: 1
- Round 2: $IMPL..$FIX1 -- changes requested; blocking: 1; follow-ups: 0
EOF
git add -A && git commit -qm "chore: record review rounds 1 and 2 in the T01 plan"
