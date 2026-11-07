#!/usr/bin/env bash
# Regression tests for hooks/pre-compact (M016-S01-T02, issues #26/#27).
#
# Contract (DECISIONS 2026-11-07):
#   - The hook resolves its target from the payload `cwd`, never from
#     CLAUDE_PROJECT_DIR (which is pinned to the session-start dir).
#   - The automatic handoff is written OUT OF TREE, per session, with a
#     `latest-handoff` symlink per worktree.
#   - `.ytstack/HANDOFF.md` is user-owned: never overwritten, never created.
#   - stdout (exit 0) carries compaction instructions, < 10,000 chars.
#   - Without a resolvable .ytstack the hook is silent and writes nothing.
#
# Run: /bin/bash tests/pre-compact.test.sh   (exit 0 = all pass)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/pre-compact"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytpc.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
PD="$TMP/plugin-data"
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"   # bogus CLAUDE_PROJECT_DIR

sha() { shasum -a 256 "$1" | cut -c1-16; }

new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack"
  ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t
    printf 'project: fixture\ncurrent_milestone: M042\nactive_slice: S03\nactive_task: T07\n\n# State\n\n## Next action\n\nFinish the widget.\n' > .ytstack/STATE.md
    printf 'name: fixture\n' > .ytstack/PROJECT.md
    printf -- '---\nkind: handoff\nevent: user-triggered\n---\n\n# Hand-written handoff\n\nDo not lose me.\n' > .ytstack/HANDOFF.md
    echo seed > f.txt; git add -A; git commit -qm "seed" )
  echo "$d"
}

# fire <cwd-for-payload|-> <session> [extra-env...]  (stdin payload unless cwd is '-')
fire() {
  local cwd="$1" sess="$2"; shift 2
  if [ "$cwd" = "-" ]; then
    ( cd "$FIRE_PWD" && env CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" "$@" bash "$HOOK" </dev/null )
  else
    printf '{"session_id":"%s","transcript_path":"/x","cwd":"%s","hook_event_name":"PreCompact","trigger":"auto","custom_instructions":null}' "$sess" "$cwd" \
      | ( cd "$ELSEWHERE" && env CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" "$@" bash "$HOOK" )
  fi
}

# key helpers via the lib (the hook's own notion of keys)
keys() { ( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$1" >/dev/null; printf '%s/worktrees/%s' "$YT_REPO_KEY" "$YT_WT_KEY" ); }

# ---- 1. main checkout, committed HANDOFF.md -------------------------------
echo "# main checkout"
MAIN=$(new_repo main)
H_BEFORE=$(sha "$MAIN/.ytstack/HANDOFF.md")
OUT=$(fire "$MAIN" s1); EC=$?
eq "main: exit 0" 0 "$EC"
eq "main: HANDOFF.md byte-identical" "$H_BEFORE" "$(sha "$MAIN/.ytstack/HANDOFF.md")"
eq "main: git status clean" "" "$(git -C "$MAIN" status --porcelain)"
K=$(keys "$MAIN"); AUTO="$PD/repos/$K/sessions/s1/HANDOFF.auto.md"
if [ -f "$AUTO" ]; then ok "main: auto handoff written out-of-tree"; else bad "main: auto handoff written out-of-tree" "$AUTO missing"; fi
eq "main: event: pre-compact"      pre-compact "$(sed -n 's/^event: *//p' "$AUTO" 2>/dev/null | head -1)"
eq "main: session_id recorded"     s1          "$(sed -n 's/^session_id: *//p' "$AUTO" 2>/dev/null | head -1)"
eq "main: milestone from STATE"    M042        "$(sed -n 's/^current_milestone: *//p' "$AUTO" 2>/dev/null | head -1)"
eq "main: worktree recorded"       "$MAIN"     "$(sed -n 's/^worktree: *//p' "$AUTO" 2>/dev/null | head -1)"
LATEST="$PD/repos/$K/latest-handoff"
if [ -L "$LATEST" ] && [ "$(cd "$(dirname "$LATEST")" && cd "$(dirname "$(readlink "$LATEST")")" && pwd -P)/$(basename "$(readlink "$LATEST")")" = "$AUTO" ]; then ok "main: latest-handoff symlink resolves to s1"; else bad "main: latest-handoff symlink resolves to s1" "$(readlink "$LATEST" 2>/dev/null)"; fi
[ -n "$OUT" ] && ok "main: stdout non-empty (compaction instructions)" || bad "main: stdout non-empty"
case "$OUT" in *M042*) ok "main: stdout mentions milestone";; *) bad "main: stdout mentions milestone";; esac
case "$OUT" in *STATE.md*) ok "main: stdout points at STATE.md";; *) bad "main: stdout points at STATE.md";; esac
case "$OUT" in *"$AUTO"*) ok "main: stdout points at auto handoff";; *) bad "main: stdout points at auto handoff";; esac
if [ "${#OUT}" -lt 10000 ]; then ok "main: stdout under 10,000 chars (${#OUT})"; else bad "main: stdout under 10,000 chars" "${#OUT}"; fi
if [ -e "$ELSEWHERE/.ytstack" ]; then bad "main: nothing written under CLAUDE_PROJECT_DIR"; else ok "main: nothing written under CLAUDE_PROJECT_DIR"; fi

# ---- 2. linked worktree -----------------------------------------------------
echo "# linked worktree"
WT="$TMP/wt"
git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1
OUT=$(fire "$WT" s1); EC=$?
eq "wt: exit 0" 0 "$EC"
eq "wt: main git status clean" "" "$(git -C "$MAIN" status --porcelain)"
eq "wt: worktree git status clean" "" "$(git -C "$WT" status --porcelain)"
KW=$(keys "$WT")
if [ "$KW" != "$K" ]; then ok "wt: key dir differs from main"; else bad "wt: key dir differs from main"; fi
if [ -f "$PD/repos/$KW/sessions/s1/HANDOFF.auto.md" ]; then ok "wt: auto handoff under worktree key"; else bad "wt: auto handoff under worktree key"; fi
eq "wt: worktree field is the worktree" "$WT" "$(sed -n 's/^worktree: *//p' "$PD/repos/$KW/sessions/s1/HANDOFF.auto.md" 2>/dev/null | head -1)"
eq "wt: main_toplevel field is main"    "$MAIN" "$(sed -n 's/^main_toplevel: *//p' "$PD/repos/$KW/sessions/s1/HANDOFF.auto.md" 2>/dev/null | head -1)"
eq "wt: HANDOFF.md in worktree unchanged" "$H_BEFORE" "$(sha "$WT/.ytstack/HANDOFF.md")"

# ---- 3. repo without .ytstack ----------------------------------------------
echo "# no .ytstack"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"; ( cd "$PLAIN" && git init -q && git config user.email t@t.t && git config user.name t && echo x > f && git add -A && git commit -qm seed )
BEFORE_COUNT=$(find "$PD" -type f 2>/dev/null | wc -l | tr -d ' ')
OUT=$(fire "$PLAIN" s9); EC=$?
eq "plain: exit 0" 0 "$EC"
eq "plain: stdout empty" "" "$OUT"
eq "plain: no new state files" "$BEFORE_COUNT" "$(find "$PD" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ -e "$PLAIN/.ytstack" ]; then bad "plain: .ytstack not created"; else ok "plain: .ytstack not created"; fi

# ---- 4. two sessions --------------------------------------------------------
echo "# two sessions"
sleep 1
fire "$MAIN" s2 >/dev/null
if [ -f "$PD/repos/$K/sessions/s1/HANDOFF.auto.md" ] && [ -f "$PD/repos/$K/sessions/s2/HANDOFF.auto.md" ]; then ok "two: both session handoffs exist"; else bad "two: both session handoffs exist"; fi
case "$(readlink "$LATEST")" in *"/sessions/s2/"*) ok "two: latest-handoff points at s2";; *) bad "two: latest-handoff points at s2" "$(readlink "$LATEST")";; esac
eq "two: HANDOFF.md still byte-identical" "$H_BEFORE" "$(sha "$MAIN/.ytstack/HANDOFF.md")"

# ---- 5. no stdin, cwd = main -----------------------------------------------
echo "# no stdin"
FIRE_PWD="$MAIN" fire - x >/dev/null; EC=$?
eq "nostdin: exit 0" 0 "$EC"
if [ -f "$PD/repos/$K/sessions/nosession/HANDOFF.auto.md" ]; then ok "nostdin: falls back to hook cwd + nosession"; else bad "nostdin: falls back to hook cwd + nosession"; fi
eq "nostdin: HANDOFF.md untouched" "$H_BEFORE" "$(sha "$MAIN/.ytstack/HANDOFF.md")"
eq "nostdin: git status clean" "" "$(git -C "$MAIN" status --porcelain)"

# ---- 6. .ytstack without HANDOFF.md ----------------------------------------
echo "# no HANDOFF.md"
NOH=$(new_repo noh); ( cd "$NOH" && git rm -q .ytstack/HANDOFF.md && git commit -qm "drop handoff" )
fire "$NOH" s1 >/dev/null
if [ -e "$NOH/.ytstack/HANDOFF.md" ]; then bad "noh: hook does not create HANDOFF.md"; else ok "noh: hook does not create HANDOFF.md"; fi
eq "noh: git status clean" "" "$(git -C "$NOH" status --porcelain)"

# ---- 7. unwritable plugin data -> .ytstack/.local fallback -----------------
echo "# fallback"
FB=$(new_repo fb)
OUT=$(printf '{"session_id":"s1","cwd":"%s"}' "$FB" | ( cd "$ELSEWHERE" && CLAUDE_PLUGIN_DATA=/dev/null/x CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" ))
if [ -f "$FB/.ytstack/.local/sessions/s1/HANDOFF.auto.md" ]; then ok "fallback: auto handoff in .ytstack/.local"; else bad "fallback: auto handoff in .ytstack/.local"; fi
case "$OUT" in *"/.ytstack/.local/sessions/s1/HANDOFF.auto.md"*) ok "fallback: stdout reports the fallback path";; *) bad "fallback: stdout reports the fallback path";; esac
eq "fallback: HANDOFF.md untouched" "$H_BEFORE" "$(sha "$FB/.ytstack/HANDOFF.md")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
