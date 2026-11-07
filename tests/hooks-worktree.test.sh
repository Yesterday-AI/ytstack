#!/usr/bin/env bash
# End-to-end acceptance for issues #26/#27 (M016-S03-T01).
#
# For three session shapes -- (a) session in main, (b) session in a linked
# worktree, (c) CLAUDE_PROJECT_DIR=main while the payload cwd is the worktree --
# fire every hook with realistic payloads and assert:
#   - the main checkout is byte-identical except for artifacts that legitimately
#     belong to the checkout that committed (draft stub, team summary)
#   - the hand-written .ytstack/HANDOFF.md never changes
#   - volatile state (auto handoff, journal) lives only under CLAUDE_PLUGIN_DATA
#   - firing the whole sequence twice adds nothing new in any checkout
#
# Run: /bin/bash tests/hooks-worktree.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
H="$ROOT/hooks"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytwt.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
PD="$TMP/plugin-data"
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
in_fixture() { case "$1" in "$TMP"/*) return 0 ;; *) echo "FATAL: non-fixture path '$1'" >&2; exit 2 ;; esac; }
jstr() { printf '%s' "$1" | jq -Rs .; }

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2
  git init -q && git config user.email t@t.t && git config user.name t && git branch -M main
  printf 'project: fixture\ncurrent_milestone: M042\nactive_slice: S03\nactive_task: T07\n\n# State\n\n## Next action\n\nFinish the widget.\n' > .ytstack/STATE.md
  printf 'name: fixture\n' > .ytstack/PROJECT.md
  printf 'granularity: task\n' > .ytstack/PREFERENCES.md
  printf -- '---\nkind: handoff\nevent: user-triggered\ntimestamp: 2026-01-01T00:00:00Z\n---\n# Hand-written\n\nDo not lose me.\n' > .ytstack/HANDOFF.md
  printf -- '---\nmilestone: M042\n---\n- [ ] S03 -- x\n' > .ytstack/M042-ROADMAP.md
  printf -- '---\nmilestone: M042\nslice: S03\n---\n- [ ] T07 -- do it (src/planned.ts)\n- [ ] T08 -- more\n' > .ytstack/M042-S03-PLAN.md
  printf -- '---\ntask: T07\n---\n## Files\n\n- Modify: src/planned.ts\n' > .ytstack/M042-S03-T07-PLAN.md
  echo seed > f.txt; git add -A; git commit -qm "seed" ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1 || { echo FATAL worktree; exit 2; }
H_SHA=$(shasum -a 256 "$MAIN/.ytstack/HANDOFF.md" | cut -c1-16)

# snapshot <checkout> -> porcelain status + sha of every tracked/untracked .ytstack file
snapshot() { ( cd "$1" || exit 2; git status --porcelain; find .ytstack -type f | sort | xargs shasum -a 256 2>/dev/null ); }
# files_in <checkout> -> sorted list of files under .ytstack
files_in() { ( cd "$1" || exit 2; find .ytstack -type f | sort ); }

# fire <hook> <cwd-for-payload> <project-dir-env> <extra-json-fields>
fire() {
  local hook="$1" cwd="$2" pdir="$3" extra="$4"
  printf '{"session_id":"%s","transcript_path":"/x","cwd":%s,"hook_event_name":"%s"%s}' "$SESSION" "$(jstr "$cwd")" "$hook" "$extra" \
    | ( cd "$pdir" && env CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$pdir" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$H/$hook" >/dev/null 2>"$TMP/err.$hook" )
}

# sequence <checkout-for-cwd> <project-dir-env> <label>
sequence() {
  local co="$1" pdir="$2" label="$3"
  fire session-start "$co" "$pdir" ',"source":"startup"'
  fire pre-tool-use-edit "$co" "$pdir" ",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":$(jstr "$co/src/other.ts")}"
  in_fixture "$co"; ( cd "$co" || exit 2; echo "$label" > "work-$label.txt"; git add "work-$label.txt"; git commit -qm "M042-S03-T07: work in $label" ) >/dev/null 2>&1
  fire post-tool-use-bash "$co" "$pdir" ',"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"tool_response":{"exit_code":0}'
  fire pre-compact "$co" "$pdir" ',"trigger":"auto"'
  fire session-end "$co" "$pdir" ',"reason":"clear"'
  fire task-created "$co" "$pdir" ',"tool_input":{"subject":"touch src/planned.ts"}'
  fire teammate-idle "$co" "$pdir" ''
  fire task-completed "$co" "$pdir" ',"tool_input":{"subject":"M042-S03-T08 -- more"}'
}

check_after() { # check_after <label> <co> <expected-new-files-in-co> <other-checkout-snapshot-before> <other>
  local label="$1" co="$2" expect="$3" other_before="$4" other="$5"
  eq "$label: only the two legitimate artifacts appeared in the committing checkout" "$expect" "$(files_in "$co" | grep -v -F -f "$TMP/baseline-files")"
  eq "$label: other checkout byte-identical" "$other_before" "$(snapshot "$other")"
  eq "$label: HANDOFF.md unchanged in committing checkout" "$H_SHA" "$(shasum -a 256 "$co/.ytstack/HANDOFF.md" | cut -c1-16)"
  if [ -e "$co/.ytstack/journal" ]; then bad "$label: no .ytstack/journal"; else ok "$label: no .ytstack/journal"; fi
  if [ -e "$ELSEWHERE/.ytstack" ]; then bad "$label: nothing under bogus CLAUDE_PROJECT_DIR"; else ok "$label: nothing under bogus CLAUDE_PROJECT_DIR"; fi
}

files_in "$MAIN" > "$TMP/baseline-files"
EXPECT=$'.ytstack/M042-S03-T07-SUMMARY.md\n.ytstack/M042-S03-T08-SUMMARY.md'

# ---- (a) session in main ---------------------------------------------------
echo "# (a) session in main"
SESSION=sa; WT_BEFORE=$(snapshot "$WT")
sequence "$MAIN" "$MAIN" a
check_after "a" "$MAIN" "$EXPECT" "$WT_BEFORE" "$WT"
MAIN_FILES_A=$(files_in "$MAIN")
K=$( ( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$MAIN" >/dev/null; printf '%s/worktrees/%s' "$YT_REPO_KEY" "$YT_WT_KEY" ) )
if [ -f "$PD/repos/$K/sessions/sa/HANDOFF.auto.md" ] && [ -f "$PD/repos/$K/sessions/sa/session.jsonl" ]; then ok "a: auto handoff + journal under plugin data"; else bad "a: auto handoff + journal under plugin data"; fi
# commit the two artifacts so main is clean again for the next scenarios
( cd "$MAIN" && git add -A && git commit -qm "M042-S03-T07: artifacts from (a)" ) >/dev/null 2>&1

# ---- (b) session in the linked worktree ------------------------------------
echo "# (b) session in worktree"
SESSION=sb; MAIN_BEFORE=$(snapshot "$MAIN")
files_in "$WT" > "$TMP/baseline-files"
sequence "$WT" "$WT" b
check_after "b" "$WT" "$EXPECT" "$MAIN_BEFORE" "$MAIN"
KW=$( ( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$WT" >/dev/null; printf '%s/worktrees/%s' "$YT_REPO_KEY" "$YT_WT_KEY" ) )
[ "$KW" != "$K" ] && ok "b: worktree has its own state dir" || bad "b: worktree has its own state dir"
if [ -f "$PD/repos/$KW/sessions/sb/HANDOFF.auto.md" ]; then ok "b: auto handoff under the worktree key"; else bad "b: auto handoff under the worktree key"; fi
( cd "$WT" && git add -A && git commit -qm "M042-S03-T07: artifacts from (b)" ) >/dev/null 2>&1

# ---- (c) CLAUDE_PROJECT_DIR = main, cwd = worktree -------------------------
echo "# (c) project dir main, work in worktree"
SESSION=sc; MAIN_BEFORE=$(snapshot "$MAIN")
( cd "$WT" && git rm -q --cached .ytstack/M042-S03-T07-SUMMARY.md .ytstack/M042-S03-T08-SUMMARY.md && rm -f .ytstack/M042-S03-T07-SUMMARY.md .ytstack/M042-S03-T08-SUMMARY.md && git commit -qm "M042-S03-T07: drop artifacts for (c)" ) >/dev/null 2>&1
files_in "$WT" > "$TMP/baseline-files"
sequence "$WT" "$MAIN" c
check_after "c" "$WT" "$EXPECT" "$MAIN_BEFORE" "$MAIN"
if [ -f "$PD/repos/$KW/sessions/sc/HANDOFF.auto.md" ]; then ok "c: auto handoff under the worktree key, not main's"; else bad "c: auto handoff under the worktree key"; fi
if [ -e "$PD/repos/$K/sessions/sc" ]; then bad "c: nothing written under main's key"; else ok "c: nothing written under main's key"; fi

# ---- idempotency ------------------------------------------------------------
echo "# idempotency"
WT_FILES=$(files_in "$WT"); MAIN_FILES=$(files_in "$MAIN")
sequence "$WT" "$MAIN" c2 >/dev/null 2>&1
eq "repeat: no new files in worktree" "$WT_FILES" "$(files_in "$WT")"
eq "repeat: no new files in main"     "$MAIN_FILES" "$(files_in "$MAIN")"
eq "repeat: main HANDOFF.md still intact" "$H_SHA" "$(shasum -a 256 "$MAIN/.ytstack/HANDOFF.md" | cut -c1-16)"
eq "repeat: journal appended, not duplicated elsewhere" 2 "$(cat "$PD/repos/$KW/sessions/sc/session.jsonl" | wc -l | tr -d ' ')"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
