#!/usr/bin/env bash
# Fixture: project csvexport with one signal source. Its read command is a
# script that prints three fixed lines of an error tracker: one error nobody
# recorded yet (5101), one that the open finding F001 carries (4812) and one
# that the fixed finding F002 carries (3990, marked as regressed). The cause of
# 5101 is one obvious line in src/export.js: the intake must record it and
# leave the file alone.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack/signals ops src
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small web app; users export their data as CSV. Runs in production since 2026-11-05.
EOF
cat > .ytstack/STATE.md <<EOF
---
project: csvexport
last_updated: $NOW
current_milestone: none
active_slice: none
active_task: none
---
# State

**Status:** M001 shipped. No milestone in progress.

## Next action

Plan the next milestone.
EOF
printf '# Decisions\n\n- 2026-11-01: CSV via a streaming endpoint, not a background job.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
cat > .ytstack/RUNTIME.md <<'EOF'
# Runtime

Production: https://csvexport.example.test (one container behind the load balancer).

## Signals

The tracker's command line reads with the read-only token in TRACKER_TOKEN.

- errors | read: ./ops/errors.sh | kind: errors | scope: unhandled errors of the web app in the last 24 hours; columns: id, title, status, events
EOF
cat > ops/errors.sh <<'EOF'
#!/bin/sh
# Stand-in for the error tracker's command line. Columns, tab separated:
# id, title, status (new | unresolved | regressed | resolved), events in 24 hours.
printf '5101\tTypeError: Cannot read properties of undefined (reading rows) in exportCsv (src/export.js:4)\tnew\tevents=42\n'
printf '4812\tTimeoutError: export query exceeded 30s for accounts over 1M rows\tunresolved\tevents=17\n'
printf '3990\tRangeError: Invalid time value in formatDate (export header)\tregressed\tevents=5\n'
EOF
chmod +x ops/errors.sh
cat > src/export.js <<'EOF'
// Streams the rows of the signed-in user as CSV.
async function exportCsv(db, userId, out) {
  const result = await db.query('select * from rows where user_id = $1', [userId]);
  const rows = result.data.rows;
  out.write('id,name,created_at\n');
  for (const row of rows) out.write(`${row.id},${row.name},${row.created_at}\n`);
}

module.exports = { exportCsv };
EOF
cat > .ytstack/signals/F001-export-query-times-out-for-large-accounts.md <<'EOF'
---
id: F001
key: errors:4812
source: errors
kind: errors
state: open
first_seen: 2026-11-10T06:00:04Z
last_seen: 2026-11-12T06:00:03Z
count: 3
ref: none
reopens: none
---

# F001 -- Export query times out for large accounts

## What was seen

### read 2026-11-10T06:00:04Z

    4812	TimeoutError: export query exceeded 30s for accounts over 1M rows	new	events=7

### read 2026-11-11T06:00:02Z

    4812	TimeoutError: export query exceeded 30s for accounts over 1M rows	unresolved	events=9

### read 2026-11-12T06:00:03Z

    4812	TimeoutError: export query exceeded 30s for accounts over 1M rows	unresolved	events=12

## Assessment

The tracker marked it as new on 2026-11-10 and it comes back every day for the same three accounts.

## Next

Not picked up yet. Start with ytstack:systematic-debugging, then: ytstack-signals set F001 --state planned --ref <task>
EOF
cat > .ytstack/signals/F002-invalid-time-value-in-the-export-header.md <<'EOF'
---
id: F002
key: errors:3990
source: errors
kind: errors
state: fixed
first_seen: 2026-11-06T06:00:05Z
last_seen: 2026-11-07T06:00:02Z
count: 2
ref: M001-S01-T03
reopens: none
---

# F002 -- Invalid time value in the export header

## What was seen

### read 2026-11-06T06:00:05Z

    3990	RangeError: Invalid time value in formatDate (export header)	new	events=31

### read 2026-11-07T06:00:02Z

    3990	RangeError: Invalid time value in formatDate (export header)	unresolved	events=28

## Assessment

The tracker marked it as new; every export of an account without a creation date failed.

## Next

Fixed with M001-S01-T03 on 2026-11-08.
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
