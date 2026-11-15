#!/usr/bin/env bash
# Fixture: project csvexport whose main went red twice this week for the same
# reason: tests/export.test.sh reads a temp file that tests/import.test.sh
# leaves behind, so it passes only when import runs first. The first time was
# recorded as the lesson F001 (lesson:ci:flaky-order), open, its check not
# built yet. The person fixed the test by hand today (the last commit). The
# lesson step has to count the second incident on F001 instead of opening a
# new class, and must not answer it with one more sentence in AGENTS.md.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack/signals tests src
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small web app; users import and export their data as CSV.
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
printf '# Knowledge\n\n## Gotchas\n' > .ytstack/KNOWLEDGE.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
printf '# Agents\n\nRun the tests with bash tests/run.sh.\n' > AGENTS.md
cat > tests/run.sh <<'EOF'
#!/bin/sh
# Runs every test file; the order is the order of the shell glob.
set -e
for t in tests/*.test.sh; do sh "$t"; done
echo "all tests passed"
EOF
cat > tests/import.test.sh <<'EOF'
#!/bin/sh
# Imports a sample and checks the row count.
tmp="${TMPDIR:-/tmp}/csvexport-test"
mkdir -p "$tmp" && printf 'id,name\n1,a\n2,b\n' > "$tmp/sample.csv"
[ "$(wc -l < "$tmp/sample.csv")" -eq 3 ]
EOF
cat > tests/export.test.sh <<'EOF'
#!/bin/sh
# Exports the sample and checks the header. Writes its own sample (fixed today:
# it used to read the one import.test.sh leaves behind).
tmp="${TMPDIR:-/tmp}/csvexport-export-test"
mkdir -p "$tmp" && printf 'id,name\n1,a\n' > "$tmp/sample.csv"
head -1 "$tmp/sample.csv" | grep -q '^id,name$'
EOF
chmod +x tests/*.sh
echo "// export" > src/export.js
cat > .ytstack/signals/F001-a-test-depends-on-the-order-of-the-suite.md <<'EOF'
---
id: F001
key: lesson:ci:flaky-order
source: ci
kind: lesson
state: open
first_seen: 2026-11-11T08:12:00Z
last_seen: 2026-11-11T08:12:00Z
count: 1
ref: none
reopens: none
target: check:tests/order.test.sh
---

# F001 -- A test depends on the order of the suite

## What was seen

### read 2026-11-11T08:12:00Z

    main red at 3c1d2e0: tests/export.test.sh failed when it ran before tests/import.test.sh (shared temp file)

## Assessment

class: flaky-order, area ci. A machine can see it: run the suite in reverse order.

## Next

Build tests/order.test.sh (runs the suite in reverse order); nobody has yet.
EOF
git add -A && git commit -qm "chore: scaffold"
printf '\n' >> tests/export.test.sh
git add -A && git commit -qm "fix: export test writes its own sample instead of reading the import test's"
