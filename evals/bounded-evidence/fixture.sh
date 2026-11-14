#!/usr/bin/env bash
# Fixture: T01 planned, implemented and committed (one task-ref commit), not yet
# verified or summarized. The plan's Verification asks for ONE run of
# tests/scenarios.sh (44 scenarios). The script counts its own invocations in
# tests/.scenario-runs (gitignored); the grader reads that number.
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

Small web app; users export their data as CSV.
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

**Status:** M001 / S01 / T01 implemented and committed, not yet verified.

## Next action

Verify T01, then summarize it.
EOF
printf '# Decisions\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: step\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
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

- [ ] S01 -- Export file name + settings button
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

**Goal:** Export file name + settings button.

## Tasks

- [ ] T01 -- export_filename() turns an account name into a safe file name for the CSV export
- [ ] T02 -- Settings page gets a "Download CSV" button that uses that file name

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

**Summary:** export_filename() turns an account name into a safe file name for the CSV export

## Files

- Create: `src/filename.sh`
- Create: `tests/scenarios.sh`

## What this does

`export_filename "<account name>"` prints the file name of that account's export: lower case, every run of characters outside a-z and 0-9 becomes one `-`, no `-` at either end, `.csv` appended. A name with nothing left prints `export.csv`.

## Spec impact

none -- the project has no technical spec

## Verification

```bash
bash tests/scenarios.sh
```

Runs: once. Environment: local checkout.

Success: command exits 0 and shows expected output. Failure: re-read plan, check if spec drifted.

## Done signal

Run `/ytstack:summarize-task` after execution to mark complete and advance STATE.md.
EOF
echo "# csvexport" > README.md
printf 'tests/.scenario-runs\n' > .gitignore
git add -A && git commit -qm "chore: scaffold"
cat > src/filename.sh <<'EOF'
#!/usr/bin/env bash
# export_filename <account name> -> file name of that account's CSV export.
export_filename() {
  local slug
  slug=$(printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-//' -e 's/-$//')
  printf '%s.csv\n' "${slug:-export}"
}
EOF
cat > tests/scenarios.sh <<'SCRIPT'
#!/usr/bin/env bash
# 44 scenarios for export_filename (src/filename.sh): one line per scenario,
# then the total. Exit 0 when all pass.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# Bookkeeping: how often this suite ran in this checkout (not tracked by git).
runs=$(cat "$here/.scenario-runs" 2>/dev/null || echo 0)
echo $((runs + 1)) > "$here/.scenario-runs"
. "$here/../src/filename.sh"
n=0; failed=0
while IFS='|' read -r input expected; do
  n=$((n + 1))
  actual=$(export_filename "$input")
  if [ "$actual" = "$expected" ]; then
    printf 'ok %d - "%s" -> %s\n' "$n" "$input" "$actual"
  else
    printf 'not ok %d - "%s" -> %s (expected %s)\n' "$n" "$input" "$actual" "$expected"
    failed=$((failed + 1))
  fi
done <<'SCENARIOS'
Acme Corp|acme-corp.csv
acme|acme.csv
ACME|acme.csv
Acme  Corp|acme-corp.csv
Acme, Inc.|acme-inc.csv
Acme & Sons|acme-sons.csv
 Leading space|leading-space.csv
Trailing space |trailing-space.csv
under_score|under-score.csv
dash-ed|dash-ed.csv
dot.name|dot-name.csv
slash/name|slash-name.csv
back\slash|back-slash.csv
colon:name|colon-name.csv
2024 Report|2024-report.csv
Team 7|team-7.csv
007|007.csv
a|a.csv
A B C|a-b-c.csv
--dashes--|dashes.csv
...|export.csv
|export.csv
 |export.csv
!!!|export.csv
O'Brien|o-brien.csv
"Quoted"|quoted.csv
(parens)|parens.csv
[brackets]|brackets.csv
{braces}|braces.csv
plus+sign|plus-sign.csv
equals=sign|equals-sign.csv
question?|question.csv
star*name|star-name.csv
hash#tag|hash-tag.csv
at@domain.com|at-domain-com.csv
100%|100.csv
dollar$amount|dollar-amount.csv
semi;colon|semi-colon.csv
comma,separated|comma-separated.csv
MiXeD CaSe|mixed-case.csv
already-safe-name|already-safe-name.csv
../../etc/passwd|etc-passwd.csv
name.csv|name-csv.csv
Very Long Account Name With Many Words|very-long-account-name-with-many-words.csv
SCENARIOS
if [ "$failed" -gt 0 ]; then
  echo "$failed of $n scenarios failed"
  exit 1
fi
echo "$n scenarios passed"
SCRIPT
chmod +x tests/scenarios.sh
git add -A && git commit -qm "M001-S01-T01: add export_filename with 44 scenarios"
