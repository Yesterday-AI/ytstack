#!/usr/bin/env bash
# Fixture: an initialized .ytstack/ without a milestone, and the project's real
# plan in plans/: a board of work packages (2 done, 9 open, EXP-04 depends on
# EXP-03) plus a checklist file. The frontier sees none of it.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p .ytstack plans
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
current_milestone: none
active_slice: none
active_task: none
---
# State

**Status:** adopted, no milestone yet.

## Next action

Plan the export v2 work.
EOF
printf '# Decisions\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '# Preferences\n\nexplain_level: default\n' > .ytstack/PREFERENCES.md
cat > plans/2026-11-01-export-v2.md <<'EOF'
# Export v2 work packages

Export v2 replaces the synchronous CSV endpoint with a job that streams to object storage.

## Board

| Done | ID | Deliverable | Depends on | State |
| --- | --- | --- | --- | --- |
| [x] | EXP-01 | Job table and migration | - | Merged #11 |
| [x] | EXP-02 | Worker skeleton | EXP-01 | Merged #12 |
| [ ] | EXP-03 | Stream rows to object storage | EXP-02 | open |
| [ ] | EXP-04 | Signed download link | EXP-03 | open |
| [ ] | EXP-05 | Settings page shows job progress | - | open |
| [ ] | EXP-06 | Email when the export is ready | - | open |
| [ ] | EXP-07 | Retention: delete files after 7 days | - | open |
| [ ] | EXP-08 | Rate limit per account | - | open |
| [ ] | EXP-09 | Metrics for job duration | - | open |
| [ ] | EXP-10 | Remove the old endpoint | - | open |
| [ ] | EXP-11 | Docs for the new export | - | open |

## EXP-03 -- Stream rows to object storage

- [ ] Write rows in chunks of 10k
- [ ] Resume a job after a worker restart
EOF
cat > plans/2026-10-20-export-v1-retro.md <<'EOF'
# Export v1 follow-ups

| Item | Status |
| --- | --- |
| Fix the BOM in Excel | done |
| Quote newlines | done |
| Document the columns | done |
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
