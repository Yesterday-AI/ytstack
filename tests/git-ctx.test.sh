#!/usr/bin/env bash
# Unit tests for hooks/lib/git-ctx.sh (M016-S01-T01).
#
# Contract (DECISIONS 2026-11-07 "Hooks never write relative to
# CLAUDE_PROJECT_DIR"):
#   - yt_read_stdin parses the hook payload (cwd, session_id, hook event,
#     tool command, exit code) with jq or, without jq, python3.
#   - yt_git_ctx resolves the Git context of the directory the agent works
#     in: toplevel, git dir, common dir, linked-worktree flag, main toplevel,
#     and stable keys (16 hex chars of sha256) for repo and worktree.
#   - yt_state_dir locates the out-of-tree per-session state dir and falls
#     back to <toplevel>/.ytstack/.local when the data dir is not writable.
#   - yt_resolve_yt_dir finds .ytstack without basename slugs.
#
# Run: /bin/bash tests/git-ctx.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LIB="$ROOT/hooks/lib/git-ctx.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
ne()  { if [ "$2" != "$3" ]; then ok "$1"; else bad "$1" "both '$2'"; fi; }

if [ ! -f "$LIB" ]; then
  bad "lib exists at hooks/lib/git-ctx.sh"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

if bash -n "$LIB" 2>/dev/null; then ok "lib parses (bash -n)"; else bad "lib parses (bash -n)"; fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytctx.XXXXXX")
TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t \
    && echo seed > f.txt && git add -A && git commit -qm "seed" )
  echo "$d"
}

# ctx <dir> <var>: value of <var> after yt_git_ctx <dir>, in a clean subshell
ctx() { ( . "$LIB"; yt_git_ctx "$1" >/dev/null; eval "printf '%s' \"\${$2:-}\"" ); }

# ---- 1. main checkout -------------------------------------------------------
echo "# main checkout"
MAIN=$(new_repo main)
mkdir -p "$MAIN/.ytstack"
eq "main: YT_IS_GIT=yes"            yes      "$(ctx "$MAIN" YT_IS_GIT)"
eq "main: YT_IS_LINKED=no"          no       "$(ctx "$MAIN" YT_IS_LINKED)"
eq "main: YT_TOPLEVEL"              "$MAIN"  "$(ctx "$MAIN" YT_TOPLEVEL)"
eq "main: YT_MAIN_TOPLEVEL"         "$MAIN"  "$(ctx "$MAIN" YT_MAIN_TOPLEVEL)"
eq "main: YT_COMMON_DIR"            "$MAIN/.git" "$(ctx "$MAIN" YT_COMMON_DIR)"
eq "main: YT_GIT_DIR == common"     "$(ctx "$MAIN" YT_COMMON_DIR)" "$(ctx "$MAIN" YT_GIT_DIR)"
MAIN_RK=$(ctx "$MAIN" YT_REPO_KEY); MAIN_WK=$(ctx "$MAIN" YT_WT_KEY)
eq "main: repo key is 16 hex chars" 16 "$(printf '%s' "$MAIN_RK" | tr -cd '0-9a-f' | wc -c | tr -d ' ')"
mkdir -p "$MAIN/sub/deeper"
eq "main: toplevel from subdir"     "$MAIN"  "$(ctx "$MAIN/sub/deeper" YT_TOPLEVEL)"
eq "main: resolve .ytstack (project)" "$MAIN/.ytstack" "$( . "$LIB"; yt_git_ctx "$MAIN"; yt_resolve_yt_dir )"
eq "main: YT_SCOPE=project"         project  "$( . "$LIB"; yt_git_ctx "$MAIN"; yt_resolve_yt_dir >/dev/null; printf '%s' "$YT_SCOPE" )"

# ---- 2. linked worktree -----------------------------------------------------
echo "# linked worktree"
WT="$TMP/wt"
git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1
if [ -f "$WT/.git" ]; then ok "wt: .git is a file"; else bad "wt: .git is a file"; fi
eq "wt: YT_IS_GIT=yes"              yes      "$(ctx "$WT" YT_IS_GIT)"
eq "wt: YT_IS_LINKED=yes"           yes      "$(ctx "$WT" YT_IS_LINKED)"
eq "wt: YT_TOPLEVEL is the worktree" "$WT"   "$(ctx "$WT" YT_TOPLEVEL)"
eq "wt: YT_MAIN_TOPLEVEL is main"   "$MAIN"  "$(ctx "$WT" YT_MAIN_TOPLEVEL)"
eq "wt: repo key equals main's"     "$MAIN_RK" "$(ctx "$WT" YT_REPO_KEY)"
ne "wt: worktree key differs"       "$MAIN_WK" "$(ctx "$WT" YT_WT_KEY)"
eq "wt: resolve .ytstack none (no dir in wt)" "" "$( . "$LIB"; yt_git_ctx "$WT"; yt_resolve_yt_dir )"

# ---- 3. non-git dir ---------------------------------------------------------
echo "# non-git dir"
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
eq "plain: YT_IS_GIT=no"            no       "$(ctx "$PLAIN" YT_IS_GIT)"
eq "plain: YT_IS_LINKED=no"         no       "$(ctx "$PLAIN" YT_IS_LINKED)"
eq "plain: YT_TOPLEVEL is the dir"  "$PLAIN" "$(ctx "$PLAIN" YT_TOPLEVEL)"
eq "plain: repo key non-empty"      16 "$(ctx "$PLAIN" YT_REPO_KEY | tr -cd '0-9a-f' | wc -c | tr -d ' ')"
eq "plain: resolve .ytstack empty"  ""       "$( . "$LIB"; yt_git_ctx "$PLAIN"; yt_resolve_yt_dir )"
eq "plain: YT_SCOPE=none"           none     "$( . "$LIB"; yt_git_ctx "$PLAIN"; yt_resolve_yt_dir >/dev/null; printf '%s' "$YT_SCOPE" )"

# ---- 4. submodule -----------------------------------------------------------
echo "# submodule"
SUB=$(new_repo subsrc)
PARENT=$(new_repo parent)
( cd "$PARENT" && git -c protocol.file.allow=always submodule add -q "$SUB" sub >/dev/null 2>&1 && git commit -qm "add sub" )
if [ -f "$PARENT/sub/.git" ]; then ok "submodule: .git is a file"; else bad "submodule: .git is a file"; fi
eq "submodule: YT_IS_LINKED=no"     no       "$(ctx "$PARENT/sub" YT_IS_LINKED)"
eq "submodule: toplevel is sub"     "$PARENT/sub" "$(ctx "$PARENT/sub" YT_TOPLEVEL)"
ne "submodule: repo key != parent"  "$(ctx "$PARENT" YT_REPO_KEY)" "$(ctx "$PARENT/sub" YT_REPO_KEY)"

# ---- 5. macOS /private path spelling ---------------------------------------
echo "# path canonicalisation"
case "$TMP" in
  /private/*)
    ALT="${TMP#/private}/main"
    eq "canon: /private/... and /... give same repo key" "$MAIN_RK" "$(ctx "$ALT" YT_REPO_KEY)"
    eq "canon: toplevel is canonical"  "$MAIN"  "$(ctx "$ALT" YT_TOPLEVEL)"
    ;;
  *) ok "canon: skipped (no /private prefix on this platform)" ;;
esac

# ---- 6. stdin parsing -------------------------------------------------------
echo "# stdin parsing"
PAYLOAD=$(printf '{"session_id":"sess-42","cwd":%s,"hook_event_name":"PostToolUse","tool_input":{"command":"git commit -m \\"x; y\\" && echo '"'"'done'"'"'"},"tool_response":{"exit_code":0,"stdout":"ok"}}' "\"$MAIN\"")
EXPECT="$MAIN|sess-42|PostToolUse|git commit -m \"x; y\" && echo 'done'|0"
read_fields() { ( . "$LIB"; yt_read_stdin; printf '%s|%s|%s|%s|%s' "$YT_CWD" "$YT_SESSION_ID" "$YT_HOOK_EVENT" "$YT_TOOL_CMD" "$YT_TOOL_EXIT" ); }
eq "stdin: jq path parses all fields"     "$EXPECT" "$(printf '%s' "$PAYLOAD" | read_fields)"
eq "stdin: python fallback parses equal"  "$EXPECT" "$(printf '%s' "$PAYLOAD" | YT_FORCE_NO_JQ=1 read_fields)"
eq "stdin: bogus cwd becomes empty"       "|s|||"   "$(printf '{"session_id":"s","cwd":"/nonexistent/dir/xyz"}' | read_fields)"
eq "stdin: empty stdin leaves all empty"  "||||"    "$(read_fields </dev/null)"
eq "stdin: invalid json leaves all empty" "||||"    "$(printf 'not json' | read_fields)"
eq "stdin: tool_response as string does not break" "|s|||" "$(printf '{"session_id":"s","tool_response":"text"}' | read_fields)"
eq "stdin: yt_git_ctx defaults to YT_CWD" "$WT" "$(printf '{"cwd":"%s"}' "$WT" | ( . "$LIB"; yt_read_stdin; yt_git_ctx >/dev/null; printf '%s' "$YT_TOPLEVEL" ))"

# ---- 7. state dir -----------------------------------------------------------
echo "# state dir"
state() { # state <env-assignments...> -- runs yt_state_dir for MAIN with session s1
  ( . "$LIB"; unset CLAUDE_PLUGIN_DATA PLUGIN_DATA XDG_STATE_HOME
    yt_git_ctx "$MAIN" >/dev/null; YT_SESSION_ID=s1
    for kv in "$@"; do export "$kv"; done
    yt_state_dir >/dev/null; printf '%s|%s' "$YT_STATE_DIR" "$YT_STATE_FALLBACK" )
}
eq "state: CLAUDE_PLUGIN_DATA wins" "$TMP/pd/repos/$MAIN_RK/worktrees/$MAIN_WK/sessions/s1|no" "$(state CLAUDE_PLUGIN_DATA="$TMP/pd" PLUGIN_DATA="$TMP/pd2" XDG_STATE_HOME="$TMP/x")"
if [ -d "$TMP/pd/repos/$MAIN_RK/worktrees/$MAIN_WK/sessions/s1" ]; then ok "state: dir created"; else bad "state: dir created"; fi
eq "state: PLUGIN_DATA second"      "$TMP/pd2/repos/$MAIN_RK/worktrees/$MAIN_WK/sessions/s1|no" "$(state PLUGIN_DATA="$TMP/pd2" XDG_STATE_HOME="$TMP/x")"
eq "state: XDG_STATE_HOME third (+/ytstack)" "$TMP/x/ytstack/repos/$MAIN_RK/worktrees/$MAIN_WK/sessions/s1|no" "$(state XDG_STATE_HOME="$TMP/x")"
eq "state: unwritable base falls back to .ytstack/.local" "$MAIN/.ytstack/.local/sessions/s1|yes" "$(state CLAUDE_PLUGIN_DATA=/dev/null/x)"
eq "state: no session id -> nosession" "$TMP/pd/repos/$MAIN_RK/worktrees/$MAIN_WK/sessions/nosession|no" "$( . "$LIB"; unset PLUGIN_DATA XDG_STATE_HOME; yt_git_ctx "$MAIN" >/dev/null; YT_SESSION_ID=""; CLAUDE_PLUGIN_DATA="$TMP/pd" yt_state_dir >/dev/null; printf '%s|%s' "$YT_STATE_DIR" "$YT_STATE_FALLBACK" )"
eq "state: wt dir is parent of sessions" "$TMP/pd/repos/$MAIN_RK/worktrees/$MAIN_WK" "$( . "$LIB"; unset PLUGIN_DATA XDG_STATE_HOME; yt_git_ctx "$MAIN" >/dev/null; CLAUDE_PLUGIN_DATA="$TMP/pd" yt_state_wt_dir )"
# bash 3.2 cannot parse `case ... )` inside $(...), hence the helper
plain_fallback_location() {
  ( . "$LIB"; yt_git_ctx "$PLAIN" >/dev/null; YT_SESSION_ID=s1
    CLAUDE_PLUGIN_DATA=/dev/null/x yt_state_dir >/dev/null
    if [ "${YT_STATE_DIR#"$PLAIN"/}" != "$YT_STATE_DIR" ]; then printf 'in-tree'; else printf 'no-tree'; fi )
}
eq "state: non-ytstack toplevel falls back to tmp, not into the tree" "no-tree" "$(plain_fallback_location)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
