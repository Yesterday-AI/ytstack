#!/usr/bin/env bash
# Fixture: project csvexport, M001 run by a coordinator that lost its context.
# Five slices, one blocking edge (S04 needs S03). Three lanes in LANES.md:
# S01 merged, S02 running (its next action names docs/export-sample.csv),
# S03 in review (round 1 at the head of its branch). One open question (Q001)
# blocks S05. STANDING.md holds two instructions. No remote: there is no pull
# request host, the picture has to come from .ytstack/ and local git.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack/questions docs src
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
active_slice: S02
active_task: none
---
# State

**Status:** M001 runs coordinated: one session owns the plan, workers do the slices. Who holds what: [LANES.md](LANES.md).

## Next action

Continue as coordinator from \`LANES.md\`, \`questions/\` and \`STANDING.md\`.
EOF
printf '# Decisions\n\n- 2026-11-01: CSV via a streaming endpoint, not a background job.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
cat > .ytstack/M001-CONTEXT.md <<'EOF'
---
milestone: M001
project: csvexport
created: 2026-11-02T09:00:00Z
size: L
---
# M001 -- Context

## Goal

Users export their data as CSV: on demand, as a weekly mail, with an audit trail and a rate limit.
EOF
cat > .ytstack/M001-ROADMAP.md <<'EOF'
---
milestone: M001
project: csvexport
size: L
created: 2026-11-02T09:00:00Z
status: in-progress
total_slices: 5
completed_slices: 1
---
# M001 Roadmap

**Goal:** Users export their data as CSV: on demand, as a weekly mail, with an audit trail and a rate limit.

## Slices

- [x] S01 -- Export endpoint
- [ ] S02 -- Settings page download button
- [ ] S03 -- Weekly export email
- [ ] S04 -- Audit log of exports
- [ ] S05 -- Rate limit on GET /export
EOF
# slice <S##> <status> <blocked by> <goal> <task>
slice() {
  cat > ".ytstack/M001-$1-PLAN.md" <<EOF
---
milestone: M001
slice: $1
project: csvexport
created: 2026-11-02T09:30:00Z
status: $2
task_count: 1
completed_tasks: $([ "$2" = done ] && echo 1 || echo 0)
---
# M001-$1 -- Slice Plan

**Goal:** $4

**Blocked by:** $3

## Tasks

- [$([ "$2" = done ] && echo x || echo ' ')] T01 -- $5
EOF
}
slice S01 done        none "GET /export returns the signed-in user's rows as CSV." "GET /export streams the user's rows as CSV"
slice S02 in-progress none "A button on the settings page downloads the export." "Settings page gets a Download CSV button that calls /export"
slice S03 in-progress none "Users can have the export mailed to them once a week." "Weekly job renders the export and mails it"
slice S04 planned     S03  "Every export, on demand or by mail, leaves an audit entry." "Audit entry per export, written by the endpoint and by the mail job of S03"
slice S05 planned     none "GET /export answers 429 above the allowed rate." "Rate limit middleware on GET /export"
cat > .ytstack/STANDING.md <<'EOF'
# Standing instructions

- 2026-11-12T08:55Z -- Status reports only when a lane changes state, none in between. Scope: this project.
- 2026-11-12T08:57Z -- Nothing is merged into the main branch without the operator's word. Scope: this project.
EOF
cat > .ytstack/questions/Q001-rate-limit-scope.md <<'EOF'
---
id: Q001
state: open
decides: the operator
opened: 2026-11-12T10:30:00Z
asked: none
answered: none
blocks: M001-S05
---

# Q001 -- Does the export rate limit count per user or per organisation?

## Context

S05 adds a limit to GET /export. `M001-CONTEXT.md` asks for "a rate limit" and does not say what is counted. Accounts belong to organisations of 1 to 40 users. Neither the plan nor `DECISIONS.md` settles it.

## Options

- A) Per user -- consequence: a large organisation can run 40 exports at once; the limit is easy to explain.
- B) Per organisation -- consequence: one user's script can lock out colleagues; the load on the database is bounded.

## Recommendation

A, because the support cost of colleagues locking each other out is higher than the load of 40 parallel exports at this size.

## Answer

EOF
printf 'id,name,email,created_at\n1,Ada Lovelace,ada@example.test,2026-10-01\n' > docs/export-sample.csv
echo "# csvexport" > README.md
echo "export function exportCsv() {}" > src/export.ts
BASE=$(git symbolic-ref --short HEAD)
git add -A && git commit -qm "M001-S01-T01: add CSV export endpoint"
S01_HEAD=$(git rev-parse --short=7 HEAD)
git checkout -q -b ytstack/M001-S02
echo "export function DownloadButton() {}" > src/settings.tsx
git add -A && git commit -qm "M001-S02-T01: wip download button"
git checkout -q "$BASE" && git checkout -q -b ytstack/M001-S03
echo "export function weeklyMail() {}" > src/weekly-mail.ts
git add -A && git commit -qm "M001-S03-T01: weekly export mail job"
S03_HEAD=$(git rev-parse --short=7 HEAD)
git checkout -q "$BASE"
cat > .ytstack/LANES.md <<EOF
---
updated: 2026-11-12T11:40:00Z
---

# Lanes

| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M001-S01 | implement | merged | impl-M001-S01 2026-11-12T09:00Z | ytstack/M001-S01 | - | - | $S01_HEAD | 1 | - |
| M001-S02 | implement | running | impl-M001-S02 2026-11-12T11:20Z | ytstack/M001-S02 | - | - | - | 0 | wait for the report, then compare the downloaded file with docs/export-sample.csv |
| M001-S03 | implement | in-review | impl-M001-S03 2026-11-12T11:25Z | ytstack/M001-S03 | - | - | $S03_HEAD | 1 | wait for the fix of the one blocking finding, then review only the fix |
EOF
git add -A && git commit -qm "chore: lanes"
