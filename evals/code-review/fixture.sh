#!/usr/bin/env bash
# Fixture: T01 planned and implemented in one task-ref commit, not yet reviewed or summarized.
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

**Status:** M001 / S01 / T01 implemented, not yet reviewed.

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

## Tasks

- [ ] T01 -- toCsv() renders rows as CSV with a header line
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

**Summary:** toCsv() renders rows as CSV with a header line

## Files

- Create: `src/export.js`
- Create: `tests/run.sh`

## What this does

`toCsv(header, rows)` returns the header line followed by one line per row; fields containing commas or quotes are quoted per RFC 4180.

## Verification

```bash
bash tests/run.sh
```
EOF
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
cat > src/export.js <<'EOF'
// toCsv: header + rows -> CSV text. Quoting of commas/quotes is not implemented yet.
export function toCsv(header, rows) {
  return [header.join(","), ...rows.map((r) => r.join(","))].join("\n");
}
EOF
printf '#!/usr/bin/env bash\nnode -e "import(\\"./src/export.js\\").then(m=>{const out=m.toCsv([\\"a\\",\\"b\\"],[[1,2]]); if(out!==\\"a,b\\\\n1,2\\") process.exit(1); console.log(\\"1 test passed\\")})"\n' > tests/run.sh
git add -A && git commit -qm "M001-S01-T01: add toCsv with header line"
