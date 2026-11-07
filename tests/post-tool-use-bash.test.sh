#!/usr/bin/env bash
# Regression tests for hooks/post-tool-use-bash (issues #22, #26, #27).
#
# Contract (M015 "stub-once" + M016 "worktree-safe"):
#   - The hook fires only on a REAL `git commit` invocation (not echoes,
#     not `git log | grep commit`, not doc strings). Wrapper tokens such as
#     `rtk`, `sudo`, `env X=1` before `git commit` are accepted.
#   - It resolves the checkout from the payload `cwd` (fallback: its own
#     $PWD), never from CLAUDE_PROJECT_DIR.
#   - It stubs only when HEAD's subject matches the active task's commit ref
#     (`commit_ref_pattern` in PREFERENCES.md, default `^M###-S##-T##:`).
#   - On the first matching commit with no SUMMARY yet, it creates a draft
#     stub ONCE in that checkout's .ytstack. If the SUMMARY exists: no-op.
#
# Run: /bin/bash tests/post-tool-use-bash.test.sh   (exit 0 = all pass)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/post-tool-use-bash"
[ -f "$HOOK" ] || { echo "FATAL: hook not found at $HOOK"; exit 2; }

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/yt22test.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"

# Safety: every fixture lives under $TMP. A failed `cd` into a fixture must
# abort the subshell, never fall through into the caller's checkout (this file
# once committed junk into the real repo when a fixture path was garbage).
new_repo() {
  local t; t=$(mktemp -d "$TMP/repo.XXXXXX") || exit 2
  ( cd "$t" || exit 2
    git init -q
    git config user.email t@t.t; git config user.name t
    mkdir .ytstack
    printf 'current_milestone: M999\nactive_slice: S01\nactive_task: T01\n' > .ytstack/STATE.md
    printf 'name: testproj\n' > .ytstack/PROJECT.md
    echo seed > f.txt; git add -A; git commit -qm "seed: initial"
  ) >/dev/null 2>&1 || { echo "FATAL: fixture setup failed in $t" >&2; exit 2; }
  [ -d "$t/.git" ] || { echo "FATAL: no git repo at $t" >&2; exit 2; }
  echo "$t"
}
in_fixture() { case "$1" in "$TMP"/*) return 0 ;; *) echo "FATAL: refusing to touch non-fixture path '$1'" >&2; exit 2 ;; esac; }

# fire <repo-for-cwd> <command-string> <exit-code>
# Runs from a neutral cwd with CLAUDE_PROJECT_DIR pointing at a bogus dir, so
# only the payload `cwd` can lead the hook to the right checkout.
fire() {
  local repo="$1" cmd="$2" ec="$3"
  printf '{"session_id":"t","cwd":%s,"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":%s},"tool_response":{"exit_code":%s}}' \
    "$(printf '%s' "$repo" | jq -Rs .)" "$(printf '%s' "$cmd" | jq -Rs .)" "$ec" \
    | ( cd "$ELSEWHERE" && CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" )
}

commit_in() { in_fixture "$1"; ( cd "$1" || exit 2; echo "$2" > "$2"; git add "$2"; git commit -qm "$3" ) >/dev/null 2>&1 || { echo "FATAL: commit_in failed for $1" >&2; exit 2; }; }

SUMREL=".ytstack/M999-S01-T01-SUMMARY.md"
hash_of() { [ -f "$1" ] && shasum "$1" | awk '{print $1}' || echo "MISSING"; }

# --- T1: real task-ref commit, no summary -> stub created once --------------
R=$(new_repo)
commit_in "$R" a "M999-S01-T01: add a"
fire "$R" 'git commit -m "M999-S01-T01: add a"' 0
if [ -f "$R/$SUMREL" ]; then ok "T1 real commit creates draft stub"; else bad "T1 stub NOT created"; fi
grep -q 'source: post-tool-use-bash-draft' "$R/$SUMREL" 2>/dev/null \
  && ok "T1 stub has draft frontmatter" || bad "T1 stub missing draft frontmatter"
grep -q "^worktree: $R\$" "$R/$SUMREL" 2>/dev/null \
  && ok "T1 stub records the worktree" || bad "T1 stub missing worktree field"
[ -e "$ELSEWHERE/.ytstack" ] && bad "T1 wrote under CLAUDE_PROJECT_DIR" || ok "T1 nothing written under CLAUDE_PROJECT_DIR"

# --- T2: real commit on EXISTING summary -> no-op (no append) ---------------
H1=$(hash_of "$R/$SUMREL")
commit_in "$R" b "M999-S01-T01: add b"
fire "$R" 'git commit -m "M999-S01-T01: add b"' 0
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
fire "$R5" 'git commit -m "M999-S01-T01: nothing staged"' 1
[ ! -f "$R5/$SUMREL" ] && ok "T5 failed commit creates no stub" \
  || bad "T5 stub created on failed commit"

# --- T6: self-perpetuation -> committing the stub does NOT re-dirty it ------
R6=$(new_repo)
commit_in "$R6" c "M999-S01-T01: add c"
fire "$R6" 'git commit -m "M999-S01-T01: add c"' 0
in_fixture "$R6"; ( cd "$R6" || exit 2; git add "$SUMREL"; git commit -qm "M999-S01-T01: add summary draft" ) >/dev/null 2>&1
fire "$R6" 'git commit -m "M999-S01-T01: add summary draft"' 0
DIRTY=$(cd "$R6"; git status --short .ytstack/)
[ -z "$DIRTY" ] && ok "T6 tree settles clean after committing the stub" \
  || bad "T6 hook re-dirtied the summary (never settles): $DIRTY"

# --- T7: no active task -> no stub ------------------------------------------
R7=$(new_repo)
in_fixture "$R7"; printf 'current_milestone: M999\nactive_slice: none\nactive_task: none\n' > "$R7/.ytstack/STATE.md"
commit_in "$R7" d "M999-S01-T01: add d"
fire "$R7" 'git commit -m "M999-S01-T01: add d"' 0
[ ! -f "$R7/$SUMREL" ] && ok "T7 no active task -> no stub" \
  || bad "T7 stub created with no active task"

# --- T8: chained `&& git commit` IS a real commit -> stub created -----------
R8=$(new_repo)
commit_in "$R8" e "M999-S01-T01: add e"
fire "$R8" 'git add e && git commit -m "M999-S01-T01: add e"' 0
[ -f "$R8/$SUMREL" ] && ok "T8 chained '&& git commit' creates stub" \
  || bad "T8 missed a real chained git commit"

# --- T9: real command then an echo with the ADJACENT phrase -> no stub ------
R9=$(new_repo)
fire "$R9" 'git status && echo "now please git commit it"' 0
[ ! -f "$R9/$SUMREL" ] && ok "T9 echo with adjacent 'git commit' phrase does NOT create stub" \
  || bad "T9 matcher fired on a separator-then-echo string"

# --- T10: commit in a linked worktree, CLAUDE_PROJECT_DIR = main -----------
R10=$(new_repo)
in_fixture "$R10"; ( cd "$R10" || exit 2; git add -A; git commit -qm "M999-S01-T01: track ytstack" ) >/dev/null 2>&1 || true
WT="$TMP/wt10"; git -C "$R10" worktree add -q -b wt "$WT" >/dev/null 2>&1 || { echo "FATAL: worktree add failed" >&2; exit 2; }
commit_in "$WT" g "M999-S01-T01: add g in worktree"
printf '{"cwd":%s,"tool_input":{"command":"git commit -m x"},"tool_response":{"exit_code":0}}' "$(printf '%s' "$WT" | jq -Rs .)" \
  | ( cd "$R10" && CLAUDE_PROJECT_DIR="$R10" bash "$HOOK" )
[ -f "$WT/$SUMREL" ] && ok "T10 stub lands in the worktree's .ytstack" || bad "T10 stub missing in worktree"
[ -z "$(git -C "$R10" status --porcelain)" ] && ok "T10 main checkout stays clean" || bad "T10 main checkout dirtied: $(git -C "$R10" status --porcelain)"

# --- T11: real commit WITHOUT the task ref -> no stub -----------------------
R11=$(new_repo)
commit_in "$R11" h "feat: unrelated production fix"
fire "$R11" 'git commit -m "feat: unrelated production fix"' 0
[ ! -f "$R11/$SUMREL" ] && ok "T11 commit without task ref -> no stub" \
  || bad "T11 stub created for a commit without the task ref"

# --- T12: wrapper token before git commit (rtk) -> stub ---------------------
R12=$(new_repo)
commit_in "$R12" i "M999-S01-T01: add i"
fire "$R12" 'cd x && rtk git commit -q -m "M999-S01-T01: add i"' 0
[ -f "$R12/$SUMREL" ] && ok "T12 'rtk git commit' wrapper is recognised" \
  || bad "T12 wrapper token defeated the matcher"

# --- T13: custom commit_ref_pattern from PREFERENCES.md ---------------------
R13=$(new_repo)
# Pattern is taken literally after stripping surrounding quotes (no YAML escape processing).
in_fixture "$R13"; printf -- '---\ncommit_ref_pattern: "^feat\\({task}\\)"\n---\n' > "$R13/.ytstack/PREFERENCES.md"
commit_in "$R13" j "chore: add j (default ref format M999-S01-T01: must not match the custom pattern)"
fire "$R13" 'git commit -m x' 0
[ ! -f "$R13/$SUMREL" ] && ok "T13a custom pattern: non-matching subject -> no stub" \
  || bad "T13a custom pattern ignored (stubbed on non-match)"
commit_in "$R13" k "feat(M999-S01-T01): add k"
fire "$R13" 'git commit -m x' 0
[ -f "$R13/$SUMREL" ] && ok "T13b custom pattern: matching subject -> stub" \
  || bad "T13b custom pattern did not match"

# --- T14: payload without cwd, hook run inside the repo -> $PWD fallback ----
R14=$(new_repo)
commit_in "$R14" l "M999-S01-T01: add l"
printf '{"tool_input":{"command":"git commit -m x"},"tool_response":{"exit_code":0}}' \
  | ( cd "$R14" && CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$HOOK" )
[ -f "$R14/$SUMREL" ] && ok "T14 no cwd in payload -> falls back to hook PWD" \
  || bad "T14 PWD fallback failed"

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
