#!/usr/bin/env bash
# Concurrency + idempotency acceptance for the writing hooks (M016-S03-T02,
# issue #26 "concurrent handoffs cannot overwrite one another").
#
#   - two sessions interleaved on the same worktree keep separate state
#   - latest-handoff points at the session that compacted last
#   - a parallel burst of five sessions leaves five dirs, one valid symlink,
#     no temp link leftovers
#   - journals are per session, valid JSON, append-only
#   - the summary stub is created once however often the hook fires
#   - the checkout stays byte-identical throughout
#
# Run: /bin/bash tests/hooks-concurrency.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
H="$ROOT/hooks"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytcc.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
PD="$TMP/plugin-data"; ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
jstr() { printf '%s' "$1" | jq -Rs .; }

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2
  git init -q && git config user.email t@t.t && git config user.name t
  printf 'project: fixture\ncurrent_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > .ytstack/STATE.md
  printf 'name: fixture\n' > .ytstack/PROJECT.md
  printf -- '---\nkind: handoff\nevent: user-triggered\n---\n# manual\n' > .ytstack/HANDOFF.md
  echo seed > f.txt; git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }
H_SHA=$(shasum -a 256 "$MAIN/.ytstack/HANDOFF.md" | cut -c1-16)
K=$( ( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$MAIN" >/dev/null; printf '%s/worktrees/%s' "$YT_REPO_KEY" "$YT_WT_KEY" ) )
WTD="$PD/repos/$K"

fire() { # fire <hook> <session> [extra-json]
  printf '{"session_id":"%s","cwd":%s,"hook_event_name":"%s"%s}' "$2" "$(jstr "$MAIN")" "$1" "${3:-}" \
    | ( cd "$ELSEWHERE" && CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$H/$1" >/dev/null 2>&1 )
}
latest() { readlink "$WTD/latest-handoff" 2>/dev/null; }

# ---- interleaved sessions ---------------------------------------------------
echo "# interleaved"
fire pre-compact s1 ',"trigger":"auto"'
fire pre-compact s2 ',"trigger":"auto"'
fire session-end s1 ',"reason":"clear"'
fire session-end s2 ',"reason":"clear"'
fire pre-compact s1 ',"trigger":"manual"'
fire session-end s2 ',"reason":"other"'
for s in s1 s2; do
  [ -f "$WTD/sessions/$s/HANDOFF.auto.md" ] && ok "$s: own auto handoff" || bad "$s: own auto handoff"
  eq "$s: handoff carries its session id" "$s" "$(sed -n 's/^session_id: *//p' "$WTD/sessions/$s/HANDOFF.auto.md" 2>/dev/null | head -1)"
done
eq "latest-handoff -> s1 (compacted last)" "$WTD/sessions/s1/HANDOFF.auto.md" "$(latest)"
eq "s1: trigger of the latest write recorded" manual "$(sed -n 's/^trigger: *//p' "$WTD/sessions/s1/HANDOFF.auto.md" | head -1)"
eq "s1 journal: 1 line" 1 "$(wc -l < "$WTD/sessions/s1/session.jsonl" | tr -d ' ')"
eq "s2 journal: 2 lines" 2 "$(wc -l < "$WTD/sessions/s2/session.jsonl" | tr -d ' ')"
if jq -e . "$WTD/sessions/s2/session.jsonl" >/dev/null 2>&1; then ok "s2 journal: every line valid JSON"; else bad "s2 journal: every line valid JSON"; fi
eq "s2 journal: last reason is other" other "$(jq -r .reason "$WTD/sessions/s2/session.jsonl" | tail -1)"

# ---- parallel burst ----------------------------------------------------------
echo "# parallel burst"
for s in p1 p2 p3 p4 p5; do fire pre-compact "$s" ',"trigger":"auto"' & done; wait
for s in p1 p2 p3 p4 p5; do fire session-end "$s" ',"reason":"clear"' & done; wait
eq "burst: five session dirs with handoffs" 5 "$(ls "$WTD"/sessions/p*/HANDOFF.auto.md 2>/dev/null | wc -l | tr -d ' ')"
eq "burst: five journals"                   5 "$(ls "$WTD"/sessions/p*/session.jsonl 2>/dev/null | wc -l | tr -d ' ')"
L=$(latest)
case "$L" in "$WTD"/sessions/p*/HANDOFF.auto.md) ok "burst: latest-handoff points at one burst session";; *) bad "burst: latest-handoff points at one burst session" "$L";; esac
[ -f "$WTD/latest-handoff" ] && ok "burst: latest-handoff resolves to an existing file" || bad "burst: latest-handoff resolves"
eq "burst: no temp link leftovers" 0 "$(ls -a "$WTD" | grep -c '^\.latest-handoff\.')"
BAD_JSON=0; for f in "$WTD"/sessions/p*/session.jsonl; do jq -e . "$f" >/dev/null 2>&1 || BAD_JSON=$((BAD_JSON+1)); done
eq "burst: all journals valid JSON" 0 "$BAD_JSON"

# ---- stub idempotency --------------------------------------------------------
echo "# stub idempotency"
( cd "$MAIN" && echo a > a && git add a && git commit -qm "M042-S03-T07: add a" ) >/dev/null 2>&1
for i in 1 2 3; do fire post-tool-use-bash s1 ',"tool_input":{"command":"git commit -m x"},"tool_response":{"exit_code":0}'; done
STUB="$MAIN/.ytstack/M042-S03-T07-SUMMARY.md"
[ -f "$STUB" ] && ok "stub: created" || bad "stub: created"
S1=$(shasum -a 256 "$STUB" | cut -c1-16)
( cd "$MAIN" && echo b > b && git add b && git commit -qm "M042-S03-T07: add b" ) >/dev/null 2>&1
fire post-tool-use-bash s2 ',"tool_input":{"command":"git commit -m x"},"tool_response":{"exit_code":0}'
eq "stub: unchanged after further commits/sessions" "$S1" "$(shasum -a 256 "$STUB" | cut -c1-16)"
eq "stub: exactly one summary file" 1 "$(ls "$MAIN"/.ytstack/*-SUMMARY.md | wc -l | tr -d ' ')"

# ---- tree hygiene ------------------------------------------------------------
echo "# hygiene"
eq "HANDOFF.md untouched" "$H_SHA" "$(shasum -a 256 "$MAIN/.ytstack/HANDOFF.md" | cut -c1-16)"
eq "git status shows only the (untracked) stub" "?? .ytstack/M042-S03-T07-SUMMARY.md" "$(git -C "$MAIN" status --porcelain)"
[ -e "$MAIN/.ytstack/journal" ] && bad "no .ytstack/journal" || ok "no .ytstack/journal"
[ -e "$ELSEWHERE/.ytstack" ] && bad "nothing under bogus CLAUDE_PROJECT_DIR" || ok "nothing under bogus CLAUDE_PROJECT_DIR"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
