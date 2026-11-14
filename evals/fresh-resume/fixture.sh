#!/usr/bin/env bash
# Fixture: the shared snapshot of the three fresh-session cases (fresh-resume,
# fresh-bugfix, fresh-requirement). The three fixture.sh files are identical.
#
# Project csvexport, written in bash. History:
#   M001 (done)        context and summaries say archived rows ARE exported
#   M002 (done)        a decision and a summary say archived rows are EXCLUDED,
#                      and --since limits the rows by date; M001 files untouched
#   M003 (in progress) one slice, T01 (JSON output) not planned yet
# .ytstack/spec/ says what applies now: archived rows are excluded, with or
# without --since. The code has one defect: with --since the archived rows are
# not filtered out. No test covers that combination, so the suite passes.
# Dates are fixed, so every run builds the same commits.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack/spec src tests data

# commit <iso-date> <subject>: everything in the tree, with a fixed date
commit() {
  git add -A
  GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2"
}

# summary_head <milestone> <slice> <task> <closed> <commit> <subject>
summary_head() {
  printf -- '---\nmilestone: %s\nslice: %s\ntask: %s\nproject: csvexport\nclosed: %s\nverification: passed\n---\n' "$1" "$2" "$3" "$4"
  printf '# %s-%s-%s -- Summary\n\n## Commits\n\n- `%s` -- %s\n\n' "$1" "$2" "$3" "$5" "$6"
}

# ---- scaffold ------------------------------------------------------------------
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-02T08:30:00Z
scope: project
---
# csvexport

A small command-line tool in bash. Users get their rows out of the data file as CSV.
EOF
cat > .ytstack/KNOWLEDGE.md <<'EOF'
# Knowledge

- Dates in the form YYYY-MM-DD sort as text, so bash can compare them with `[[ a < b ]]`.
- A command substitution drops the trailing newline; the tests compare whole outputs that way.
EOF
cat > .ytstack/RUNTIME.md <<'EOF'
# Runtime

- Run: `bash src/export.sh <user>`
- Test: `bash tests/run.sh`
- Needs bash and coreutils. Nothing is built or installed.
EOF
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

A user gets their rows out of the data file as CSV.

## Exit criteria

- `bash src/export.sh <user>` prints a header line and every row of that user.
- Archived rows are part of the export: the export is a complete copy of what the user has.
- `bash tests/run.sh` passes.
EOF
cat > README.md <<'EOF'
# csvexport

Prints the rows of one user from `data/rows.csv` as CSV.

    bash src/export.sh <user>
    bash tests/run.sh
EOF
commit 2026-11-02T09:15:00Z "chore: scaffold csvexport"

# ---- M001-S01-T01 --------------------------------------------------------------
cat > data/rows.csv <<'EOF'
owner,id,name,changed,archived
ada,1,Invoice January,2026-01-15,no
ada,2,Invoice February,2026-02-15,no
ada,3,Draft offer,2026-02-20,yes
ada,4,Invoice March,2026-03-15,no
grace,5,Contract,2026-01-10,no
grace,6,Old contract,2026-03-01,yes
EOF
cat > src/export.sh <<'EOF'
#!/usr/bin/env bash
# csvexport: print the rows of one user as CSV.
# Usage: export.sh <user>
set -eu

usage() { echo "usage: export.sh <user>" >&2; exit 2; }

[ $# -eq 1 ] || usage
user="$1"
data="${CSVEXPORT_DATA:-$(dirname "$0")/../data/rows.csv}"

echo "id,name,changed"
{
  read -r _header || true
  while IFS=, read -r owner id name changed archived; do
    [ "$owner" = "$user" ] || continue
    echo "$id,$name,$changed"
  done
} < "$data"
EOF
cat > .ytstack/M001-S01-T01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
task: T01
project: csvexport
created: 2026-11-02T10:00:00Z
status: done
---
# M001-S01-T01 -- Task Plan

**Summary:** `src/export.sh` prints the rows of one user as CSV with a header line

## Files

- Create: `src/export.sh`
- Create: `data/rows.csv`

## What this does

`bash src/export.sh <user>` reads `data/rows.csv` (columns owner, id, name, changed, archived), prints the header line `id,name,changed` and then one line per row whose owner is the user, in file order. Every row of the user is printed, archived or not.

## Verification

```bash
bash src/export.sh ada
```
EOF
commit 2026-11-02T11:30:00Z "M001-S01-T01: export the rows of one user as CSV"
C_M1T1=$(git rev-parse --short HEAD)

# ---- M001-S01-T02 --------------------------------------------------------------
cat > tests/run.sh <<'EOF'
#!/usr/bin/env bash
# Tests for src/export.sh against data/rows.csv.
# Prints "<n> tests passed", or one FAIL block per failed test. Exit code 0 or 1.
set -u
cd "$(dirname "$0")/.."

pass=0
fail=0
header="id,name,changed"

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

check "every row of the user is printed, archived rows included" \
  "$(printf '%s\n' "$header" "1,Invoice January,2026-01-15" "2,Invoice February,2026-02-15" "3,Draft offer,2026-02-20" "4,Invoice March,2026-03-15")" \
  "$(bash src/export.sh ada)"

check "rows of other users are not printed" \
  "$(printf '%s\n' "$header" "5,Contract,2026-01-10" "6,Old contract,2026-03-01")" \
  "$(bash src/export.sh grace)"

check "a user without rows gets the header line only" \
  "$header" \
  "$(bash src/export.sh nobody)"

if [ "$fail" -eq 0 ]; then
  echo "$pass tests passed"
else
  echo "$fail of $((pass + fail)) tests failed"
  exit 1
fi
EOF
{
  summary_head M001 S01 T01 2026-11-02T12:00:00Z "$C_M1T1" "M001-S01-T01: export the rows of one user as CSV"
  cat <<'EOF'
## Outcome

`bash src/export.sh <user>` prints the header line `id,name,changed` and every row of the user in file order. Archived rows are part of the export; the column `archived` itself is not printed.

## Deviations from plan

None.

## Follow-ups

- No tests yet (T02).

## Verification

Command: `bash src/export.sh ada` -- printed the header line and four rows, the archived one among them.
EOF
} > .ytstack/M001-S01-T01-SUMMARY.md
cat > .ytstack/M001-S01-T02-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
task: T02
project: csvexport
created: 2026-11-03T09:00:00Z
status: done
---
# M001-S01-T02 -- Task Plan

**Summary:** `tests/run.sh` pins the export behaviour

## Files

- Create: `tests/run.sh`

## What this does

A test script in bash without dependencies. A helper `check <name> <expected> <actual>` compares whole outputs. Three tests: every row of the user including the archived one, no rows of other users, header line only for a user without rows. The last line is `<n> tests passed`; a failure prints a FAIL block and the exit code is 1.

## Verification

```bash
bash tests/run.sh
```
EOF
cat > .ytstack/M001-ROADMAP.md <<'EOF'
---
milestone: M001
project: csvexport
size: S
created: 2026-11-02T09:00:00Z
status: done
total_slices: 1
completed_slices: 1
---
# M001 Roadmap

**Goal:** A user gets their rows out of the data file as CSV.

## Slices

- [x] S01 -- Export script + test suite
EOF
cat > .ytstack/M001-S01-PLAN.md <<'EOF'
---
milestone: M001
slice: S01
project: csvexport
created: 2026-11-02T09:30:00Z
status: done
task_count: 2
completed_tasks: 2
---
# M001-S01 -- Slice Plan

**Goal:** Export script + test suite.

## Tasks

- [x] T01 -- `src/export.sh` prints the rows of one user as CSV with a header line
- [x] T02 -- `tests/run.sh` pins the export behaviour

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.
EOF
commit 2026-11-03T11:00:00Z "M001-S01-T02: test suite for the export"
C_M1T2=$(git rev-parse --short HEAD)

# ---- M002-S01-T01 --------------------------------------------------------------
cat > src/export.sh <<'EOF'
#!/usr/bin/env bash
# csvexport: print the rows of one user as CSV.
# Usage: export.sh <user>
set -eu

usage() { echo "usage: export.sh <user>" >&2; exit 2; }

[ $# -eq 1 ] || usage
user="$1"
data="${CSVEXPORT_DATA:-$(dirname "$0")/../data/rows.csv}"

echo "id,name,changed"
{
  read -r _header || true
  while IFS=, read -r owner id name changed archived; do
    [ "$owner" = "$user" ] || continue
    [ "$archived" = no ] || continue
    echo "$id,$name,$changed"
  done
} < "$data"
EOF
cat > tests/run.sh <<'EOF'
#!/usr/bin/env bash
# Tests for src/export.sh against data/rows.csv.
# Prints "<n> tests passed", or one FAIL block per failed test. Exit code 0 or 1.
set -u
cd "$(dirname "$0")/.."

pass=0
fail=0
header="id,name,changed"

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

check "archived rows are left out" \
  "$(printf '%s\n' "$header" "1,Invoice January,2026-01-15" "2,Invoice February,2026-02-15" "4,Invoice March,2026-03-15")" \
  "$(bash src/export.sh ada)"

check "rows of other users are not printed" \
  "$(printf '%s\n' "$header" "5,Contract,2026-01-10")" \
  "$(bash src/export.sh grace)"

check "a user without rows gets the header line only" \
  "$header" \
  "$(bash src/export.sh nobody)"

if [ "$fail" -eq 0 ]; then
  echo "$pass tests passed"
else
  echo "$fail of $((pass + fail)) tests failed"
  exit 1
fi
EOF
{
  summary_head M001 S01 T02 2026-11-03T11:30:00Z "$C_M1T2" "M001-S01-T02: test suite for the export"
  cat <<'EOF'
## Outcome

`tests/run.sh` runs three tests and prints `3 tests passed`. The first test pins what M001 asked for: every row of the user is in the output and archived rows are part of the export. M001 is complete.

## Deviations from plan

None.

## Follow-ups

- None.

## Verification

Command: `bash tests/run.sh` -- `3 tests passed`, exit code 0.
EOF
} > .ytstack/M001-S01-T02-SUMMARY.md
cat > .ytstack/DECISIONS.md <<'EOF'
# Decisions

Append-only architectural and product decisions for csvexport. Never rewrite past entries. If a decision is reversed, add a new entry that supersedes.

## 2026-11-02: The export is a complete copy of a user's rows

**Context:** M001 needed a rule for which rows the export prints.
**Options considered:** every row of the user; only rows that are not archived.
**Chose:** every row of the user, archived rows included.
**Reason:** the first users wanted a backup of everything they have.

## 2026-11-05: Archived rows are not part of the export

**Context:** users open the export in a spreadsheet and work with it. Archived rows showed up there as if they were current, and two users sent out offers that had been archived.
**Options considered:** keep every row and print the `archived` column; leave archived rows out; a switch that includes them on request.
**Chose:** leave archived rows out. No switch.
**Reason:** the export is a working copy, not a backup. Nobody asked for the archived rows back when we proposed this.
**Supersedes:** "2026-11-02: The export is a complete copy of a user's rows", for archived rows.

## 2026-11-06: `--since` takes a date YYYY-MM-DD and compares it as text

**Context:** M002 limits the export to rows changed on or after a date.
**Options considered:** parse dates with `date`; compare the text.
**Chose:** compare the text. The value must have the form YYYY-MM-DD, anything else is an error.
**Reason:** `date` differs between systems, and dates in this form sort as text.
EOF
cat > .ytstack/M002-CONTEXT.md <<'EOF'
---
milestone: M002
project: csvexport
created: 2026-11-05T09:00:00Z
size: S
---
# M002 -- Context

## Goal

The export shows what a user works with, and can be limited to what changed lately.

## Exit criteria

- Archived rows are excluded from the export (DECISIONS 2026-11-05).
- `bash src/export.sh <user> --since <date>` prints only the rows changed on or after that date.
- `bash tests/run.sh` passes.
EOF
cat > .ytstack/M002-S01-T01-PLAN.md <<'EOF'
---
milestone: M002
slice: S01
task: T01
project: csvexport
created: 2026-11-05T09:45:00Z
status: done
---
# M002-S01-T01 -- Task Plan

**Summary:** Archived rows are left out of the export

## Files

- Modify: `src/export.sh`
- Modify: `tests/run.sh`

## What this does

The row loop skips every row whose column `archived` is not `no`. The first test changes from "archived rows included" to "archived rows are left out"; the test for the other user loses its archived row.

## Verification

```bash
bash tests/run.sh
```
EOF
commit 2026-11-05T11:00:00Z "M002-S01-T01: leave archived rows out of the export"
C_M2T1=$(git rev-parse --short HEAD)

# ---- M002-S01-T02 (introduces the defect) --------------------------------------
cat > src/export.sh <<'EOF'
#!/usr/bin/env bash
# csvexport: print the rows of one user as CSV.
# Usage: export.sh <user> [--since YYYY-MM-DD]
set -eu

usage() { echo "usage: export.sh <user> [--since YYYY-MM-DD]" >&2; exit 2; }

user=""
since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since)
      [ $# -ge 2 ] || usage
      since="$2"
      shift 2 ;;
    -*) usage ;;
    *) user="$1"; shift ;;
  esac
done
[ -n "$user" ] || usage
case "$since" in
  ""|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "export: --since needs a date YYYY-MM-DD, got '$since'" >&2; exit 2 ;;
esac

data="${CSVEXPORT_DATA:-$(dirname "$0")/../data/rows.csv}"

echo "id,name,changed"
{
  read -r _header || true
  while IFS=, read -r owner id name changed archived; do
    [ "$owner" = "$user" ] || continue
    if [ -z "$since" ]; then
      [ "$archived" = no ] || continue
    else
      [[ "$changed" < "$since" ]] && continue
    fi
    echo "$id,$name,$changed"
  done
} < "$data"
EOF
cat > tests/run.sh <<'EOF'
#!/usr/bin/env bash
# Tests for src/export.sh against data/rows.csv.
# Prints "<n> tests passed", or one FAIL block per failed test. Exit code 0 or 1.
set -u
cd "$(dirname "$0")/.."

pass=0
fail=0
header="id,name,changed"

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

check "archived rows are left out" \
  "$(printf '%s\n' "$header" "1,Invoice January,2026-01-15" "2,Invoice February,2026-02-15" "4,Invoice March,2026-03-15")" \
  "$(bash src/export.sh ada)"

check "rows of other users are not printed" \
  "$(printf '%s\n' "$header" "5,Contract,2026-01-10")" \
  "$(bash src/export.sh grace)"

check "a user without rows gets the header line only" \
  "$header" \
  "$(bash src/export.sh nobody)"

check "--since keeps the rows changed on or after the date" \
  "$(printf '%s\n' "$header" "4,Invoice March,2026-03-15")" \
  "$(bash src/export.sh ada --since 2026-03-01)"

check "--since counts the date itself" \
  "$(printf '%s\n' "$header" "4,Invoice March,2026-03-15")" \
  "$(bash src/export.sh ada --since 2026-03-15)"

check "--since rejects a value that is not a date" \
  "2" \
  "$(bash src/export.sh ada --since yesterday >/dev/null 2>&1; echo $?)"

if [ "$fail" -eq 0 ]; then
  echo "$pass tests passed"
else
  echo "$fail of $((pass + fail)) tests failed"
  exit 1
fi
EOF
{
  summary_head M002 S01 T01 2026-11-05T11:30:00Z "$C_M2T1" "M002-S01-T01: leave archived rows out of the export"
  cat <<'EOF'
## Outcome

Archived rows are excluded from the export. `src/export.sh` skips every row whose column `archived` is not `no`. The test that pinned the M001 behaviour now asserts the opposite, and the other user's archived row left the expected output. The decision is in DECISIONS.md (2026-11-05).

## Deviations from plan

None.

## Follow-ups

- M001-CONTEXT.md and the M001 summaries still describe the old behaviour. They are history and stay as written.

## Verification

Command: `bash tests/run.sh` -- `3 tests passed`, exit code 0.
EOF
} > .ytstack/M002-S01-T01-SUMMARY.md
cat > .ytstack/M002-S01-T02-PLAN.md <<'EOF'
---
milestone: M002
slice: S01
task: T02
project: csvexport
created: 2026-11-06T09:00:00Z
status: done
---
# M002-S01-T02 -- Task Plan

**Summary:** Optional `--since <date>`: only rows changed on or after that date

## Files

- Modify: `src/export.sh`
- Modify: `tests/run.sh`

## What this does

`src/export.sh` reads its arguments in a loop: the user, and an optional `--since <YYYY-MM-DD>`. With the option, a row is printed only when its column `changed` is on or after the date (text comparison, DECISIONS 2026-11-06). A value that is not a date, an unknown option or a missing user prints a message on standard error and exits with code 2. Without the option the output is unchanged.

## Verification

```bash
bash tests/run.sh
```
EOF
commit 2026-11-06T11:00:00Z "M002-S01-T02: optional --since date for the export"
C_M2T2=$(git rev-parse --short HEAD)

# ---- close M002 ----------------------------------------------------------------
{
  summary_head M002 S01 T02 2026-11-06T11:30:00Z "$C_M2T2" "M002-S01-T02: optional --since date for the export"
  cat <<'EOF'
## Outcome

`bash src/export.sh <user> --since <YYYY-MM-DD>` limits the export to the rows changed on or after that date; the date itself counts. A value that is not a date ends with exit code 2 and a message on standard error. Without the option the output is unchanged. M002 is complete.

## Deviations from plan

None.

## Follow-ups

- None.

## Verification

Command: `bash tests/run.sh` -- `6 tests passed`, exit code 0.
EOF
} > .ytstack/M002-S01-T02-SUMMARY.md
cat > .ytstack/M002-ROADMAP.md <<'EOF'
---
milestone: M002
project: csvexport
size: S
created: 2026-11-05T09:00:00Z
status: done
total_slices: 1
completed_slices: 1
---
# M002 Roadmap

**Goal:** The export shows what a user works with, and can be limited to what changed lately.

## Slices

- [x] S01 -- Archived rows and the since date
EOF
cat > .ytstack/M002-S01-PLAN.md <<'EOF'
---
milestone: M002
slice: S01
project: csvexport
created: 2026-11-05T09:30:00Z
status: done
task_count: 2
completed_tasks: 2
---
# M002-S01 -- Slice Plan

**Goal:** Archived rows and the since date.

## Tasks

- [x] T01 -- Archived rows are left out of the export
- [x] T02 -- Optional `--since <date>`: only rows changed on or after that date

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.
EOF
commit 2026-11-06T11:45:00Z "chore: close M002"
V=$(git rev-parse --short HEAD)

# ---- technical spec ------------------------------------------------------------
cat > .ytstack/spec/SPEC.md <<'EOF'
---
project: csvexport
updated: 2026-11-07
---

# csvexport -- technical spec

## What this is

A command-line tool in bash. `src/export.sh` prints the rows of one user from the data file as CSV. It has two parts: the export and the data file it reads.

This spec says what applies now. `STATE.md` says where the work stands, `DECISIONS.md` why, the `M###-*` files what happened.

## Areas

| Area | Covers | Status | File |
|---|---|---|---|
| export | Which rows the export prints, the `--since` option, the output format, errors | implemented | [export.md](export.md) |
| storage | The data file `data/rows.csv` and its columns | implemented | [storage.md](storage.md) |

## Invariants that hold everywhere

- The tool only reads the data file. Nothing in this repository writes it ([storage.md](storage.md)).
- bash and coreutils only, so that `bash tests/run.sh` runs anywhere without a setup step.

## Build and test

Nothing is built. From the repository root: `bash tests/run.sh`.

## Keeping this true

- A task plan names its **Spec impact**: the area and section it changes, or `none`.
- A task that changes behaviour updates the area file, or the source the area file names, in the same commits. A task that restores the described behaviour, a refactoring and a trivial edit close with `none`.
- A decision that changes what applies in an area is linked under that area's "Decisions that apply now" in the same commits; the entry it replaces leaves the list.
- Which area describes a path: the `paths` in each area file. Which areas need a look: `bin/ytstack-spec drift`.
- The format: `docs/ux/spec-format.md` in the ytstack plugin.
EOF
{
  printf -- '---\narea: export\nstatus: implemented\npaths:\n  - src/export.sh\n  - tests/run.sh\nverified_at: %s\n---\n' "$V"
  cat <<'EOF'

# export

## Purpose

Prints the rows of one user as CSV on standard output. The area ends where the data file begins: its columns and values are described in [storage.md](storage.md).

## Behavior

- `bash src/export.sh <user>` prints a header line and then one line per row of that user, in the order of the data file.
- The header line is `id,name,changed`. It is always the first line, and a user without rows gets the header line only.
- Archived rows are excluded from the export, with or without `--since`.
- `--since <YYYY-MM-DD>` limits the export to the rows changed on or after that date. The date itself counts.
- Rows of other users are never printed.

## Interfaces and contracts

- Call: `bash src/export.sh <user> [--since <YYYY-MM-DD>]`.
- Output columns: `id`, `name`, `changed`, in that order. The columns `owner` and `archived` of the data file are not printed.
- The data file is `data/rows.csv`. The environment variable `CSVEXPORT_DATA` names another file.

## Error behavior

- No user, an unknown option, `--since` without a value or with a value that is not a date `YYYY-MM-DD`: a message on standard error, exit code 2, nothing on standard output.

## Where implemented

- `src/export.sh` -- the arguments are read at the top, the row loop at the bottom decides which rows are printed.
- Tests that pin the behaviour: `tests/run.sh`.

## How to verify

`bash tests/run.sh` exits with code 0 and its last line is `<n> tests passed`. A failed test prints `FAIL <name>` with the expected and the actual output, and the exit code is 1. Last run at the commit in `verified_at`: passed.

## Decisions that apply now

- DECISIONS.md -- "2026-11-05: Archived rows are not part of the export". It replaces "2026-11-02: The export is a complete copy of a user's rows" for archived rows.
- DECISIONS.md -- "2026-11-06: `--since` takes a date YYYY-MM-DD and compares it as text"
EOF
} > .ytstack/spec/export.md
{
  printf -- '---\narea: storage\nstatus: implemented\npaths:\n  - data/rows.csv\nverified_at: %s\n---\n' "$V"
  cat <<'EOF'

# storage

## Purpose

The data file the export reads: one text file with the rows of all users. Nothing in this repository writes it.

## Interfaces and contracts

- `data/rows.csv`: the first line names the columns `owner,id,name,changed,archived`. Every further line is one row with these five fields, separated by commas.
- `changed` is a date `YYYY-MM-DD`. `archived` is `yes` or `no`.
- There is no quoting: a value contains no comma and no line break.

## Known limits

- The whole file is read on every export. That is fine for a few thousand rows.

## Where implemented

- `data/rows.csv` -- the file itself. `src/export.sh` reads it.

## How to verify

`bash tests/run.sh`: the export tests read this file, so a malformed line shows up as a failed export test.

## Decisions that apply now

None.
EOF
} > .ytstack/spec/storage.md
commit 2026-11-07T10:00:00Z "docs: technical spec for export and storage"

# ---- M003 planned and sliced ---------------------------------------------------
cat > .ytstack/M003-CONTEXT.md <<'EOF'
---
milestone: M003
project: csvexport
created: 2026-11-10T08:00:00Z
size: S
---
# M003 -- Context

## Goal

Programs can read the export: JSON as a second output format.

## Exit criteria

- An option of `src/export.sh` switches the output from CSV to JSON. The rows are the same as in the CSV export.
- Without the option the output is unchanged.
- `bash tests/run.sh` passes.
EOF
cat > .ytstack/M003-ROADMAP.md <<'EOF'
---
milestone: M003
project: csvexport
size: S
created: 2026-11-10T08:00:00Z
status: in-progress
total_slices: 1
completed_slices: 0
---
# M003 Roadmap

**Goal:** Programs can read the export: JSON as a second output format.

## Slices

- [ ] S01 -- JSON output option
EOF
cat > .ytstack/M003-S01-PLAN.md <<'EOF'
---
milestone: M003
slice: S01
project: csvexport
created: 2026-11-10T08:30:00Z
status: planned
task_count: 1
completed_tasks: 0
---
# M003-S01 -- Slice Plan

**Goal:** JSON output option.

## Tasks

- [ ] T01 -- The export gets an option to write JSON instead of CSV

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.
EOF
cat > .ytstack/ROADMAP.md <<'EOF'
# Roadmap

| Milestone | Goal | Status |
|---|---|---|
| M001 | A user gets their rows out of the data file as CSV | done |
| M002 | The export shows what a user works with, and can be limited to what changed lately | done |
| M003 | Programs can read the export: JSON as a second output format | in-progress |
EOF
cat > .ytstack/STATE.md <<'EOF'
---
project: csvexport
last_updated: 2026-11-10T09:00:00Z
current_milestone: M003
active_slice: S01
active_task: none
---
# State

**Status (2026-11-10):** M003 (JSON as a second output format) is sliced: S01 with one task, T01, which is not planned yet. M001 and M002 are done.

**Previous status (2026-11-06):** M002 done. S01 closed with T01 and T02; the export takes `--since <date>`. `bash tests/run.sh` prints `6 tests passed`.

**Previous status (2026-11-05):** M002 / S01 -- 1/2 tasks done. T01 closed, T02 (`--since`) is planned.

**Previous status (2026-11-03):** M001 done. `bash src/export.sh <user>` prints the header line and every row of the user, archived rows included; the export is a complete copy. `bash tests/run.sh` prints `3 tests passed`.

## Next action

Plan T01 of M003 / S01 (the export gets an option to write JSON instead of CSV), then execute it.
EOF
commit 2026-11-10T09:00:00Z "chore: plan and slice M003 (JSON output)"

# Summaries carry the time their task closed (the newest three are listed at session start).
touch -t 202611021200 .ytstack/M001-S01-T01-SUMMARY.md
touch -t 202611031130 .ytstack/M001-S01-T02-SUMMARY.md
touch -t 202611051130 .ytstack/M002-S01-T01-SUMMARY.md
touch -t 202611061130 .ytstack/M002-S01-T02-SUMMARY.md
git status >/dev/null
