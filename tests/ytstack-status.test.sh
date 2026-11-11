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
( cd "$D" && git add -A && GIT_COMMITTER_DATE="2099-01-01T00:00:00Z" git commit -qm "main state 8" ) >/dev/null 2>&1
git -C "$C" fetch -q origin 2>/dev/null
state "$C" M003 S01 T05 ''
eq "clone on a topic branch: newer origin/main wins" "0|V2 80% 8/10 · M003/S01/T05" "$(seg "$C")"

# slice count without a block: belongs to the local pointer, so it is read
# from the checkout even off the default branch (a slice executed in a
# worktree flips its checkboxes there first)
E=$(new_repo slicewt); state "$E" M003 S01 T03; commit "$E" seed
EW="$TMP/slicewt-wt"; git -C "$E" worktree add -q -b slice-work "$EW" >/dev/null 2>&1
printf -- '---\nmilestone: M003\nslice: S01\n---\n# plan\n\n- [x] T01 -- one\n- [x] T02 -- two\n- [x] T03 -- three\n- [ ] T04 -- four\n- [ ] T05 -- five\n' > "$EW/.ytstack/M003-S01-PLAN.md"
state "$EW" M003 S01 T04
eq "linked worktree, no block: slice count is local" "0|M003/S01/T04 3/5" "$(seg "$EW")"
eq "main checkout keeps its own count"               "0|M003/S01/T03 2/5" "$(seg "$E")"

# no default branch at all: working tree
N="$TMP/nodef"; mkdir -p "$N/.ytstack"
( cd "$N" && git init -q -b trunk && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
state "$N" M003 none none "$BLOCK"; commit "$N" seed
eq "no main/master/origin: working tree"    "0|V2 76% 138/180 · M003" "$(seg "$N")"

# no git at all
G="$TMP/nogit"; mkdir -p "$G/.ytstack"; state "$G" M003 none none "$BLOCK"
eq "not a git repository: working tree"     "0|V2 76% 138/180 · M003" "$(seg "$G")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
