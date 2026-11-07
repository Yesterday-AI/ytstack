#!/usr/bin/env bash
# Regression tests for hooks/session-end (M016-S01-T03, issues #26/#27).
#
# Contract (DECISIONS 2026-11-07):
#   - One JSON line per session end, appended to the OUT-OF-TREE per-session
#     file sessions/<session_id>/session.jsonl; never .ytstack/journal/.
#   - Target resolved from payload `cwd`, never CLAUDE_PROJECT_DIR.
#   - No git subprocess besides lib context resolution; fits 1.5 s budget.
#
# Run: /bin/bash tests/session-end.test.sh   (exit 0 = all pass)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/session-end"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytse.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
PD="$TMP/plugin-data"
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"

new_repo() { # new_repo <name> [milestone-value]
  local d="$TMP/$1" m="${2:-M042}"
  mkdir -p "$d/.ytstack"
  ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t
    printf 'project: fixture\ncurrent_milestone: %s\nactive_slice: S03\nactive_task: T07\n' "$m" > .ytstack/STATE.md
    echo seed > f.txt; git add -A; git commit -qm "seed" )
  echo "$d"
}
keys() { ( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$1" >/dev/null; printf '%s/worktrees/%s' "$YT_REPO_KEY" "$YT_WT_KEY" ); }

fire() { # fire <cwd> <session> <reason>
  printf '{"session_id":"%s","transcript_path":"/x","cwd":"%s","hook_event_name":"SessionEnd","reason":"%s"}' "$2" "$1" "$3" \
    | ( cd "$ELSEWHERE" && CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" )
}
jfield() { jq -r ".$2 // empty" "$1" 2>/dev/null | tail -1; }

# ---- 1. main checkout -------------------------------------------------------
echo "# main checkout"
MAIN=$(new_repo main); K=$(keys "$MAIN"); J="$PD/repos/$K/sessions/s1/session.jsonl"
fire "$MAIN" s1 clear; EC=$?
eq "main: exit 0" 0 "$EC"
if [ -f "$J" ]; then ok "main: journal file out-of-tree"; else bad "main: journal file out-of-tree" "$J missing"; fi
eq "main: one line"                1       "$(wc -l < "$J" 2>/dev/null | tr -d ' ')"
if jq -e . "$J" >/dev/null 2>&1; then ok "main: line is valid JSON"; else bad "main: line is valid JSON"; fi
eq "main: session_id"              s1      "$(jfield "$J" session_id)"
eq "main: milestone from STATE"    M042    "$(jfield "$J" milestone)"
eq "main: task from STATE"         T07     "$(jfield "$J" task)"
eq "main: reason from payload"     clear   "$(jfield "$J" reason)"
eq "main: event"                   session-end "$(jfield "$J" event)"
eq "main: worktree"                "$MAIN" "$(jfield "$J" worktree)"
if [ -e "$MAIN/.ytstack/journal" ]; then bad "main: .ytstack/journal not created"; else ok "main: .ytstack/journal not created"; fi
eq "main: git status clean"        ""      "$(git -C "$MAIN" status --porcelain)"
if [ -e "$ELSEWHERE/.ytstack" ]; then bad "main: nothing under CLAUDE_PROJECT_DIR"; else ok "main: nothing under CLAUDE_PROJECT_DIR"; fi

# ---- 2. append on second end of same session -------------------------------
echo "# append"
fire "$MAIN" s1 other
eq "append: two lines, same file"  2       "$(wc -l < "$J" | tr -d ' ')"
eq "append: last reason is other"  other   "$(jfield "$J" reason)"

# ---- 3. linked worktree -----------------------------------------------------
echo "# linked worktree"
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1
KW=$(keys "$WT"); JW="$PD/repos/$KW/sessions/s1/session.jsonl"
fire "$WT" s1 logout
if [ -f "$JW" ]; then ok "wt: journal under worktree key"; else bad "wt: journal under worktree key"; fi
eq "wt: worktree field"            "$WT"   "$(jfield "$JW" worktree)"
eq "wt: linked_worktree yes"       yes     "$(jfield "$JW" linked_worktree)"
eq "wt: main git status clean"     ""      "$(git -C "$MAIN" status --porcelain)"
eq "wt: worktree git status clean" ""      "$(git -C "$WT" status --porcelain)"

# ---- 4. two sessions --------------------------------------------------------
echo "# two sessions"
fire "$MAIN" s2 clear
J2="$PD/repos/$K/sessions/s2/session.jsonl"
if [ -f "$J2" ]; then ok "two: s2 has its own file"; else bad "two: s2 has its own file"; fi
eq "two: s2 one line"              1       "$(wc -l < "$J2" | tr -d ' ')"
eq "two: s1 still two lines"       2       "$(wc -l < "$J" | tr -d ' ')"

# ---- 5. no .ytstack ---------------------------------------------------------
echo "# no .ytstack"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"; ( cd "$PLAIN" && git init -q && git config user.email t@t.t && git config user.name t && echo x > f && git add -A && git commit -qm seed )
BEFORE=$(find "$PD" -type f | wc -l | tr -d ' ')
OUT=$(fire "$PLAIN" s9 clear); EC=$?
eq "plain: exit 0" 0 "$EC"
eq "plain: no output" "" "$OUT"
eq "plain: no new files" "$BEFORE" "$(find "$PD" -type f | wc -l | tr -d ' ')"

# ---- 6. escaping ------------------------------------------------------------
echo "# escaping"
ESC=$(new_repo esc 'M1 "quoted" back\slash')
KE=$(keys "$ESC"); JE="$PD/repos/$KE/sessions/s1/session.jsonl"
fire "$ESC" s1 clear
if jq -e . "$JE" >/dev/null 2>&1; then ok "esc: still valid JSON"; else bad "esc: still valid JSON" "$(cat "$JE" 2>/dev/null)"; fi
eq "esc: value round-trips" 'M1 "quoted" back\slash' "$(jfield "$JE" milestone)"

# ---- 7. no stdin ------------------------------------------------------------
echo "# no stdin"
( cd "$MAIN" && CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" </dev/null )
JN="$PD/repos/$K/sessions/nosession/session.jsonl"
if [ -f "$JN" ]; then ok "nostdin: falls back to hook cwd + nosession"; else bad "nostdin: falls back to hook cwd + nosession"; fi
eq "nostdin: reason unknown" unknown "$(jfield "$JN" reason)"
eq "nostdin: git status clean" "" "$(git -C "$MAIN" status --porcelain)"

# ---- 8. budget --------------------------------------------------------------
echo "# budget"
ELAPSED=$(python3 - "$HOOK" "$MAIN" "$PD" "$ELSEWHERE" <<'PY'
import subprocess, sys, time, json
hook, main, pd, elsewhere = sys.argv[1:5]
payload = json.dumps({"session_id": "bench", "cwd": main, "reason": "clear"})
t = time.time()
for _ in range(5):
    subprocess.run(["bash", hook], input=payload.encode(), cwd=elsewhere,
                   env={"PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": elsewhere,
                        "CLAUDE_PLUGIN_DATA": pd, "CLAUDE_PROJECT_DIR": elsewhere}, check=False)
print("%.2f" % (time.time() - t))
PY
)
# Per-call plugin budget is 1.5 s; require a 1.0 s average so a loaded machine
# (other suites running) does not make this flaky while real regressions
# (shim/perl/python-stub latency, ~1 s per call) still fail.
if python3 -c "import sys; sys.exit(0 if float('$ELAPSED') < 5.0 else 1)"; then ok "budget: 5 runs in ${ELAPSED}s (< 5.0s)"; else bad "budget: 5 runs in ${ELAPSED}s (< 5.0s)"; fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
