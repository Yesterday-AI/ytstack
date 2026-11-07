#!/usr/bin/env bash
# Tests for the skill preambles (M016-S02-T01, issue #24).
#
# Every skill preamble resolves the checkout through hooks/lib/git-ctx.sh:
#   - IS_GIT via `git rev-parse --is-inside-work-tree` (a linked worktree,
#     whose .git is a FILE, reports yes)
#   - .ytstack resolution from where the shell runs (never CLAUDE_PROJECT_DIR)
#   - no basename slug for anything but display
#
# The test extracts the first fenced preamble (```bash or ```!) from each
# SKILL.md, substitutes ${CLAUDE_SKILL_DIR} like Claude Code does, and runs it
# inside a fixture main checkout and a linked worktree of it.
#
# Run: /bin/bash tests/skill-preambles.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytsp.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2
  git init -q && git config user.email t@t.t && git config user.name t
  printf 'project: fixture\ncurrent_milestone: M999\nactive_slice: S01\nactive_task: T01\n\n# State\n\n## Next action\n\nx\n' > .ytstack/STATE.md
  printf 'name: fixture\n' > .ytstack/PROJECT.md
  printf -- '---\nmilestone: M999\n---\n- [ ] S01 -- (to be planned)\n' > .ytstack/M999-ROADMAP.md
  printf -- '---\nmilestone: M999\nslice: S01\n---\n- [ ] T01 -- x\n' > .ytstack/M999-S01-PLAN.md
  printf -- '---\ntask: T01\n---\n## Files\n\n- Modify: a.ts\n\n## Verification\n\n```bash\ntrue\n```\n' > .ytstack/M999-S01-T01-PLAN.md
  echo seed > f.txt; git add -A; git commit -qm "M999-S01-T01: seed" ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1 || { echo FATAL worktree; exit 2; }

SKILLS="handoff-session init-project plan-milestone plan-task reassess-roadmap resume-session slice-milestone spawn-milestone-team summarize-task office-hours plan-ceo-review plan-eng-review systematic-debugging test-driven-development verification-before-completion"

# extract <skill> -> path of a runnable script with ${CLAUDE_SKILL_DIR} substituted
extract() {
  local skill="$1" src="$ROOT/skills/$1/SKILL.md" out="$TMP/pre-$1.sh"
  awk 'BEGIN{p=0} /^```(bash|!)[[:space:]]*$/ && p==0 {p=1; next} /^```[[:space:]]*$/ && p==1 {exit} p==1 {print}' "$src" \
    | sed "s|\${CLAUDE_SKILL_DIR}|$ROOT/skills/$skill|g" > "$out"
  printf '%s' "$out"
}

run_pre() { # run_pre <script> <cwd> -> sets OUT (stdout) and EC (exit code) in this shell
  ( cd "$2" || exit 2; env CLAUDE_PROJECT_DIR="$ELSEWHERE" HOME="$TMP/home" bash "$1" 2>"$TMP/err" >"$TMP/out" ); EC=$?
  OUT=$(cat "$TMP/out")
}
mkdir -p "$TMP/home"

for s in $SKILLS; do
  echo "# $s"
  P=$(extract "$s")
  [ -s "$P" ] && ok "$s: preamble extracted ($(wc -l < "$P" | tr -d ' ') lines)" || { bad "$s: preamble extracted"; continue; }
  bash -n "$P" 2>/dev/null && ok "$s: parses" || bad "$s: parses" "$(bash -n "$P" 2>&1 | head -1)"
  grep -q 'hooks/lib/git-ctx.sh' "$P" && ok "$s: sources the lib" || bad "$s: sources the lib"
  grep -q 'CLAUDE_PROJECT_DIR' "$P" && bad "$s: no CLAUDE_PROJECT_DIR" || ok "$s: no CLAUDE_PROJECT_DIR"
  grep -q 'basename "$(git rev-parse --show-toplevel' "$P" && bad "$s: no basename slug" || ok "$s: no basename slug"
  grep -q -- '-d \.git ]' "$P" && bad "$s: no [ -d .git ]" || ok "$s: no [ -d .git ]"

  run_pre "$P" "$MAIN"
  [ "$EC" -eq 0 ] && ok "$s: runs in main (exit 0)" || bad "$s: runs in main (exit 0)" "exit $EC: $(head -2 "$TMP/err" | tr '\n' ' ')"
  has "$s: main -> HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
  case "$OUT" in *"$ELSEWHERE"*) bad "$s: main -> no CLAUDE_PROJECT_DIR leak";; *) ok "$s: main -> no CLAUDE_PROJECT_DIR leak";; esac

  run_pre "$P" "$WT"
  [ "$EC" -eq 0 ] && ok "$s: runs in worktree (exit 0)" || bad "$s: runs in worktree (exit 0)" "exit $EC"
  has "$s: worktree -> HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
  case "$OUT" in *"$MAIN/.ytstack"*) bad "$s: worktree -> resolves its own .ytstack, not main's";; *) ok "$s: worktree -> resolves its own .ytstack, not main's";; esac
  case "$s" in
    summarize-task|init-project)
      has "$s: worktree -> IS_GIT yes (#24)" "$OUT" "IS_GIT: yes" ;;
  esac
done

# Fallback path: CLAUDE_SKILL_DIR left unsubstituted (foreign host) -> still resolves project scope
echo "# fallback without lib"
P=$(extract summarize-task); sed "s|$ROOT/skills/summarize-task|/nonexistent-skill-dir|g" "$P" > "$TMP/pre-fallback.sh"
run_pre "$TMP/pre-fallback.sh" "$WT"
[ "$EC" -eq 0 ] && ok "fallback: runs" || bad "fallback: runs" "exit $EC"
has "fallback: HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
has "fallback: IS_GIT yes in worktree" "$OUT" "IS_GIT: yes"

echo "# tree hygiene"
[ -z "$(git -C "$MAIN" status --porcelain)" ] && ok "main checkout clean after all preambles" || bad "main checkout clean" "$(git -C "$MAIN" status --porcelain | head -3 | tr '\n' ' ')"
[ -e "$ELSEWHERE/.ytstack" ] && bad "nothing written under CLAUDE_PROJECT_DIR" || ok "nothing written under CLAUDE_PROJECT_DIR"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
