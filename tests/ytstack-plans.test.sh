#!/usr/bin/env bash
# Tests for bin/ytstack-plans: a plan outside .ytstack/ (format and thresholds:
# docs/ux/external-plans.md).
#
# Contract:
#   scan   one line per candidate directory with plan files: files, open, done,
#          verdict (large at >= 10 open rows, YTSTACK_PLAN_MIN_OPEN overrides)
#          and the answer recorded in PREFERENCES.md; exit 0 only when a large
#          directory has no answer yet; "no external plan" and exit 1 otherwise
#   rows   path:line, state, id, section, title per work row; the line number
#          points at the row; --open keeps the open ones
#   work   task-list items and rows of tables with a status or checkbox column;
#          a table without one and anything in a code fence is not counted
#   read   the plan files are byte-identical after every call
#   usage  unknown command or a -C that is no directory: exit 64
#
# Run: /bin/bash tests/ytstack-plans.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-plans"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-plans exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytplans.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
TAB='	'

run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t )
  printf -- '---\nproject: acme\ncurrent_milestone: none\n---\n\n# State\n' > "$d/.ytstack/STATE.md"
  echo "$d"
}
sums() { find "$1" -type f -name '*.md' | sort | while read -r f; do cksum "$f"; done; }

echo "== no plan directory"
R=$(new_repo empty)
run "$R" scan
eq "no plan -> exit 1" 1 "$EC"
has "no plan -> says so" "no external plan" "$OUT"

echo "== a large plan in plans/"
R=$(new_repo big)
mkdir -p "$R/plans/sub" "$R/notes"
{
  printf '# v2 work packages\n\n## Board\n\n'
  printf '| Done | ID | Deliverable | Gate | State |\n| --- | --- | --- | --- | --- |\n'
  printf '| [x] | AV-01 | Toolchain bump | E | Merged #12 |\n'
  printf '| [x] | AV-02 | Contract emit | E | Merged #13 |\n'
  i=3; while [ $i -le 10 ]; do printf '| [ ] | AV-%02d | Package %d | AV-01 | open |\n' $i $i; i=$((i+1)); done
  printf '\n## Comparison\n\n| Option | Cost |\n|---|---|\n| A | 1 |\n| B | 2 |\n| C | 3 |\n'
  printf '\n```markdown\n- [ ] not a task, inside a fence\n| [ ] | AV-99 | fenced | x | open |\n```\n'
} > "$R/plans/2026-10-29-v2-packages.md"
{
  printf '# Teardown\n\n## Steps\n\n'
  printf -- '- [ ] Remove the old bucket\n- [x] Snapshot the data\n* [ ] Switch DNS\n+ [X] Announce\n'
} > "$R/plans/sub/teardown.md"
printf '# Ideas\n\n- [ ] one\n- [ ] two\n' > "$R/plans/ideas.md"
{
  printf '# Status table\n\n| Step | Status |\n|---|---|\n| Migrate | done |\n| Backfill | Superseded by AV-04 |\n| Verify | in progress |\n| Cut over | ✅ |\n'
} > "$R/plans/status.md"
printf -- '- [ ] a\n- [ ] b\n- [ ] c\n- [ ] d\n- [ ] e\n- [ ] f\n- [ ] g\n- [ ] h\n- [ ] i\n- [ ] j\n- [ ] k\n' > "$R/notes/todo.md"
BEFORE=$(sums "$R/plans")
run "$R" scan
eq "large, unanswered -> exit 0" 0 "$EC"
# open: 8 (table) + 2 (teardown) + 1 (status: in progress) = 11; ideas.md has 2 rows (< 3, no plan file)
# done: 2 + 2 + 2 = 6
has "dir line" "dir=plans files=3 open=11 done=6 verdict=large answer=none" "$OUT"
hasnt "notes/ is no candidate directory" "notes" "$OUT"

run "$R" rows
has "rows: table row with id, section, title" "plans/2026-10-29-v2-packages.md:9${TAB}open${TAB}AV-03${TAB}Board${TAB}Package 3" "$OUT"
has "rows: done row" "${TAB}done${TAB}AV-01${TAB}Board${TAB}Toolchain bump" "$OUT"
has "rows: task item without id" "plans/sub/teardown.md:5${TAB}open${TAB}-${TAB}Steps${TAB}Remove the old bucket" "$OUT"
has "rows: capital X is done" "${TAB}done${TAB}-${TAB}Steps${TAB}Announce" "$OUT"
has "rows: superseded is dropped" "${TAB}dropped${TAB}-${TAB}Status table${TAB}Backfill" "$OUT"
has "rows: check mark is done" "${TAB}done${TAB}-${TAB}Status table${TAB}Cut over" "$OUT"
hasnt "rows: fenced content skipped" "AV-99" "$OUT"
hasnt "rows: fenced task skipped" "inside a fence" "$OUT"
hasnt "rows: table without status column skipped" "Comparison" "$OUT"
hasnt "rows: file below 3 rows is no plan file" "ideas.md" "$OUT"
# the pointer points at the row
LN=$(printf '%s\n' "$OUT" | awk -F'\t' '$3 == "AV-07" { split($1, a, ":"); print a[2] }')
has "rows: line number points at the row" "AV-07" "$(sed -n "${LN:-0}p" "$R/plans/2026-10-29-v2-packages.md")"

run "$R" rows --open
hasnt "rows --open: no done rows" "${TAB}done${TAB}" "$OUT"
hasnt "rows --open: no dropped rows" "${TAB}dropped${TAB}" "$OUT"
N=$(printf '%s\n' "$OUT" | grep -c .)
eq "rows --open: 11 open rows" 11 "$N"

OUT=$(cd "$R" && bash "$BIN" rows plans/ideas.md 2>&1)
has "rows PATH: an explicit file is listed even below 3 rows" "plans/ideas.md:3${TAB}open${TAB}-${TAB}Ideas${TAB}one" "$OUT"
# A relative PATH is read from where the command was started (PR #66 review).
OUT=$(cd "$R/plans" && bash "$BIN" rows ideas.md 2>&1); EC=$?
has "rows PATH from a subdirectory: the file next to the caller" "plans/ideas.md:3${TAB}open${TAB}-${TAB}Ideas${TAB}one" "$OUT"
OUT=$(cd "$R/plans" && bash "$BIN" rows sub/ 2>&1)
has "rows DIR from a subdirectory" "plans/sub/teardown.md:5${TAB}open" "$OUT"
OUT=$(cd "$R/plans/sub" && bash "$BIN" rows plans/ideas.md 2>&1)
has "rows PATH not there from the caller: read from the repository root, as scan names it" "plans/ideas.md:3${TAB}open" "$OUT"
OUT=$(bash "$BIN" -C "$R" rows "$R/plans/ideas.md" 2>&1)
eq "rows with an absolute PATH and -C: relative to the repository in the output" "plans/ideas.md:3" "$(printf '%s\n' "$OUT" | head -1 | cut -f1)"

eq "plan files unchanged" "$BEFORE" "$(sums "$R/plans")"

echo "== thresholds and answers"
R2=$(new_repo small)
mkdir -p "$R2/docs/plans"
printf '# Small\n\n- [ ] a\n- [ ] b\n- [ ] c\n- [x] d\n' > "$R2/docs/plans/small.md"
run "$R2" scan
eq "small -> exit 1" 1 "$EC"
has "small -> verdict small" "dir=docs/plans files=1 open=3 done=1 verdict=small answer=none" "$OUT"
OUT=$(YTSTACK_PLAN_MIN_OPEN=3 bash "$BIN" -C "$R2" scan 2>&1); EC=$?
eq "YTSTACK_PLAN_MIN_OPEN=3 -> exit 0" 0 "$EC"
has "YTSTACK_PLAN_MIN_OPEN=3 -> large" "verdict=large" "$OUT"

printf '# Preferences\n\nexternal_plans: plans declined 2026-11-15\n' > "$R/.ytstack/PREFERENCES.md"
run "$R" scan
eq "declined -> exit 1" 1 "$EC"
has "declined -> reported" "verdict=large answer=declined" "$OUT"
printf '# Preferences\n\nexternal_plans: docs/plans declined 2026-11-15\nexternal_plans: plans mapped 2026-11-15\n' > "$R/.ytstack/PREFERENCES.md"
run "$R" scan
eq "mapped -> exit 1" 1 "$EC"
has "mapped -> reported per directory" "answer=mapped" "$OUT"

echo "== from a subdirectory and usage"
OUT=$(cd "$R/plans/sub" && bash "$BIN" scan 2>&1); EC=$?
has "runs from a subdirectory of the repository" "dir=plans files=3" "$OUT"
run "$R" frobnicate
eq "unknown command -> 64" 64 "$EC"
OUT=$(bash "$BIN" -C "$TMP/nope" scan 2>&1); EC=$?
eq "-C to a missing directory -> 64" 64 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
