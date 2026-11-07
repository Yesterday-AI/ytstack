#!/usr/bin/env bash
# Regression tests for the read-only / team hooks after their migration to
# hooks/lib/git-ctx.sh (M016-S01-T05): session-start, pre-tool-use-edit,
# task-created, task-completed, teammate-idle.
#
# Contract: every hook resolves its checkout from the payload `cwd` (never
# CLAUDE_PROJECT_DIR), uses no basename slug, and session-start points at the
# latest automatic handoff without writing into the tree.
#
# Run: /bin/bash tests/hooks-readonly.test.sh   (exit 0 = all pass)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
H="$ROOT/hooks"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "found '$3'";; *) ok "$1";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytro.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
PD="$TMP/plugin-data"
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"
in_fixture() { case "$1" in "$TMP"/*) return 0 ;; *) echo "FATAL: refusing to touch non-fixture path '$1'" >&2; exit 2 ;; esac; }

new_repo() {
  local t; t=$(mktemp -d "$TMP/repo.XXXXXX") || exit 2
  ( cd "$t" || exit 2
    git init -q && git config user.email t@t.t && git config user.name t
    mkdir .ytstack
    printf 'project: fixture\nlast_updated: %s\ncurrent_milestone: M999\nactive_slice: S01\nactive_task: T01\n\n# State\n\n## Next action\n\nDo the thing.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .ytstack/STATE.md
    printf 'name: fixture\n' > .ytstack/PROJECT.md
    printf -- '---\nkind: handoff\nevent: user-triggered\n---\n# manual\n' > .ytstack/HANDOFF.md
    printf -- '---\nmilestone: M999\nslice: S01\n---\n# plan\n\n- [ ] T01 -- do it (src/planned.ts)\n- [ ] T02 -- do more\n' > .ytstack/M999-S01-PLAN.md
    printf -- '---\nmilestone: M999\n---\n# roadmap\n' > .ytstack/M999-ROADMAP.md
    printf -- '---\ntask: T01\n---\n## Files\n\n- Modify: src/planned.ts\n' > .ytstack/M999-S01-T01-PLAN.md
    echo seed > f.txt; git add -A; git commit -qm seed
  ) >/dev/null 2>&1 || { echo "FATAL: fixture setup failed" >&2; exit 2; }
  echo "$t"
}

# run <hook> <json-payload> [env...]  -> stdout; stderr to $ERR; exit code in $EC
run() {
  local hook="$1" payload="$2"; shift 2
  ERR="$TMP/err.$$"; : > "$ERR"
  printf '%s' "$payload" | ( cd "$ELSEWHERE" && env CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" CLAUDE_PLUGIN_ROOT="$ROOT" "$@" bash "$H/$hook" 2>"$ERR" >"$TMP/out.$$" )
  EC=$?
  OUT=$(cat "$TMP/out.$$")
}
jstr() { printf '%s' "$1" | jq -Rs .; }

MAIN=$(new_repo)
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1 || { echo FATAL worktree; exit 2; }
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"; ( cd "$PLAIN" && git init -q && git config user.email t@t.t && git config user.name t && echo x > f && git add -A && git commit -qm seed ) >/dev/null 2>&1

# ---- 1. session-start, main checkout ---------------------------------------
echo "# session-start"
# seed an auto handoff via pre-compact so latest-handoff exists
printf '{"session_id":"s0","cwd":%s}' "$(jstr "$MAIN")" | ( cd "$ELSEWHERE" && CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$H/pre-compact" >/dev/null )
run session-start "{\"session_id\":\"s1\",\"cwd\":$(jstr "$MAIN"),\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}"
eq  "ss-main: exit 0" 0 "$EC"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
[ -n "$CTX" ] && ok "ss-main: emits additionalContext JSON" || bad "ss-main: emits additionalContext JSON" "$(printf '%s' "$OUT" | head -c 200)"
has "ss-main: scope project"             "$CTX" "scope: project"
has "ss-main: milestone from fixture"    "$CTX" "M999"
has "ss-main: latest auto handoff line"  "$CTX" "Latest automatic handoff:"
has "ss-main: auto handoff path is out-of-tree" "$CTX" "$PD/repos/"
has "ss-main: manual HANDOFF.md mentioned with event" "$CTX" "HANDOFF.md (event: user-triggered)"
lacks "ss-main: no CLAUDE_PROJECT_DIR path leaked" "$CTX" "$ELSEWHERE"
eq  "ss-main: git status clean" "" "$(git -C "$MAIN" status --porcelain)"
if [ "${#CTX}" -lt 10000 ]; then ok "ss-main: context under 10,000 chars (${#CTX})"; else bad "ss-main: context under 10,000 chars" "${#CTX}"; fi

# ---- 1b. session-start, two milestones in progress (M018 states) ----------
printf -- '---\nmilestone: M998\nstatus: in-progress\n---\n' > "$MAIN/.ytstack/M998-ROADMAP.md"
printf -- '---\nmilestone: M999\nstatus: in-progress\n---\n' > "$MAIN/.ytstack/M999-ROADMAP.md"
run session-start "{\"session_id\":\"s1b\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: two in-progress milestones listed" "$CTX" "Milestones in progress: M998, M999"
rm -f "$MAIN/.ytstack/M998-ROADMAP.md"; printf -- '---\nmilestone: M999\n---\n# roadmap\n' > "$MAIN/.ytstack/M999-ROADMAP.md"   # restore the tracked fixture file
run session-start "{\"session_id\":\"s1c\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
lacks "ss-main: no in-progress line with <2 milestones" "$CTX" "Milestones in progress:"

# ---- 1c. session-start: STATE lint + minimal-code pointer (M018) ----------
has "ss-main: minimal-code pointer injected by default" "$CTX" "Minimal-code guard is on"
cp "$MAIN/.ytstack/STATE.md" "$TMP/state.good"
printf 'project: fixture\ncurrent_milestone: M3\nactive_slice: S01\nactive_task: T01\n' > "$MAIN/.ytstack/STATE.md"
run session-start "{\"session_id\":\"s1d\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: malformed pointer -> STATE lint block" "$CTX" "STATE lint ("
has "ss-main: lint names the bad field"            "$CTX" "current_milestone 'M3' is not M###"
cp "$TMP/state.good" "$MAIN/.ytstack/STATE.md"
printf 'minimal_code: off\n' > "$MAIN/.ytstack/PREFERENCES.md"
run session-start "{\"session_id\":\"s1e\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
lacks "ss-main: minimal_code off -> no pointer" "$CTX" "Minimal-code guard is on"
lacks "ss-main: clean STATE -> no lint block"   "$CTX" "STATE lint ("
if [ "${#CTX}" -lt 9500 ]; then ok "ss-main: injection still under the guard (${#CTX})"; else bad "ss-main: injection under guard" "${#CTX}"; fi
rm -f "$MAIN/.ytstack/PREFERENCES.md"

# ---- 1f. session-start: no roadmap in progress -> clean count, no stderr noise
run session-start "{\"session_id\":\"s1j\",\"cwd\":$(jstr "$MAIN")}"
eq "ss-main: no in-progress roadmap -> no 'integer expression' error on stderr" 0 "$(grep -c 'integer expression' "$ERR")"
eq "ss-main: no in-progress roadmap -> no 'Milestones in progress' line" 0 "$(printf '%s' "$OUT" | grep -c 'Milestones in progress')"
# host context (Codex adapter) is not counted against Claude Code's cap
run session-start "{\"session_id\":\"s1k\",\"cwd\":$(jstr "$MAIN")}" YTSTACK_HOST_CONTEXT="$(printf 'H%.0s' $(seq 1 6000))"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: host context prepended" "$CTX" "HHHHHHHHHH"
has "ss-main: host context does not shed Next action" "$CTX" "Do the thing."

# ---- 1e. session-start: lifecycle hints after a closed slice / milestone (M019-S03)
cp "$MAIN/.ytstack/M999-S01-PLAN.md" "$TMP/slice.good"
printf -- '---\nmilestone: M999\nslice: S01\nstatus: done\n---\n# plan\n\n- [x] T01 -- done\n' > "$MAIN/.ytstack/M999-S01-PLAN.md"
run session-start "{\"session_id\":\"s1g\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: slice done -> reassess + finish-branch/ship hint" "$CTX" "Slice S01 is done: ytstack:reassess-roadmap"
cp "$TMP/slice.good" "$MAIN/.ytstack/M999-S01-PLAN.md"
printf -- '---\nmilestone: M999\nstatus: done\n---\n# roadmap\n' > "$MAIN/.ytstack/M999-ROADMAP.md"
run session-start "{\"session_id\":\"s1h\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: milestone done, no retro -> retro hint" "$CTX" "Milestone M999 is done and has no retro: ytstack:retro"
printf -- '---\nmilestone: M999\n---\n# retro\n' > "$MAIN/.ytstack/M999-RETRO.md"
run session-start "{\"session_id\":\"s1i\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
lacks "ss-main: milestone done with retro -> no retro hint" "$CTX" "has no retro"
rm -f "$MAIN/.ytstack/M999-RETRO.md"; printf -- '---\nmilestone: M999\n---\n# roadmap\n' > "$MAIN/.ytstack/M999-ROADMAP.md"

# ---- 1d. session-start: nested milestones/ layout read-side (M018-S03) -----
mkdir -p "$MAIN/.ytstack/milestones/M777"
printf -- '---\nclosed: 2026-11-07T00:00:00Z\n---\n' > "$MAIN/.ytstack/milestones/M777/M777-S01-T01-SUMMARY.md"
run session-start "{\"session_id\":\"s1f\",\"cwd\":$(jstr "$MAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-main: summary under milestones/M777/ listed in Recent tasks" "$CTX" "M777-S01-T01-SUMMARY"
rm -rf "$MAIN/.ytstack/milestones"

# ---- 2. session-start, greenfield (no .ytstack) ---------------------------
BEFORE=$(find "$PD" -type d | wc -l | tr -d ' ')
run session-start "{\"session_id\":\"s2\",\"cwd\":$(jstr "$PLAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-plain: greenfield scope"          "$CTX" "scope: greenfield"
has "ss-plain: names the cwd repo"        "$CTX" "$PLAIN"
lacks "ss-plain: not CLAUDE_PROJECT_DIR"  "$CTX" "$ELSEWHERE"
eq  "ss-plain: no state dirs created"     "$BEFORE" "$(find "$PD" -type d | wc -l | tr -d ' ')"

# ---- 2b. session-start, existing codebase without .ytstack (M010, #18) -----
BROWN="$TMP/brown"; mkdir -p "$BROWN/docs/adr"
( cd "$BROWN" || exit 2; git init -q && git config user.email t@t.t && git config user.name t
  i=0; while [ $i -lt 40 ]; do echo "line $i" >> README.md; i=$((i+1)); done
  printf '# Guide\n' > docs/guide.md; printf '# Setup\n' > docs/setup.md; printf '# Ops\n' > docs/ops.md
  printf '# ADR\n' > docs/adr/0001.md; printf '# Changelog\n' > CHANGELOG.md
  git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL brownfield fixture; exit 2; }
run session-start "{\"session_id\":\"s2b\",\"cwd\":$(jstr "$BROWN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-brown: still greenfield scope"        "$CTX" "scope: greenfield"
has "ss-brown: says existing codebase"        "$CTX" "existing codebase (4 brownfield signals"
has "ss-brown: names the sources"             "$CTX" "README.md (40 lines), docs/*.md (3 files), CHANGELOG.md, docs/adr/ (1 files)"
has "ss-brown: routes to adopt-brownfield"    "$CTX" "invoke \`ytstack:adopt-brownfield\` FIRST"
lacks "ss-brown: no office-hours-first step"  "$CTX" "invoke \`ytstack:office-hours\` FIRST"
[ "${#CTX}" -lt 9500 ] && ok "ss-brown: injection ${#CTX} chars < 9500 cap guard" || bad "ss-brown: injection under cap" "${#CTX} chars"
eq  "ss-brown: hook exit 0"                   0 "$EC"
[ -z "$(git -C "$BROWN" status --porcelain)" ] && ok "ss-brown: fixture untouched (read-only)" || bad "ss-brown: fixture untouched"
run session-start "{\"session_id\":\"s2c\",\"cwd\":$(jstr "$PLAIN")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-plain: office-hours first stays for empty repos" "$CTX" "invoke \`ytstack:office-hours\` FIRST"
has "ss-plain: mentions adopt-brownfield as the alternative" "$CTX" "ytstack:adopt-brownfield"

# ---- 3. session-start, linked worktree -------------------------------------
run session-start "{\"session_id\":\"s3\",\"cwd\":$(jstr "$WT")}"
CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
has "ss-wt: scope project via worktree .ytstack" "$CTX" "scope: project"
has "ss-wt: ytstack dir is the worktree's"       "$CTX" "$WT/.ytstack"

# ---- 4. pre-tool-use-edit ---------------------------------------------------
echo "# pre-tool-use-edit"
run pre-tool-use-edit "{\"cwd\":$(jstr "$MAIN"),\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":$(jstr "$MAIN/src/other.ts")}}" >/dev/null
eq  "ptue: unplanned path exits 0 (advisory)" 0 "$EC"
has "ptue: unplanned path warns scope drift" "$(cat "$ERR")" "Scope drift"
has "ptue: rel path is checkout-relative"    "$(cat "$ERR")" "src/other.ts"
run pre-tool-use-edit "{\"cwd\":$(jstr "$MAIN"),\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":$(jstr "$MAIN/src/planned.ts")}}" >/dev/null
eq  "ptue: planned path is silent" "" "$(cat "$ERR")"
run pre-tool-use-edit "{\"cwd\":$(jstr "$MAIN"),\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":$(jstr "$MAIN/.ytstack/STATE.md")}}" >/dev/null
eq  "ptue: .ytstack files exempt" "" "$(cat "$ERR")"
run pre-tool-use-edit "{\"cwd\":$(jstr "$WT"),\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":$(jstr "$WT/src/other.ts")}}" >/dev/null
has "ptue: worktree edit resolved against worktree" "$(cat "$ERR")" "src/other.ts"

# ---- 5. task-completed in a worktree ---------------------------------------
echo "# task-completed"
run task-completed "{\"cwd\":$(jstr "$WT"),\"tool_input\":{\"subject\":\"M999-S01-T02 -- do more\"}}" >/dev/null
eq  "tc: exit 0" 0 "$EC"
if [ -f "$WT/.ytstack/M999-S01-T02-SUMMARY.md" ]; then ok "tc: summary lands in the worktree's .ytstack"; else bad "tc: summary lands in the worktree's .ytstack"; fi
has "tc: summary records worktree" "$(cat "$WT/.ytstack/M999-S01-T02-SUMMARY.md" 2>/dev/null)" "worktree: $WT"
eq  "tc: main checkout clean" "" "$(git -C "$MAIN" status --porcelain)"
has "tc: slice-plan checkbox flipped in worktree" "$(cat "$WT/.ytstack/M999-S01-PLAN.md")" "- [x] T02"
if [ -e "$ELSEWHERE/.ytstack" ]; then bad "tc: nothing under CLAUDE_PROJECT_DIR"; else ok "tc: nothing under CLAUDE_PROJECT_DIR"; fi

# ---- 6. teammate-idle / task-created ---------------------------------------
echo "# teammate-idle / task-created"
run teammate-idle "{\"cwd\":$(jstr "$MAIN")}" >/dev/null
eq  "ti: open tasks -> exit 2" 2 "$EC"
has "ti: reports open count" "$(cat "$ERR")" "2 task(s) still open"
run teammate-idle "{\"cwd\":$(jstr "$PLAIN")}" >/dev/null
eq  "ti: no .ytstack -> exit 0" 0 "$EC"
run task-created "{\"cwd\":$(jstr "$MAIN"),\"tool_input\":{\"subject\":\"touch foo/bar.ts\",\"description\":\"edit foo/bar.ts\"}}" >/dev/null
eq  "tcr: drifted path -> exit 2" 2 "$EC"
has "tcr: names the path" "$(cat "$ERR")" "foo/bar.ts"
run task-created "{\"cwd\":$(jstr "$MAIN"),\"tool_input\":{\"subject\":\"edit src/planned.ts\"}}" >/dev/null
eq  "tcr: planned path -> exit 0" 0 "$EC"

# ---- 7. resolver fully retired ---------------------------------------------
echo "# static"
MISSING=$(grep -L 'lib/git-ctx.sh' "$H"/session-start "$H"/pre-tool-use-edit "$H"/task-created "$H"/task-completed "$H"/teammate-idle "$H"/pre-compact "$H"/session-end "$H"/post-tool-use-bash)
eq  "static: every hook sources the lib" "" "$MISSING"
# Code lines only (comments may explain why CLAUDE_PROJECT_DIR is not used).
LEAK=$(grep -l '^[^#]*CLAUDE_PROJECT_DIR' "$H"/* 2>/dev/null | grep -v '/lib/' | grep -v '\.json$' || true)
eq  "static: no hook uses CLAUDE_PROJECT_DIR" "" "$LEAK"
SLUG=$(grep -l 'basename "$(git rev-parse --show-toplevel' "$H"/* 2>/dev/null || true)
eq  "static: no basename slug in hooks" "" "$SLUG"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
