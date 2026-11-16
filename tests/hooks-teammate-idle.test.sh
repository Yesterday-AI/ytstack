#!/usr/bin/env bash
# Tests for the TeammateIdle hook (issues #97, #98).
#
#   - counts only the lane's own scope: the LANES.md row the teammate holds
#     (claimed or running), else an M###-S##[-T##] ref in its name; never the
#     STATE pointer's milestone, never a done, dropped, shipped-informally or
#     backlog milestone, never one outside the held lanes when LANES.md has any
#   - no scope known, no session id, a reported row: silent
#   - said once per teammate, scope and count (<session home>/<sid>/idle-said)
#   - writes nothing into the checkout
#
# Run: /bin/bash tests/hooks-teammate-idle.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/teammate-idle"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3' in: $2";; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "found '$3' in: $2";; *) ok "$1";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytidle.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"
unset CLAUDE_PLUGIN_DATA PLUGIN_DATA 2>/dev/null
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
jstr() { printf '%s' "$1" | jq -Rs .; }

# The issue's shape: STATE points at an old open milestone M034 with 13 open
# tasks; the lanes were dispatched for M046.
MAIN="$TMP/main"; Y="$MAIN/.ytstack"; mkdir -p "$Y/milestones/M046"
( cd "$MAIN" || exit 2; git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  printf 'current_milestone: M034\nactive_slice: S01\nactive_task: T01\n' > .ytstack/STATE.md
  printf -- '---\nmilestone: M034\nstatus: in-progress\n---\n- [ ] S01\n' > .ytstack/M034-ROADMAP.md
  { printf -- '---\nslice: S01\n---\n'; for i in 01 02 03 04 05 06 07 08 09 10 11 12 13; do printf -- '- [ ] T%s -- old\n' "$i"; done; } > .ytstack/M034-S01-PLAN.md
  printf -- '---\nmilestone: M046\nstatus: in-progress\n---\n- [ ] S01\n- [ ] S02\n' > .ytstack/milestones/M046/M046-ROADMAP.md
  printf -- '---\nslice: S01\n---\n- [x] T01 -- a\n- [x] T02 -- b\n- [ ] T03 -- c\n' > .ytstack/milestones/M046/M046-S01-PLAN.md
  printf -- '---\nslice: S02\n---\n- [ ] T01 -- d\n- [ ] T02 -- e\n' > .ytstack/milestones/M046/M046-S02-PLAN.md
  printf -- '---\nmilestone: M040\nstatus: done\n---\n' > .ytstack/M040-ROADMAP.md
  printf -- '---\nslice: S01\n---\n- [ ] T01 -- left over\n' > .ytstack/M040-S01-PLAN.md
  printf -- '---\nslice: S03\n---\n- [ ] T01 -- f\n' > .ytstack/milestones/M046/M046-S03-PLAN.md
  cat > .ytstack/LANES.md <<'EOF'
---
updated: 2026-11-16T10:00:00Z
---

# Lanes

| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M046-S01-T02 | implement | running | lane-done 2026-11-16T09:00Z | b1 | - | - | - | 0 | - |
| M046-S02 | implement | running | lane-s02 2026-11-16T09:00Z | b2 | - | - | - | 0 | - |
| M046-S01-T03 | implement | claimed | lane-t03 2026-11-16T09:00Z | b3 | - | - | - | 0 | - |
| M046-S01 | implement | reported | lane-rep 2026-11-16T09:00Z | b4 | - | - | - | 0 | - |
| M040-S01 | implement | running | lane-old 2026-11-16T09:00Z | b5 | - | - | - | 0 | - |
| review-pr-12 | review | running | lane-review 2026-11-16T09:00Z | - | - | 12 | - | 0 | - |
EOF
  git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }

# idle <teammate> [session]: fire once; EC and ERR hold the result
idle() {
  printf '{"session_id":"%s","cwd":%s,"hook_event_name":"TeammateIdle","teammate_name":"%s","team_name":"session-x"}' "${2:-s1}" "$(jstr "${CWD:-$MAIN}")" "$1" \
    | ( cd "$ELSEWHERE" && CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" >/dev/null 2>"$TMP/err" ); EC=$?
  ERR=$(cat "$TMP/err")
}

echo "# #97/#98: the lane's own task is done, an unrelated milestone is open"
idle lane-done; eq "own task done -> exit 0" 0 "$EC"; eq "own task done -> silent" "" "$ERR"
idle nobody; eq "no lane scope -> exit 0" 0 "$EC"; eq "no lane scope -> silent, M034 not counted" "" "$ERR"
idle lane-review; eq "a lane outside the plan (review-pr-12) -> silent" "" "$ERR"
idle lane-rep; eq "a reported lane -> silent" "" "$ERR"
idle lane-old; eq "a lane in a done milestone -> silent" "" "$ERR"

echo "# the useful case: the held slice still has open tasks"
idle lane-s02; eq "held slice with open tasks -> exit 2" 2 "$EC"
has "names the count" "$ERR" "2 task(s) still open"; has "names the lane" "$ERR" "M046-S02"
lacks "never names M034" "$ERR" "M034"
idle lane-s02; eq "#98: the same idle again -> exit 0" 0 "$EC"; eq "#98: said once" "" "$ERR"
idle lane-s02; eq "#98: a third idle -> silent" "" "$ERR"
printf -- '---\nslice: S02\n---\n- [x] T01 -- d\n- [ ] T02 -- e\n' > "$Y/milestones/M046/M046-S02-PLAN.md"
idle lane-s02; eq "progress, still open -> said again" 2 "$EC"; has "the new count" "$ERR" "1 task(s) still open"
idle lane-s02; eq "and then once only" "" "$ERR"
printf -- '---\nslice: S02\n---\n- [ ] T01 -- d\n- [ ] T02 -- e\n' > "$Y/milestones/M046/M046-S02-PLAN.md"
idle lane-s02; eq "2 -> 1 -> 2: the count differs from the last said one -> said again" 2 "$EC"
idle lane-s02; eq "and once only again" "" "$ERR"
idle lane-s02 s2; eq "another session -> said again" 2 "$EC"
idle lane-t03; eq "held task still open -> exit 2" 2 "$EC"; has "task lane counts one" "$ERR" "1 task(s) still open in M046-S01-T03"

echo "# team mode: no row, the ref in the teammate name"
idle impl-M046-S03 s3; eq "name names an unclaimed slice of a held milestone -> exit 2" 2 "$EC"; has "its count" "$ERR" "1 task(s) still open in M046-S03"
idle impl-M046-S02 s3; eq "review: the named slice is held by another teammate -> silent" "" "$ERR"
idle impl-M046-S01 s3; eq "review: the named slice has a row (reported) -> silent" "" "$ERR"
idle impl-M046-S03-x s5; eq "a ref followed by a non-word character counts" 2 "$EC"
idle impl-M046-S031 s5; eq "review: M046-S031 is no ref to M046-S03 -> silent" "" "$ERR"
idle impl-M034-S01 s3; eq "name outside the held lanes' milestones -> silent" "" "$ERR"
mv "$Y/LANES.md" "$TMP/LANES.md"
idle impl-M034-S01 s3; eq "no LANES.md: the named slice counts" 2 "$EC"; has "its count" "$ERR" "13 task(s) still open in M034-S01"
printf -- '---\nmilestone: M034\nstatus: backlog\n---\n' > "$Y/M034-ROADMAP.md"
idle impl-M034-S01 s4; eq "a backlog milestone -> silent" "" "$ERR"
idle impl-M040-S01 s4; eq "a done milestone -> silent" "" "$ERR"
mv "$TMP/LANES.md" "$Y/LANES.md"
printf -- '---\nmilestone: M034\nstatus: in-progress\n---\n- [ ] S01\n' > "$Y/M034-ROADMAP.md"
printf -- '---\nslice: S02\n---\n- [ ] T01 -- d\n- [ ] T02 -- e\n' > "$Y/milestones/M046/M046-S02-PLAN.md"

echo "# a linked worktree reads the main checkout's LANES.md (its own copy is stale)"
git -C "$MAIN" worktree add -q --detach "$TMP/wt" HEAD >/dev/null 2>&1 || { echo FATAL worktree; exit 2; }
cp "$Y/LANES.md" "$TMP/LANES.keep"
printf '| M046-S03 | implement | running | lane-wt 2026-11-16T11:00Z | b6 | - | - | - | 0 | - |\n' >> "$Y/LANES.md"
CWD="$TMP/wt" idle lane-wt s6; eq "review: the claim in the main checkout counts" 2 "$EC"; has "its lane" "$ERR" "in M046-S03"
CWD="$TMP/wt" idle impl-M046-S03 s6; eq "review: and the row there silences another teammate" "" "$ERR"
cp "$TMP/LANES.keep" "$Y/LANES.md"

echo "# guards"
printf '{"cwd":%s,"hook_event_name":"TeammateIdle","teammate_name":"lane-s02"}' "$(jstr "$MAIN")" \
  | ( cd "$ELSEWHERE" && bash "$HOOK" >/dev/null 2>"$TMP/err" ); EC=$?
eq "no session id -> exit 0" 0 "$EC"; eq "no session id -> silent" "" "$(cat "$TMP/err")"
printf '{"session_id":"s9","cwd":%s,"hook_event_name":"TeammateIdle"}' "$(jstr "$MAIN")" \
  | ( cd "$ELSEWHERE" && bash "$HOOK" >/dev/null 2>"$TMP/err" ); EC=$?
eq "no teammate name -> silent" "" "$(cat "$TMP/err")"
eq "checkout untouched" "" "$(git -C "$MAIN" status --porcelain)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
