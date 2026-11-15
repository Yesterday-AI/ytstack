#!/usr/bin/env bash
# Tests for bin/ytstack-status (M021-S01-T02, issue #31).
#
# Contract:
#   - one compact segment on stdout for the directory in the status line JSON
#     (`cwd`), falling back to $PWD; exit 0 only when something was printed
#   - with a `progress` block: label, percentage, done/total, task pointer,
#     truncated waiting_on; without it: pointer plus the active slice's
#     checkbox count
#   - plan progress from the default branch when the checkout is on another
#     branch (linked worktree), task pointer always local
#   - nothing outside a ytstack project and nothing for a malformed block
#   - colour by default, none with NO_COLOR or --no-color
#   - --phases (issue #81): done / in review / total per roadmap that is not
#     dropped and in total; a changed total names its cause, and every change
#     goes to a log under the plugin data dir, never into the tree; --json
#
# Run: /bin/bash tests/ytstack-status.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-status"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-status exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytstatus.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"

# seg <dir> [args/env...]: "<exit code>|<stdout>" with the dir passed as JSON cwd
seg() {
  local d="$1" out ec; shift
  out=$(cd "$ELSEWHERE" && printf '{"cwd":"%s","workspace":{"current_dir":"%s"},"model":{"display_name":"x"}}' "$d" "$d" | env -u NO_COLOR "$@" bash "$BIN" --no-color 2>/dev/null); ec=$?
  printf '%s|%s' "$ec" "$out"
}

# state <dir> <milestone> <slice> <task> [progress block lines]
state() {
  printf -- '---\nproject: fx\nlast_updated: 2026-01-01T00:00:00Z\ncurrent_milestone: %s\nactive_slice: %s\nactive_task: %s\n%b---\n# State\n' "$2" "$3" "$4" "${5:-}" > "$1/.ytstack/STATE.md"
}
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
  printf -- '---\nmilestone: M003\nslice: S01\n---\n# plan\n\n- [x] T01 -- one\n- [X] T02 -- two\n- [ ] T03 -- three\n- [ ] T04 -- four\n- [ ] T05 -- five\n\n## Notes\n\n- [ ] not a task\n' > "$d/.ytstack/M003-S01-PLAN.md"
  echo "$d"
}
commit() { ( cd "$1" && git add -A && git commit -qm "$2" ) >/dev/null 2>&1; }
BLOCK='progress:\n  label: V2\n  done: 138\n  total: 180\n'

# ---- 1. outside a ytstack project -------------------------------------------
echo "# outside a project"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
eq "plain dir: no output, exit 1"           "1|" "$(seg "$PLAIN")"
eq "missing dir: no output, exit 1"         "1|" "$(seg "$TMP/does-not-exist")"

# ---- 2. fallback: slice checkbox count ---------------------------------------
echo "# no progress block"
R=$(new_repo main)
state "$R" M003 S01 T03
commit "$R" seed
eq "pointer + slice count"                  "0|M003/S01/T03 2/5" "$(seg "$R")"
mkdir -p "$R/src/deep"
eq "subdirectory resolves to the project"   "0|M003/S01/T03 2/5" "$(seg "$R/src/deep")"
state "$R" M003 S01 none
eq "no active task: slice count only"       "0|M003/S01 2/5" "$(seg "$R")"
state "$R" M003 S02 T01
eq "slice plan missing: pointer alone"      "0|M003/S02/T01" "$(seg "$R")"
state "$R" M003 none none
eq "milestone only"                         "0|M003" "$(seg "$R")"
state "$R" none none none
eq "nothing to show: no output, exit 1"     "1|" "$(seg "$R")"
mkdir -p "$R/.ytstack/milestones/M003"; git -C "$R" mv .ytstack/M003-S01-PLAN.md .ytstack/milestones/M003/ 2>/dev/null
state "$R" M003 S01 T03
eq "slice plan under milestones/M003/"      "0|M003/S01/T03 2/5" "$(seg "$R")"

# ---- 3. progress block -------------------------------------------------------
echo "# progress block"
state "$R" M003 S01 T03 "$BLOCK"
eq "label, percentage, done/total, pointer" "0|V2 76% 138/180 · M003/S01/T03" "$(seg "$R")"
state "$R" none none none "$BLOCK"
eq "block without pointer"                  "0|V2 76% 138/180" "$(seg "$R")"
state "$R" M003 S01 T03 "${BLOCK}  waiting_on: \"review of PR 12\"\n"
eq "waiting_on shown"                       "0|V2 76% 138/180 · M003/S01/T03 · waiting: review of PR 12" "$(seg "$R")"
state "$R" M003 S01 T03 "${BLOCK}  waiting_on: the operator has to approve the budget for phase three\n"
eq "waiting_on truncated to 32 characters"  "0|V2 76% 138/180 · M003/S01/T03 · waiting: the operator has to approve the …" "$(seg "$R")"
state "$R" M003 S01 T03 'progress:\n  label: V2\n  done: 7\n  total: 7\n'
eq "complete: 100%"                         "0|V2 100% 7/7 · M003/S01/T03" "$(seg "$R")"
state "$R" M003 S01 T03 'progress:\n  label: V2\n  done: 179\n  total: 180\n'
eq "percentage rounds down (never 100% early)" "0|V2 99% 179/180 · M003/S01/T03" "$(seg "$R")"
state "$R" M003 S01 T03 'progress:\n  label: V2\n  done: 9\n  total: 7\n'
eq "malformed block: no output, exit 1"     "1|" "$(seg "$R")"

# ---- 4. input handling -------------------------------------------------------
echo "# input"
state "$R" M003 S01 T03 "$BLOCK"
WANT="V2 76% 138/180 · M003/S01/T03"
eq "no stdin JSON: falls back to PWD"       "$WANT" "$(cd "$R" && bash "$BIN" --no-color </dev/null)"
eq "garbage on stdin: falls back to PWD"    "$WANT" "$(cd "$R" && echo 'not json' | bash "$BIN" --no-color)"
eq "JSON without cwd: falls back to PWD"    "$WANT" "$(cd "$R" && echo '{"model":{}}' | bash "$BIN" --no-color)"
SP="$TMP/with space"; cp -R "$R" "$SP"
eq "path with a space"                      "0|$WANT" "$(seg "$SP")"
ESC=$(printf '\033')
case "$(cd "$R" && env -u NO_COLOR bash "$BIN" </dev/null)" in *"$ESC["*) ok "colour by default";; *) bad "colour by default";; esac
case "$(cd "$R" && NO_COLOR=1 bash "$BIN" </dev/null)" in *"$ESC"*) bad "NO_COLOR disables colour";; "$WANT") ok "NO_COLOR disables colour";; *) bad "NO_COLOR output";; esac
case "$(cd "$R" && env -u NO_COLOR bash "$BIN" --no-color </dev/null)" in *"$ESC"*) bad "--no-color disables colour";; *) ok "--no-color disables colour";; esac

# ---- 5. default branch vs. working tree --------------------------------------
echo "# default branch"
D=$(new_repo def)
state "$D" M003 S01 T02 'progress:\n  label: V2\n  done: 5\n  total: 10\n'
commit "$D" "main state"
state "$D" M003 S01 T02 'progress:\n  label: V2\n  done: 6\n  total: 10\n'
eq "on the default branch: working tree wins" "0|V2 60% 6/10 · M003/S01/T02" "$(seg "$D")"
commit "$D" "main state 6"
WT="$TMP/def-wt"; git -C "$D" worktree add -q -b feature "$WT" >/dev/null 2>&1
state "$WT" M003 S01 T04 'progress:\n  label: V2\n  done: 3\n  total: 10\n'
eq "linked worktree: plan from main, pointer local" "0|V2 60% 6/10 · M003/S01/T04" "$(seg "$WT")"
state "$WT" M003 S01 T04 'progress:\n  label: V2\n  done: 99\n  total: 10\n'
eq "linked worktree: local block is not read"       "0|V2 60% 6/10 · M003/S01/T04" "$(seg "$WT")"
state "$D" M003 S01 T02 'progress:\n  label: V2\n  done: 99\n  total: 10\n'; commit "$D" "broken on main"
state "$WT" M003 S01 T04 'progress:\n  label: V2\n  done: 3\n  total: 10\n'
eq "linked worktree: malformed block on main prints nothing" "1|" "$(seg "$WT")"
state "$D" M003 S01 T02 'progress:\n  label: V2\n  done: 7\n  total: 10\n'; commit "$D" "main state 7"
( cd "$WT" && git checkout -q --detach ) 2>/dev/null
eq "detached HEAD: plan from main"          "0|V2 70% 7/10 · M003/S01/T04" "$(seg "$WT")"

# clone: origin/HEAD names the default branch; origin/main is newer than local main
C="$TMP/clone"; git clone -q "$D" "$C" 2>/dev/null
( cd "$C" && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false && git checkout -q -b topic )
state "$D" M003 S01 T02 'progress:\n  label: V2\n  done: 8\n  total: 10\n'
# The refs are compared by ancestry, not by committer date: the origin commit
# is ahead but carries an older timestamp (equal timestamps tie the same way).
( cd "$D" && git add -A && GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" git commit -qm "main state 8" ) >/dev/null 2>&1
git -C "$C" fetch -q origin 2>/dev/null
state "$C" M003 S01 T05 ''
eq "clone on a topic branch: origin/main ahead wins" "0|V2 80% 8/10 · M003/S01/T05" "$(seg "$C")"
( cd "$C" && git checkout -q -f main && git merge -q --ff-only origin/main ) >/dev/null 2>&1
state "$C" M003 S01 T02 'progress:\n  label: V2\n  done: 9\n  total: 10\n'
( cd "$C" && git add -A && GIT_COMMITTER_DATE="1999-01-01T00:00:00Z" git commit -qm "local main state 9, unpushed" && git checkout -q topic ) >/dev/null 2>&1
state "$C" M003 S01 T05 ''
eq "clone on a topic branch: unpushed local main wins" "0|V2 90% 9/10 · M003/S01/T05" "$(seg "$C")"

# slice count without a block: same source rule as the block. Off the default
# branch the slice plan is read from the default ref (PR #32 review); the
# checkout's copy is used only for a slice plan that does not exist there yet.
E=$(new_repo slicewt); state "$E" M003 S01 T03; commit "$E" seed
EW="$TMP/slicewt-wt"; git -C "$E" worktree add -q -b slice-work "$EW" >/dev/null 2>&1
printf -- '---\nmilestone: M003\nslice: S01\n---\n# plan\n\n- [x] T01 -- one\n- [x] T02 -- two\n- [x] T03 -- three\n- [ ] T04 -- four\n- [ ] T05 -- five\n' > "$EW/.ytstack/M003-S01-PLAN.md"
state "$EW" M003 S01 T04
eq "linked worktree, no block: slice count from main, pointer local" "0|M003/S01/T04 2/5" "$(seg "$EW")"
eq "main checkout: its own working tree"                             "0|M003/S01/T03 2/5" "$(seg "$E")"
printf -- '---\nmilestone: M003\nslice: S02\n---\n# plan\n\n- [x] T01 -- one\n- [ ] T02 -- two\n' > "$EW/.ytstack/M003-S02-PLAN.md"
state "$EW" M003 S02 T02
eq "slice plan only in the worktree: local count"                    "0|M003/S02/T02 1/2" "$(seg "$EW")"
mkdir -p "$E/.ytstack/milestones/M003"; git -C "$E" mv .ytstack/M003-S01-PLAN.md .ytstack/milestones/M003/; commit "$E" "nested layout"
state "$EW" M003 S01 T04; rm -f "$EW/.ytstack/M003-S01-PLAN.md"
eq "slice plan under milestones/M003/ on main"                       "0|M003/S01/T04 2/5" "$(seg "$EW")"

# no default branch at all: working tree
N="$TMP/nodef"; mkdir -p "$N/.ytstack"
( cd "$N" && git init -q -b trunk && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
state "$N" M003 none none "$BLOCK"; commit "$N" seed
eq "no main/master/origin: working tree"    "0|V2 76% 138/180 · M003" "$(seg "$N")"

# no git at all
G="$TMP/nogit"; mkdir -p "$G/.ytstack"; state "$G" M003 none none "$BLOCK"
eq "not a git repository: working tree"     "0|V2 76% 138/180 · M003" "$(seg "$G")"

# ---- 6. --phases: progress per milestone, the denominator log out of tree ---
echo "# phases"
export CLAUDE_PLUGIN_DATA="$TMP/data"
TAB='	'
# road <dir> <M###> <status> <slice lines...>: "x S01" checked, "- S02" open
road() {
  local f="$1/.ytstack/$2-ROADMAP.md" s; printf -- '---\nmilestone: %s\nstatus: %s\n---\n\n# %s Roadmap\n\n## Slices\n\n' "$2" "$3" "$2" > "$f"; shift 3
  for s in "$@"; do case "$s" in x\ *) echo "- [x] ${s#x } -- goal" ;; *) echo "- [ ] ${s#- } -- goal" ;; esac; done >> "$f"
}
# ph <dir> [args]: OUT and EC of --phases, run from elsewhere
ph() { local d="$1"; shift; OUT=$(cd "$ELSEWHERE" && bash "$BIN" --phases -C "$d" "$@" </dev/null 2>&1); EC=$?; }
P=$(new_repo phases); state "$P" M004 none none
# M003 is done with a checkbox left open: a done milestone counts every slice
road "$P" M003 done "x S01" "- S02"
road "$P" M004 active "x S01" "- S02" "- S03" "- S04"
road "$P" M005 dropped "- S01"
road "$P" M007 backlog "- S01" "- S02"
printf -- '---\nupdated: 2026-11-15T10:00:00Z\n---\n\n# Lanes\n\n| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |\n|---|---|---|---|---|---|---|---|---|---|\n| M004-S02 | implement | merged | w 2026-11-15T08:00Z | - | - | 3 | abc1234 | 1 | - |\n| M004-S03 | implement | in-review | w 2026-11-15T09:00Z | - | - | 4 | - | 1 | - |\n' > "$P/.ytstack/LANES.md"
ph "$P"
eq "--phases: exit 0" 0 "$EC"
eq "one line per phase, dropped and backlog left out, done counts all, the total, the read line" \
"M003${TAB}2/2 done (100%)${TAB}0 in review
M004${TAB}2/4 done (50%)${TAB}1 in review
total${TAB}4/6 done (66%)${TAB}1 in review" "$(printf '%s\n' "$OUT" | sed '$d')"
LOG=$(find "$TMP/data" -name denominator.log | head -1)
like() { if printf '%s\n' "$3" | grep -E -- "$2" >/dev/null; then ok "$1"; else bad "$1" "no line matches /$2/ in: $3"; fi; }
like "the last line: read time and the log" "^read [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z, log .*/repos/[0-9a-f]+/phases/denominator.log\$" "$OUT"
case "$LOG" in "$TMP/data/repos/"*) ok "the log lives in the plugin data dir, keyed by repository" ;; *) bad "log location" "$LOG" ;; esac
eq "the first report logs each phase once" "M003 - 2 first report|M004 - 4 first report" "$(awk -F'\t' '{ printf "%s%s %s %s %s", (NR > 1 ? "|" : ""), $2, $3, $4, $5 }' "$LOG")"
eq "nothing is written into the tree" "" "$(git -C "$P" status --porcelain --untracked-files=all | grep -v -e LANES.md -e ROADMAP.md -e STATE.md -e PLAN.md)"
road "$P" M004 active "x S01" "- S02" "- S03" "- S05" "- S06"
ph "$P"
eq "a changed denominator is named with its cause" \
"M004${TAB}2/5 done (40%)${TAB}1 in review${TAB}total 4 -> 5 since the last report: added S05, S06; removed S04" "$(printf '%s\n' "$OUT" | grep '^M004')"
eq "the total carries the change too" "total${TAB}4/7 done (57%)${TAB}1 in review${TAB}total 6 -> 7 since the last report" "$(printf '%s\n' "$OUT" | grep '^total')"
eq "and the log has one line for it" "M004 4 5 added S05, S06; removed S04" "$(awk -F'\t' 'END { print $2, $3, $4, $5 }' "$LOG")"
ph "$P"
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }
hasnt "no change: no change shown" "since the last report" "$OUT"
eq "and nothing logged" 3 "$(awk 'END { print NR }' "$LOG")"
# Same total (7): M006 joins with 2 slices, M003 (2) leaves as dropped
road "$P" M006 planned "- S01" "- S02"; road "$P" M003 dropped "x S01" "x S02"
ph "$P"
eq "a new phase and a dropped one are logged" "M006 - 2 new phase|M003 2 - phase left the report" "$(awk -F'\t' 'NR > 3 { printf "%s%s %s %s %s", (NR > 4 ? "|" : ""), $2, $3, $4, $5 }' "$LOG")"
eq "the new phase is named on its line" "M006${TAB}0/2 done (0%)${TAB}0 in review${TAB}new since the last report" "$(printf '%s\n' "$OUT" | grep '^M006')"
eq "the phase that left has a line" "M003${TAB}left the report since the last report (was 2 rows)" "$(printf '%s\n' "$OUT" | grep '^M003')"
eq "the total names both, also when it stays equal" "total${TAB}2/7 done (28%)${TAB}1 in review${TAB}total 7 -> 7 since the last report; joined M006; left M003" "$(printf '%s\n' "$OUT" | grep '^total')"
road "$P" M006 backlog "- S01" "- S02"
ph "$P"
eq "a phase parked on the backlog leaves the report" "M006${TAB}left the report since the last report (was 2 rows)" "$(printf '%s\n' "$OUT" | grep '^M006')"
road "$P" M006 planned "- S01" "- S02"
ph "$P"
if command -v jq >/dev/null 2>&1; then
  road "$P" M004 active "x S01" "- S02" "- S03" "- S05" "- S06" "- S07"
  road "$P" M008 planned "- S01"
  ph "$P" --json
  eq "--json: exit 0" 0 "$EC"
  J='(.phases[] | "\(.phase) \(.status) \(.done) \(.in_review) \(.total) \(.percent) \(if .change then "\(.change.before) \(.change.added | join(",")) \(.change.joined)" else "null" end)"), "\(.total.done) \(.total.in_review) \(.total.total) \(.total.percent // "null") \(.total.change.before) \(.total.change.joined | join(","))"'
  WANT="M004 active 2 1 6 33 5 S07 false|M006 planned 0 0 2 0 null|M008 planned 0 0 1 0 0 S01 true|2 1 9 22 7 M008"
  eq "--json: phases, counts, the change and a joined phase" "$WANT" "$(printf '%s' "$OUT" | jq -r "$J" | paste -sd'|' -)"
  case "$(printf '%s' "$OUT" | jq -r '.read + " " + .log')" in 20*" $LOG") ok "--json: read time and log path" ;; *) bad "--json: read and log" "$OUT" ;; esac
  LINES=$(awk 'END { print NR }' "$LOG")
  ph "$P" --json
  eq "--json does not use up the change: a second --json shows it again" "$WANT" "$(printf '%s' "$OUT" | jq -r "$J" | paste -sd'|' -)"
  eq "and logs nothing" "$LINES" "$(awk 'END { print NR }' "$LOG")"
  road "$P" M006 dropped "- S01" "- S02"
  ph "$P" --json
  eq "--json: a phase that left" "M006 2" "$(printf '%s' "$OUT" | jq -r '.left[] | "\(.phase) \(.before)"')"
  road "$P" M006 planned "- S01" "- S02"
  ph "$P"
  ph "$P" --json
  eq "after a text report the change is used up" "null" "$(printf '%s' "$OUT" | jq -r '.total.change')"
else
  ok "--json: skipped, no jq"
fi
# Concurrent text reports: the log gets each change once, no temporary or lock file stays
road "$P" M004 active "x S01" "- S02" "- S03" "- S05" "- S06" "- S07" "- S09"
B4=$(awk 'END { print NR }' "$LOG")
for i in 1 2 3 4 5 6; do ( cd "$ELSEWHERE" && bash "$BIN" --phases -C "$P" >/dev/null 2>&1 ) & done; wait
eq "six reports at once log the change once" "$((B4 + 1))" "$(awk 'END { print NR }' "$LOG")"
eq "and leave only the snapshot and the log" "denominator.log snapshot" "$(ls "$(dirname "$LOG")" | paste -sd' ' -)"
N2=$(new_repo noroad); state "$N2" none none none
ph "$N2"
eq "no roadmap: exit 1" 1 "$EC"
ph "$TMP/plain"
eq "no .ytstack: exit 1" 1 "$EC"
OUT=$(bash "$BIN" --phases --bogus 2>&1); EC=$?
eq "unknown option: exit 64" 64 "$EC"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
