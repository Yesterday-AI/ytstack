#!/usr/bin/env bash
# Regression tests for hooks/post-tool-use-bash (issue #22).
#
# Contract (M015, "stub-once"):
#   - The hook fires only on a REAL `git commit` invocation (not echoes,
#     not `git log | grep commit`, not doc strings).
#   - On the first real commit of a task with no SUMMARY yet, it creates a
#     draft stub ONCE.
#   - If the SUMMARY already exists, the hook is a no-op (exit 0). It never
#     appends, so the tree settles and a worktree branched from main can see
#     the committed stub.
#
# Run: bash tests/post-tool-use-bash.test.sh   (exit 0 = all pass)

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/post-tool-use-bash"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }

# Build a fresh isolated ytstack git repo, echo its path.
new_repo() {
  local t; t=$(mktemp -d "/tmp/yt22test.XXXXXX")
  ( cd "$t"
    git init -q
    git config user.email t@t.t; git config user.name t
    mkdir .ytstack
    printf 'current_milestone: M999\nactive_slice: S01\nactive_task: T01\n' > .ytstack/STATE.md
    printf 'name: testproj\n' > .ytstack/PROJECT.md
    echo seed > f.txt; git add -A; git commit -qm "seed: initial"
  )
  echo "$t"
}

# fire <repo> <command-string> <exit-code>
fire() {
  local repo="$1" cmd="$2" ec="$3"
  printf '{"tool_input":{"command":%s},"tool_response":{"exit_code":%s}}' \
    "$(jq -Rs . <<<"$cmd")" "$ec" \
    | CLAUDE_PROJECT_DIR="$repo" bash "$HOOK"
}

SUMREL=".ytstack/M999-S01-T01-SUMMARY.md"
hash_of() { [ -f "$1" ] && shasum "$1" | awk '{print $1}' || echo "MISSING"; }

# --- T1: real commit, no summary -> stub created once -----------------------
R=$(new_repo)
( cd "$R"; echo a>a; git add a; git commit -qm "feat: add a" )
fire "$R" 'git commit -m "feat: add a"' 0
if [ -f "$R/$SUMREL" ]; then ok "T1 real commit creates draft stub"; else bad "T1 stub NOT created"; fi
grep -q 'source: post-tool-use-bash-draft' "$R/$SUMREL" 2>/dev/null \
  && ok "T1 stub has draft frontmatter" || bad "T1 stub missing draft frontmatter"

# --- T2: real commit on EXISTING summary -> no-op (no append) ---------------
H1=$(hash_of "$R/$SUMREL")
( cd "$R"; echo b>b; git add b; git commit -qm "feat: add b" )
fire "$R" 'git commit -m "feat: add b"' 0
H2=$(hash_of "$R/$SUMREL")
[ "$H1" = "$H2" ] && ok "T2 second commit leaves summary byte-identical" \
  || bad "T2 summary changed on second commit (append leak)"

# --- T3: read-only `git log | grep commit` on FRESH repo -> no stub ---------
R3=$(new_repo)
fire "$R3" 'git log --oneline | grep commit' 0
[ ! -f "$R3/$SUMREL" ] && ok "T3 read-only git+commit does NOT create stub" \
  || bad "T3 loose matcher fired on read-only command"

# --- T4: echo containing the quoted phrase "git commit" -> no stub ----------
R4=$(new_repo)
fire "$R4" 'echo "remember to git commit later"' 0
[ ! -f "$R4/$SUMREL" ] && ok "T4 quoted-echo of git commit does NOT create stub" \
  || bad "T4 matcher fired on an echo string"

# --- T5: failed commit (exit 1) -> no stub ----------------------------------
R5=$(new_repo)
fire "$R5" 'git commit -m "nothing staged"' 1
[ ! -f "$R5/$SUMREL" ] && ok "T5 failed commit creates no stub" \
  || bad "T5 stub created on failed commit"

# --- T6: self-perpetuation -> committing the stub does NOT re-dirty it ------
#   create stub, commit it, fire hook on that commit, tree must be clean.
R6=$(new_repo)
( cd "$R6"; echo c>c; git add c; git commit -qm "feat: add c" )
fire "$R6" 'git commit -m "feat: add c"' 0
( cd "$R6"; git add "$SUMREL"; git commit -qm "M999-S01-T01: add summary draft" )
fire "$R6" 'git commit -m "M999-S01-T01: add summary draft"' 0
DIRTY=$(cd "$R6"; git status --short .ytstack/)
[ -z "$DIRTY" ] && ok "T6 tree settles clean after committing the stub" \
  || bad "T6 hook re-dirtied the summary (never settles): $DIRTY"

# --- T7: no active task -> no stub ------------------------------------------
R7=$(new_repo)
( cd "$R7"; printf 'current_milestone: M999\nactive_slice: none\nactive_task: none\n' > .ytstack/STATE.md
  echo d>d; git add d; git commit -qm "feat: add d" )
fire "$R7" 'git commit -m "feat: add d"' 0
[ ! -f "$R7/$SUMREL" ] && ok "T7 no active task -> no stub" \
  || bad "T7 stub created with no active task"

# --- T8: chained `&& git commit` IS a real commit -> stub created -----------
R8=$(new_repo)
( cd "$R8"; echo e>e )
fire "$R8" 'git add e && git commit -m "feat: add e"' 0
[ -f "$R8/$SUMREL" ] && ok "T8 chained '&& git commit' creates stub" \
  || bad "T8 missed a real chained git commit"

# --- T9: real command then an echo with the ADJACENT phrase -> no stub ------
#   The phrase "git commit" appears (inside the echo arg) but is not preceded
#   by a command separator, so it must NOT match.
R9=$(new_repo)
fire "$R9" 'git status && echo "now please git commit it"' 0
[ ! -f "$R9/$SUMREL" ] && ok "T9 echo with adjacent 'git commit' phrase does NOT create stub" \
  || bad "T9 matcher fired on a separator-then-echo string"

rm -rf /tmp/yt22test.* 2>/dev/null

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
