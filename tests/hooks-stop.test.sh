#!/usr/bin/env bash
# Tests for the advisory Stop hook (M019-S04, issue #82).
#
#   - active task without summary -> systemMessage reminder, exit 0
#   - active task with a draft stub  -> reminder
#   - active task with a real summary -> silent
#   - no active task / no .ytstack / stop_hook_active true -> silent
#   - resolves from payload cwd (worktree), never writes into the checkout
#   - a reminder is said once per (session, pointer); a coordinate session
#     (the marker) gets none; a pointer older than YT_POINTER_STALE_DAYS is
#     left to the STATE lint line (W10)
#   - on the default branch behind origin/<default> (local refs): one message
#     with the count and the pointer origin's STATE.md has, once per origin head
#
# Run: /bin/bash tests/hooks-stop.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/stop"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3' in: $2";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytstop.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"
unset CLAUDE_PLUGIN_DATA PLUGIN_DATA 2>/dev/null
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
jstr() { printf '%s' "$1" | jq -Rs .; }

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2; git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  printf 'current_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > .ytstack/STATE.md
  echo seed > f; git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }

# fire <cwd> [extra-json]: the session id is $SID (a new one per case: a
# reminder is said once per session and pointer)
fire() {
  printf '{"session_id":"%s","cwd":%s,"hook_event_name":"Stop"%s}' "${SID:-s}" "$(jstr "$1")" "${2:-}" \
    | ( cd "$ELSEWHERE" && CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" 2>"$TMP/err" ); EC=$?
}

echo "# active task without summary"
SID=s1; OUT=$(fire "$MAIN"); eq "exit 0" 0 "$?"
has "reminder names the task"   "$OUT" "M042-S03-T07"
has "reminder is a systemMessage JSON" "$OUT" '"systemMessage"'
if printf '%s' "$OUT" | jq -e .systemMessage >/dev/null 2>&1; then ok "valid JSON"; else bad "valid JSON" "$OUT"; fi
eq "git status clean" "" "$(git -C "$MAIN" status --porcelain)"
OUT=$(fire "$MAIN"); eq "the same session and pointer: said once" "" "$OUT"
SID=s2; OUT=$(fire "$MAIN"); has "another session: said again" "$OUT" "M042-S03-T07"

echo "# draft stub"
printf -- '---\nclosed: draft\n---\n' > "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"
SID=s3; OUT=$(fire "$MAIN"); has "draft stub -> reminder" "$OUT" "draft summary stub"

echo "# real summary"
printf -- '---\nclosed: 2026-11-07T00:00:00Z\n---\n' > "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"
SID=s4; OUT=$(fire "$MAIN"); eq "real summary -> silent" "" "$OUT"
rm -f "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"

echo "# summary in milestones/M042/ (#70)"
mkdir -p "$MAIN/.ytstack/milestones/M042"
printf -- '---\nclosed: 2026-11-07T00:00:00Z\n---\n' > "$MAIN/.ytstack/milestones/M042/M042-S03-T07-SUMMARY.md"
SID=s5; OUT=$(fire "$MAIN"); eq "moved summary -> silent" "" "$OUT"
rm -rf "$MAIN/.ytstack/milestones"

echo "# coordinate session and an old pointer (issue #82)"
mkdir -p "$XDG_STATE_HOME/ytstack/sessions/c1"; printf '%s\n' "$MAIN/.ytstack" > "$XDG_STATE_HOME/ytstack/sessions/c1/coordinate"
SID=c1; OUT=$(fire "$MAIN"); eq "coordinate marker: no task reminder" "" "$OUT"
cp "$MAIN/.ytstack/STATE.md" "$TMP/state.keep"
E5=$(( $(date +%s) - 5 * 86400 ))
printf 'last_updated: %s\n' "$(date -u -r "$E5" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$E5" +%Y-%m-%dT%H:%M:%SZ)" >> "$MAIN/.ytstack/STATE.md"
SID=s6; OUT=$(fire "$MAIN"); eq "a pointer 5 days old: left to the STATE lint, silent" "" "$OUT"
cp "$TMP/state.keep" "$MAIN/.ytstack/STATE.md"

echo "# guards"
SID=s7; OUT=$(fire "$MAIN" ',"stop_hook_active":true'); eq "stop_hook_active -> silent" "" "$OUT"
printf 'current_milestone: M042\nactive_slice: none\nactive_task: none\n' > "$MAIN/.ytstack/STATE.md"
OUT=$(fire "$MAIN"); eq "no active task -> silent" "" "$OUT"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
OUT=$(fire "$PLAIN"); eq "no .ytstack -> silent" "" "$OUT"
[ -e "$ELSEWHERE/.ytstack" ] && bad "nothing under CLAUDE_PROJECT_DIR" || ok "nothing under CLAUDE_PROJECT_DIR"

echo "# worktree resolution"
printf 'current_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > "$MAIN/.ytstack/STATE.md"
( cd "$MAIN" && git add -A && git commit -qm state ) >/dev/null 2>&1
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt "$WT" >/dev/null 2>&1
printf -- '---\nclosed: 2026-11-07T00:00:00Z\n---\n' > "$WT/.ytstack/M042-S03-T07-SUMMARY.md"
SID=s8; OUT=$(fire "$WT"); eq "worktree with summary -> silent (resolved from cwd, not main)" "" "$OUT"
OUT=$(fire "$MAIN"); has "main without summary -> reminder" "$OUT" "M042-S03-T07"

echo "# a checkout behind origin (issue #82)"
O="$TMP/origin.git"; git init -q --bare "$O"
( cd "$MAIN" || exit 2; git branch -M main; git remote add origin "$O"; git push -q -u origin main
  printf 'current_milestone: M050\nactive_slice: S01\nactive_task: T02\n' > .ytstack/STATE.md; git commit -qam next; git push -q origin main
  git checkout -q --detach HEAD~1 && git branch -q -f main HEAD && git checkout -q main ) >/dev/null 2>&1
SID=b1; OUT=$(fire "$MAIN")
has "behind: the count and the ref" "$OUT" "1 commit(s) behind origin/main"
has "behind: the pointer origin has" "$OUT" "M050 / S01 / T02"
case "$OUT" in *"M042-S03-T07 is still the active task"*) bad "behind: no reminder for the stale local pointer";; *) ok "behind: no reminder for the stale local pointer";; esac
OUT=$(fire "$MAIN"); eq "behind: said once per origin head" "" "$OUT"
SID=c1; OUT=$(fire "$MAIN"); has "behind: said in a coordinate session too" "$OUT" "behind origin/main"
# PR #94 review: origin's copy only when strictly behind, origin changed it and there is no local edit
printf 'current_milestone: M044\nactive_slice: S01\nactive_task: T01\n' > "$MAIN/.ytstack/STATE.md"
SID=b2; OUT=$(fire "$MAIN"); has "behind with a local edit: the local pointer" "$OUT" "M044-S01-T01 is still the active task"
case "$OUT" in *"behind origin"*) bad "and no behind message";; *) ok "and no behind message";; esac
( cd "$MAIN" && git commit -qam "local pointer" ) >/dev/null 2>&1
SID=b3; OUT=$(fire "$MAIN"); has "diverged: the local pointer" "$OUT" "M044-S01-T01 is still the active task"
case "$OUT" in *"behind origin"*|*"ff-only"*) bad "diverged: no ff-only message";; *) ok "diverged: no ff-only message";; esac

echo "# user scope behind origin: no behind logic (PR #94 review)"
UH="$TMP/uhome"; U="$TMP/u"; mkdir -p "$UH"; git init -q --bare "$TMP/u.git"
( mkdir -p "$U" && cd "$U" || exit 2; git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  echo a > a && git add a && git commit -qm a && git branch -M main && git remote add origin "$TMP/u.git" && git push -q -u origin main
  echo b > b && git add b && git commit -qm b && git push -q origin main && git checkout -q --detach HEAD~1 && git branch -q -f main HEAD && git checkout -q main ) >/dev/null 2>&1
UK=$(HOME="$UH" bash -c '. "$1/hooks/lib/git-ctx.sh"; yt_git_ctx "$2"; printf %s "$YT_REPO_KEY"' _ "$ROOT" "$U")
mkdir -p "$UH/.ytstack/projects/$UK"; printf 'current_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > "$UH/.ytstack/projects/$UK/STATE.md"
OUT=$(printf '{"session_id":"u1","cwd":%s,"hook_event_name":"Stop"}' "$(jstr "$U")" | HOME="$UH" XDG_STATE_HOME="$XDG_STATE_HOME" bash "$HOOK" 2>/dev/null)
has "user scope: the ordinary reminder" "$OUT" "M042-S03-T07 is still the active task"
case "$OUT" in *"behind"*|*" /  / "*) bad "user scope: no empty origin pointer";; *) ok "user scope: no empty origin pointer";; esac

echo "# old session dirs that only held stop-said are pruned (PR #94 review)"
SHM="$XDG_STATE_HOME/ytstack/sessions"
mkdir -p "$SHM/old1" "$SHM/oldc"; : > "$SHM/old1/stop-said"; : > "$SHM/oldc/stop-said"; : > "$SHM/oldc/coordinate"
mkdir -p "$SHM/oldi" "$SHM/oldb" "$SHM/newi"; : > "$SHM/oldi/idle-said"; : > "$SHM/oldb/idle-said"; : > "$SHM/oldb/stop-said"; : > "$SHM/newi/idle-said"
touch -t 202001010000 "$SHM/old1/stop-said" "$SHM/oldc/stop-said" "$SHM/oldi/idle-said" "$SHM/oldb/idle-said" "$SHM/oldb/stop-said"
SID=fresh2; printf 'current_milestone: M042\nactive_slice: S09\nactive_task: T09\n' > "$WT/.ytstack/STATE.md"; OUT=$(fire "$WT"); has "a new session's reminder" "$OUT" "M042-S09-T09"
eq "an old stop-said-only dir is gone" no "$([ -d "$SHM/old1" ] && echo yes || echo no)"
eq "an old dir with a coordinate marker stays" yes "$([ -d "$SHM/oldc" ] && echo yes || echo no)"
eq "an old idle-said-only dir is gone (teammate-idle)" no "$([ -d "$SHM/oldi" ] && echo yes || echo no)"
eq "an old dir with idle-said and stop-said is gone" no "$([ -d "$SHM/oldb" ] && echo yes || echo no)"
eq "a fresh idle-said dir stays" yes "$([ -d "$SHM/newi" ] && echo yes || echo no)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
