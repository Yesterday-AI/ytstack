#!/usr/bin/env bash
# Tests for bin/ytstack-frontier: the frontier of a milestone and the claims in
# LANES.md (format: docs/ux/coordinator-format.md).
#
# Contract:
#   list     per slice done / claimed / blocked / ready from the roadmap
#            checkboxes, the "**Blocked by:**" line of the slice plans and
#            LANES.md; --ready prints the ready lanes and exits 1 without one;
#            the milestone comes from STATE.md, else the highest open roadmap
#   claim    creates LANES.md with the ten columns; a held lane is refused with
#            the holder's name, exit 1, nothing written; a blocked, dropped or
#            merged row needs a release first
#   set      changes the named cells of one row, every other row stays
#            byte-identical, "updated:" is rewritten
#   release  "Claimed by" becomes "-", status "dropped" unless "merged"
#   check    a well-formed file passes; each defect is named, exit 1
#   refused  a value with "|" or a newline, and usage errors: exit 64
#
# Run: /bin/bash tests/ytstack-frontier.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-frontier"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-frontier exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytfrontier.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
TAB='	'

# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }

# new_repo <name> <current_milestone>: a repository with .ytstack/STATE.md
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
  printf -- '---\nproject: acme\ncurrent_milestone: %s\nactive_slice: none\n---\n\n# State\n' "$2" > "$d/.ytstack/STATE.md"
  echo "$d"
}
# roadmap <repo> <M###> <status> <slice lines...>: "x S01" is a checked slice, "- S02" an open one
roadmap() {
  local d="$1/.ytstack" m="$2" st="$3" s; shift 3
  {
    printf -- '---\nmilestone: %s\nstatus: %s\n---\n\n# %s Roadmap\n\n## Slices\n\n' "$m" "$st" "$m"
    for s in "$@"; do
      case "$s" in x\ *) printf -- '- [x] %s -- goal\n' "${s#x }" ;; *) printf -- '- [ ] %s -- goal\n' "${s#- }" ;; esac
    done
  } > "$d/$m-ROADMAP.md"
}
# plan <repo> <M###-S##> [blocked-by line]: a slice plan; without the third argument it has no "Blocked by" line
plan() {
  {
    printf -- '---\nstatus: planned\n---\n\n# %s -- Slice Plan\n\n**Goal:** something works\n\n' "$2"
    [ $# -lt 3 ] || printf '**Blocked by:** %s\n\n' "$3"
    printf '## Tasks\n\n- [ ] T01 -- do it\n'
  } > "$1/.ytstack/$2-PLAN.md"
}
# The example of the format document.
EXAMPLE='---
updated: 2026-11-13T10:42:00Z
---

# Lanes

| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M004-S01 | implement | merged | impl-M004-S01 2026-11-13T08:10Z | ytstack/M004-S01 | - | 11 | a1b2c3d | 1 | - |
| M004-S02 | implement | running | impl-M004-S02 2026-11-13T10:02Z | ytstack/M004-S02 | .claude/worktrees/m004-s02 | - | - | 0 | wait for the report |'
lanes() { printf '%s\n' "$EXAMPLE" > "$1/.ytstack/LANES.md"; }
# rowof <repo> <lane>: the lane's line in LANES.md
rowof() { grep "^| $2 |" "$1/.ytstack/LANES.md"; }

# ---- 1. list ------------------------------------------------------------------
echo "# list"
R=$(new_repo list M004)
roadmap "$R" M004 in-progress "x S01" "- S02" "- S03" "- S04" "- S05"
plan "$R" M004-S02 none
plan "$R" M004-S03 "S01, S02"
plan "$R" M004-S04 "S01 (needs the schema)"
plan "$R" M004-S05
run "$R" list
eq "five slices: exit 0" 0 "$EC"
eq "one line per slice, tab separated: lane, state, detail" "M004-S01${TAB}done
M004-S02${TAB}ready
M004-S03${TAB}blocked${TAB}S02
M004-S04${TAB}ready
M004-S05${TAB}ready" "$OUT"
run "$R"
has "list is the default command" "M004-S03${TAB}blocked${TAB}S02" "$OUT"
run "$R" --ready
eq "--ready: exit 0 with a ready lane" 0 "$EC"
eq "--ready: exactly the ready lanes, one per line" "M004-S02
M004-S04
M004-S05" "$OUT"
# a question for the human that names a lane keeps it out of the frontier until it is answered
mkdir -p "$R/.ytstack/questions"
printf -- '---\nid: Q001\nstate: asked\ndecides: the operator\nblocks: M004-S05, G02\n---\n\n# Q001 -- x\n' > "$R/.ytstack/questions/Q001-x.md"
printf -- '---\nid: Q002\nstate: answered\ndecides: the operator\nblocks: S04\n---\n\n# Q002 -- y\n' > "$R/.ytstack/questions/Q002-y.md"
run "$R" list
has "an asked question blocks the lane it names" "M004-S05${TAB}blocked${TAB}question Q001" "$OUT"
has "an answered question blocks nothing" "M004-S04${TAB}ready" "$OUT"
rm -f "$R/.ytstack/questions/Q001-x.md" "$R/.ytstack/questions/Q002-y.md"; rmdir "$R/.ytstack/questions"

roadmap "$R" M004 in-progress "x S01" "x S02" "- S03" "- S04" "- S05"
run "$R" list
has "a done blocker unblocks" "M004-S03${TAB}ready" "$OUT"

plan "$R" M004-S03 "S04, S05"
run "$R" list
has "every open blocker is named" "M004-S03${TAB}blocked${TAB}S04, S05" "$OUT"
plan "$R" M004-S03 "M004-S04"
run "$R" list
has "a blocker may carry the milestone prefix" "M004-S03${TAB}blocked${TAB}S04" "$OUT"
plan "$R" M004-S03 "S09"
run "$R" list
has "a blocker that is no slice of the milestone keeps the lane blocked" "M004-S03${TAB}blocked${TAB}S09" "$OUT"

# a slice without a plan has no edges to read: it waits for the slices before it
rm "$R/.ytstack/M004-S04-PLAN.md"
run "$R" list
has "an unplanned slice behind an open one is blocked" "M004-S04${TAB}blocked${TAB}S03 (unplanned)" "$OUT"
roadmap "$R" M004 in-progress "x S01" "x S02" "x S03" "- S04" "- S05"
run "$R" list
has "an unplanned slice that nothing can block is ready, and says so" "M004-S04${TAB}ready${TAB}unplanned" "$OUT"

roadmap "$R" M004 in-progress "x S01" "x S02" "x S03" "x S04" "x S05"
run "$R" --ready
eq "--ready without a ready lane: exit 1" 1 "$EC"
eq "and prints nothing" "" "$OUT"

# which milestone
roadmap "$R" M005 planned "- S01"
roadmap "$R" M006 "done" "x S01"
roadmap "$R" M007 dropped "- S01"
run "$R" list --milestone M005
eq "--milestone names the roadmap" "M005-S01${TAB}ready${TAB}unplanned" "$OUT"
printf -- '---\nproject: acme\ncurrent_milestone: none\n---\n' > "$R/.ytstack/STATE.md"
run "$R" list
eq "current_milestone none: the highest roadmap that is still open" "M005-S01${TAB}ready${TAB}unplanned" "$OUT"
mkdir -p "$R/.ytstack/milestones/M008"
mv "$R/.ytstack/M005-ROADMAP.md" "$R/.ytstack/milestones/M008/M008-ROADMAP.md"
plan "$R" M008-S01; mv "$R/.ytstack/M008-S01-PLAN.md" "$R/.ytstack/milestones/M008/"
run "$R" list
eq "roadmap and plan under milestones/M###/ are found" "M008-S01${TAB}ready" "$OUT"
run "$R" list --milestone M009
eq "no roadmap for the milestone: exit 1" 1 "$EC"
has "names the file it looked for" "M009-ROADMAP.md" "$OUT"
rm -r "$R/.ytstack/milestones"; rm "$R/.ytstack/M004-ROADMAP.md"
run "$R" list
eq "no open milestone: exit 1" 1 "$EC"
has "and says so" "no milestone" "$OUT"

# ---- 2. claim -----------------------------------------------------------------
echo "# claim"
R=$(new_repo claim M004)
roadmap "$R" M004 in-progress "- S01" "- S02" "- S03"
plan "$R" M004-S01; plan "$R" M004-S02; plan "$R" M004-S03 "S01"
L="$R/.ytstack/LANES.md"
run "$R" claim M004-S02 --by impl-M004-S02 --kind implement --branch ytstack/M004-S02 --worktree .claude/worktrees/m004-s02
eq "the first claim: exit 0" 0 "$EC"
eq "it creates LANES.md with the ten columns in the documented order" \
  "| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |" "$(grep '^|' "$L" | head -1)"
eq "a separator line under the header" "|---|---|---|---|---|---|---|---|---|---|" "$(grep '^|' "$L" | sed -n 2p)"
eq "frontmatter first" "---" "$(head -1 "$L")"
has "the title" "# Lanes" "$(cat "$L")"
case "$(sed -n 2p "$L")" in
  "updated: "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ok "updated: carries the UTC time of the write" ;;
  *) bad "updated: carries the UTC time of the write" "$(sed -n 2p "$L")" ;;
esac
ROW=$(rowof "$R" M004-S02)
case "$ROW" in
  "| M004-S02 | implement | claimed | impl-M004-S02 "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]"Z | ytstack/M004-S02 | .claude/worktrees/m004-s02 | - | - | 0 | - |") ok "the row: status claimed, worker and UTC time, branch, worktree" ;;
  *) bad "the row: status claimed, worker and UTC time, branch, worktree" "$ROW" ;;
esac
run "$R" check
eq "the created file passes check" "lanes ok" "$OUT"
run "$R" list
has "a claimed slice is listed as claimed, with the holder" "M004-S02${TAB}claimed${TAB}impl-M004-S02 20" "$OUT"
run "$R" --ready
eq "and is not ready any more" "M004-S01" "$OUT"

cp "$L" "$TMP/before"
run "$R" claim M004-S02 --by second-worker
eq "a second claim: exit 1" 1 "$EC"
has "names the holder" "M004-S02 is held by impl-M004-S02 since 20" "$OUT"
if cmp -s "$L" "$TMP/before"; then ok "and writes nothing"; else bad "and writes nothing"; fi

run "$R" claim M004-S01 --by impl-M004-S01
eq "kind defaults to implement, branch and worktree to -" "| M004-S01 | implement | claimed | - | - | - | - | 0 | - |" \
  "$(rowof "$R" M004-S01 | sed 's/ impl-M004-S01 [^|]*|//')"
eq "the new row goes under the last one" "M004-S02,M004-S01," "$(grep '^| M' "$L" | sed 's/^| \([^ ]*\) .*/\1/' | tr '\n' ',')"
run "$R" claim review-pr-12 --by rev-1 --kind review
eq "a lane outside the milestone plan can be claimed" 0 "$EC"
has "with its kind" "| review-pr-12 | review | claimed | rev-1 " "$(rowof "$R" review-pr-12)"

for S in running reported in-review ready; do
  run "$R" set M004-S02 --status "$S"
  run "$R" claim M004-S02 --by second-worker
  eq "status $S holds the lane" 1 "$EC"
done
for S in merged blocked dropped; do
  run "$R" set M004-S02 --status "$S"
  run "$R" claim M004-S02 --by second-worker
  eq "a $S row is not claimed again without a release" 1 "$EC"
  has "and the refusal says so ($S)" "release M004-S02" "$OUT"
done
run "$R" release M004-S02
run "$R" claim M004-S02 --by second-worker --kind prepare
eq "after the release the lane is claimed again" 0 "$EC"
has "by the new worker, branch and worktree kept" "| M004-S02 | prepare | claimed | second-worker " "$(rowof "$R" M004-S02)"
has "branch and worktree kept" "| ytstack/M004-S02 | .claude/worktrees/m004-s02 |" "$(rowof "$R" M004-S02)"
eq "still one row per lane" 1 "$(grep -c '^| M004-S02 |' "$L")"

# several claims sent at once: every row arrives
R=$(new_repo parallel M004)
for N in 1 2 3 4 5 6; do bash "$BIN" -C "$R" claim "lane-$N" --by "w-$N" >/dev/null 2>&1 & done
wait
eq "six claims at the same time: six rows" 6 "$(grep -c '^| lane-' "$R/.ytstack/LANES.md")"
run "$R" check
eq "and a well-formed file" "lanes ok" "$OUT"
if [ -e "$R/.ytstack/LANES.md.lock" ] || [ -e "$R/.ytstack/LANES.md.tmp" ]; then bad "no lock and no temporary file left behind"; else ok "no lock and no temporary file left behind"; fi

# ---- 3. set -------------------------------------------------------------------
echo "# set"
R=$(new_repo set M004); lanes "$R"; L="$R/.ytstack/LANES.md"
run "$R" set M004-S02 --status reported --next "verify the slice" --pr 12 --head d4e5f6a --round 1 --branch work/s02 --worktree wt/s02
eq "set: exit 0" 0 "$EC"
eq "the named cells of the row" "| M004-S02 | implement | reported | impl-M004-S02 2026-11-13T10:02Z | work/s02 | wt/s02 | 12 | d4e5f6a | 1 | verify the slice |" "$(rowof "$R" M004-S02)"
eq "every other line is byte-identical" "$(printf '%s\n' "$EXAMPLE" | grep -v '^| M004-S02 |' | grep -v '^updated:')" \
  "$(grep -v '^| M004-S02 |' "$L" | grep -v '^updated:')"
case "$(sed -n 2p "$L")" in
  "updated: 2026-11-13T10:42:00Z") bad "updated: is rewritten" ;;
  "updated: "20*Z) ok "updated: is rewritten" ;;
  *) bad "updated: is rewritten" "$(sed -n 2p "$L")" ;;
esac
run "$R" set M004-S02 --next "wait for the review"
eq "one option changes one cell" "| M004-S02 | implement | reported | impl-M004-S02 2026-11-13T10:02Z | work/s02 | wt/s02 | 12 | d4e5f6a | 1 | wait for the review |" "$(rowof "$R" M004-S02)"
run "$R" set M004-S02 --pr ""
has "an empty value clears the cell" "| wt/s02 | - | d4e5f6a |" "$(rowof "$R" M004-S02)"
for S in claimed running reported in-review ready merged blocked dropped; do
  run "$R" set M004-S02 --status "$S"
  eq "--status $S is accepted" "0 $S" "$EC $(rowof "$R" M004-S02 | awk -F' [|] ' '{ print $3 }')"
done
cp "$L" "$TMP/before"
run "$R" set M004-S02 --status finished
eq "a status the format does not list: exit 64" 64 "$EC"
run "$R" set M004-S09 --status running
eq "a lane without a row: exit 1" 1 "$EC"
has "names the lane" "M004-S09 has no row" "$OUT"
run "$R" set M004-S02;                 eq "set without a cell: exit 64" 64 "$EC"
run "$R" set M004-S02 --kind review;   eq "set does not change the kind: exit 64" 64 "$EC"
if cmp -s "$L" "$TMP/before"; then ok "a refused set writes nothing"; else bad "a refused set writes nothing"; fi
R2=$(new_repo setnone M004)
run "$R2" set M004-S01 --status running
eq "set without LANES.md: exit 1" 1 "$EC"
[ ! -e "$R2/.ytstack/LANES.md" ] && ok "and creates no file" || bad "and creates no file"

# ---- 4. release ---------------------------------------------------------------
echo "# release"
R=$(new_repo release M004); lanes "$R"; L="$R/.ytstack/LANES.md"
roadmap "$R" M004 in-progress "- S01" "- S02" "- S03"
plan "$R" M004-S02; plan "$R" M004-S03 "S01"
run "$R" list
eq "a merged row counts as done, an open checkbox is named" "M004-S01${TAB}done${TAB}merged, roadmap checkbox open
M004-S02${TAB}claimed${TAB}impl-M004-S02 2026-11-13T10:02Z
M004-S03${TAB}ready" "$OUT"
run "$R" release M004-S02
eq "release: exit 0" 0 "$EC"
eq "Claimed by becomes -, the status dropped" "| M004-S02 | implement | dropped | - | ytstack/M004-S02 | .claude/worktrees/m004-s02 | - | - | 0 | wait for the report |" "$(rowof "$R" M004-S02)"
eq "the other row is byte-identical" "$(printf '%s\n' "$EXAMPLE" | grep '^| M004-S01 |')" "$(rowof "$R" M004-S01)"
run "$R" list
has "a released lane is ready again" "M004-S02${TAB}ready" "$OUT"
run "$R" set M004-S02 --status running
eq "a released lane is not set to a held status: exit 1" 1 "$EC"
has "claim comes first" "claim it before" "$OUT"
run "$R" release M004-S01
eq "a merged lane stays merged" "| M004-S01 | implement | merged | - | ytstack/M004-S01 | - | 11 | a1b2c3d | 1 | - |" "$(rowof "$R" M004-S01)"
run "$R" release M004-S09
eq "release of a lane without a row: exit 1" 1 "$EC"
run "$R" claim M004-S03 --by impl-M004-S03
run "$R" set M004-S03 --status blocked --next "waits for Q007"
run "$R" list
has "a blocked row is listed as blocked, with what it waits for" "M004-S03${TAB}blocked${TAB}lane: waits for Q007" "$OUT"

# ---- 5. check -----------------------------------------------------------------
echo "# check"
R=$(new_repo check M004); L="$R/.ytstack/LANES.md"
run "$R" check
eq "no LANES.md: exit 0" 0 "$EC"
eq "and says so" "no lanes file" "$OUT"
lanes "$R"
run "$R" check
eq "the example of the format document: exit 0" 0 "$EC"
eq "and says so" "lanes ok" "$OUT"
# defect <name> <expected line> <sed expression on the example>
defect() {
  printf '%s\n' "$EXAMPLE" | sed "$3" > "$L"
  run "$R" check
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC: $OUT"; fi
}
defect "a missing column" "line 7: the header is not the ten columns" 's/ Round |//'
defect "columns in another order" "line 7: the header is not the ten columns" 's/| Kind | Status |/| Status | Kind |/'
defect "no separator line" "line 8: no separator line under the header" '8d'
defect "a lane twice" "M004-S01: more than one row" 's/^| M004-S02 /| M004-S01 /'
defect "a status that is not listed" 'M004-S02: status "working" is not one of' 's/| running |/| working |/'
defect "a kind that is not listed" 'M004-S02: kind "fix" is not one of' '10s/| implement |/| fix |/'
defect "a held lane without a holder" 'M004-S02: status running without a holder and a claim time ("-")' 's/| impl-M004-S02 [^|]*|/| - |/'
defect "a held lane without a claim time" 'M004-S02: status running without a holder and a claim time ("impl-M004-S02")' 's/| impl-M004-S02 [^|]*|/| impl-M004-S02 |/'
defect "a row with a cell too many" "line 10: 11 cells, expected 10" 's/wait for the report/wait | for the report/'
defect "a row with a cell too few" "line 10: 9 cells, expected 10" '10s/ 0 |//'
defect "a row without a lane" "line 10: no lane" '10s/^| M004-S02 /| /'
printf -- '---\nupdated: 2026-11-13T10:42:00Z\n---\n\n# Lanes\n' > "$L"
run "$R" check
eq "a file without a table: exit 1" "1 no lanes table" "$EC $OUT"
printf '%s\n' "$EXAMPLE" | sed 's/| running |/| working |/; s/^| M004-S02 /| M004-S01 /' > "$L"
run "$R" check
eq "one line per problem" 2 "$(printf '%s\n' "$OUT" | grep -c .)"
printf '%s\n' "$EXAMPLE" | sed 's/ Round |//' > "$L"
run "$R" claim M004-S03 --by impl-M004-S03
eq "no write into a table that is not in the format: exit 1" 1 "$EC"
has "points at check" "ytstack-frontier check" "$OUT"

# ---- 6. refused values and usage ----------------------------------------------
echo "# refused"
R=$(new_repo refused M004); lanes "$R"; L="$R/.ytstack/LANES.md"
cp "$L" "$TMP/before"
run "$R" set M004-S02 --next "a | b";            eq "a | in a value: exit 64" 64 "$EC"
has "says why" "must not contain '|' or a newline" "$OUT"
run "$R" set M004-S02 --next "a
b";                                              eq "a newline in a value: exit 64" 64 "$EC"
run "$R" claim "M004|S03" --by w;                eq "a | in the lane: exit 64" 64 "$EC"
run "$R" claim M004-S03 --by "w|x";              eq "a | in the worker: exit 64" 64 "$EC"
run "$R" claim M004-S03;                         eq "claim without --by: exit 64" 64 "$EC"
run "$R" claim --by w;                           eq "claim without a lane: exit 64" 64 "$EC"
run "$R" claim M004-S03 --by w --kind fix;       eq "a kind the format does not list: exit 64" 64 "$EC"
run "$R" claim M004-S03 --by;                    eq "option without a value: exit 64" 64 "$EC"
run "$R" claim M004-S03 --by w --force yes;      eq "unknown option: exit 64" 64 "$EC"
run "$R" release;                                eq "release without a lane: exit 64" 64 "$EC"
run "$R" release M004-S02 now;                   eq "release with an extra argument: exit 64" 64 "$EC"
run "$R" check now;                              eq "check with an argument: exit 64" 64 "$EC"
run "$R" list --milestone M4;                    eq "malformed milestone: exit 64" 64 "$EC"
run "$R" list --all;                             eq "unknown list option: exit 64" 64 "$EC"
run "$R" publish;                                eq "unknown command: exit 64" 64 "$EC"
run "$TMP/nowhere" list;                         eq "-C to a missing directory: exit 64" 64 "$EC"
if cmp -s "$L" "$TMP/before"; then ok "none of them wrote to LANES.md"; else bad "none of them wrote to LANES.md"; fi
mkdir -p "$TMP/bare"
run "$TMP/bare" list;                            eq "list without .ytstack: exit 1" 1 "$EC"
run "$TMP/bare" claim x --by w;                  eq "claim without .ytstack: exit 1" 1 "$EC"
run "$TMP/bare" check;                           eq "check without .ytstack: no lanes file" "0 no lanes file" "$EC $OUT"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
