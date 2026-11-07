#!/usr/bin/env bash
# Tests for the advisory Stop hook (M019-S04).
#
#   - active task without summary -> systemMessage reminder, exit 0
#   - active task with a draft stub  -> reminder
#   - active task with a real summary -> silent
#   - no active task / no .ytstack / stop_hook_active true -> silent
#   - resolves from payload cwd (worktree), never writes anything
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
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytstop.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
jstr() { printf '%s' "$1" | jq -Rs .; }

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2; git init -q && git config user.email t@t.t && git config user.name t
  printf 'current_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > .ytstack/STATE.md
  echo seed > f; git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }

fire() { # fire <cwd> [extra-json]
  printf '{"session_id":"s","cwd":%s,"hook_event_name":"Stop"%s}' "$(jstr "$1")" "${2:-}" \
    | ( cd "$ELSEWHERE" && CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" 2>"$TMP/err" ); EC=$?
}

echo "# active task without summary"
OUT=$(fire "$MAIN"); eq "exit 0" 0 "$?"
has "reminder names the task"   "$OUT" "M042-S03-T07"
has "reminder is a systemMessage JSON" "$OUT" '"systemMessage"'
if printf '%s' "$OUT" | jq -e .systemMessage >/dev/null 2>&1; then ok "valid JSON"; else bad "valid JSON" "$OUT"; fi
eq "git status clean" "" "$(git -C "$MAIN" status --porcelain)"

echo "# draft stub"
printf -- '---\nclosed: draft\n---\n' > "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"
OUT=$(fire "$MAIN"); has "draft stub -> reminder" "$OUT" "draft summary stub"

echo "# real summary"
printf -- '---\nclosed: 2026-11-07T00:00:00Z\n---\n' > "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"
OUT=$(fire "$MAIN"); eq "real summary -> silent" "" "$OUT"
rm -f "$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"

echo "# guards"
OUT=$(fire "$MAIN" ',"stop_hook_active":true'); eq "stop_hook_active -> silent" "" "$OUT"
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
OUT=$(fire "$WT"); eq "worktree with summary -> silent (resolved from cwd, not main)" "" "$OUT"
OUT=$(fire "$MAIN"); has "main without summary -> reminder" "$OUT" "M042-S03-T07"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
