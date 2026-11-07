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

# ---- 8. commit ref pattern ---------------------------------------------------
echo "# commit ref pattern"
PREF="$TMP/pref"; mkdir -p "$PREF"
pat() { ( . "$LIB"; yt_commit_ref_pattern "$@" ); }
eq "pattern: default renders tokens"   '^M042-S03-T07:' "$(pat "$PREF" M042 S03 T07)"
printf 'commit_ref_pattern: "^feat\\({task}\\)"\n' > "$PREF/PREFERENCES.md"
eq "pattern: custom with {task}, quotes stripped" '^feat\(M042-S03-T07\)' "$(pat "$PREF" M042 S03 T07)"
printf -- "---\ncommit_ref_pattern: '\\\\(#T##\\\\)'\n---\n" > "$PREF/PREFERENCES.md"
eq "pattern: single quotes stripped, T## rendered" '\(#T07\)' "$(pat "$PREF" M042 S03 T07)"
printf 'other: x\n' > "$PREF/PREFERENCES.md"
eq "pattern: missing key -> default" '^M042-S03-T07:' "$(pat "$PREF" M042 S03 T07)"

# ---- 9. task commit discovery ----------------------------------------------
echo "# task commits"
CR=$(new_repo commits)
( cd "$CR" || exit 2
  git branch -M main
  echo 1 > a; git add a; git commit -qm "M042-S03-T07: add a"
  echo 2 > b; git add b; git commit -qm "chore: unrelated"
  echo 3 > c; git add c; git commit -qm "M042-S03-T07: add c" ) >/dev/null 2>&1
disc() { ( . "$LIB"; yt_task_commits "$1" "$2"; printf '%s|%s' "$YT_COMMITS_SOURCE" "$(printf '%s' "$YT_COMMITS" | grep -c .)" ); }
eq "commits: task-ref finds 2 of 3"      "task-ref|2" "$(disc "$CR" '^M042-S03-T07:')"
( cd "$CR" || exit 2; git checkout -qb feature; echo 4 > d; git add d; git commit -qm "feat: d via conventional commit"; echo 5 > e; git add e; git commit -qm "fix: e" ) >/dev/null 2>&1
eq "commits: branch fallback (2 since main)" "branch|2" "$(disc "$CR" '^M999-S99-T99:')"
( cd "$CR" || exit 2; git checkout -qb empty-branch ) >/dev/null 2>&1
eq "commits: branch fallback finds 2 on empty-branch too (base = main)" "branch|2" "$(disc "$CR" '^M999-S99-T99:')"
( cd "$CR" || exit 2; git checkout -q main ) >/dev/null 2>&1
eq "commits: none on main without ref match" "none|0" "$(disc "$CR" '^M999-S99-T99:')"
CWT="$TMP/commits-wt"; git -C "$CR" worktree add -q -b wt-x "$CWT" >/dev/null 2>&1
( cd "$CWT" || exit 2; echo 6 > f; git add f; git commit -qm "M042-S03-T08: in worktree" ) >/dev/null 2>&1
eq "commits: worktree discovery uses the worktree HEAD" "task-ref|1" "$(disc "$CWT" '^M042-S03-T08:')"

# ---- 10. gitignore block ----------------------------------------------------
echo "# gitignore block"
GI=$(new_repo gi)
gi() { ( . "$LIB"; yt_ensure_gitignore "$1" >/dev/null; printf '%s' "$YT_GITIGNORE" ); }
eq "gitignore: fresh repo -> written"        written   "$(gi "$GI")"
eq "gitignore: block line present"           1         "$(grep -c '^\.ytstack/\.local/$' "$GI/.gitignore")"
eq "gitignore: second call -> unchanged"     unchanged "$(gi "$GI")"
eq "gitignore: still exactly one block line" 1         "$(grep -c '^\.ytstack/\.local/$' "$GI/.gitignore")"
GI2=$(new_repo gi2); printf 'node_modules/\n*.log' > "$GI2/.gitignore"   # no trailing newline
eq "gitignore: existing file without trailing newline -> written" written "$(gi "$GI2")"
eq "gitignore: original last line intact"    1         "$(grep -c '^\*\.log$' "$GI2/.gitignore")"
eq "gitignore: block on its own line"        1         "$(grep -c '^\.ytstack/\.local/$' "$GI2/.gitignore")"
eq "gitignore: node_modules kept"            1         "$(grep -c '^node_modules/$' "$GI2/.gitignore")"
if grep -q 'HANDOFF' "$GI/.gitignore"; then bad "gitignore: HANDOFF.md must not be ignored"; else ok "gitignore: HANDOFF.md not ignored"; fi
if git -C "$GI" check-ignore -q .ytstack/.local/x; then ok "gitignore: git ignores .ytstack/.local/"; else bad "gitignore: git ignores .ytstack/.local/"; fi

# ---- 11. gstack install context --------------------------------------------
echo "# gstack ctx"
GH="$TMP/gshome"; mkdir -p "$GH"
gs() { ( . "$LIB"; HOME="$1" GSTACK_HOME="${2:-}" yt_gstack_ctx >/dev/null; eval "printf '%s' \"\${$3:-}\"" ); }
eq "gstack: empty HOME -> not available"      no  "$(gs "$GH" "" YT_GSTACK_AVAILABLE)"
eq "gstack: empty HOME -> version empty"      ""  "$(gs "$GH" "" YT_GSTACK_VERSION)"
eq "gstack: empty HOME -> pin not ok"         no  "$(gs "$GH" "" YT_GSTACK_PIN_OK)"
case "$(gs "$GH" "" YT_GSTACK_INSTALL_CMD)" in *"--branch v1."*"/.claude/skills/gstack"*"./setup --no-browser"*) ok "gstack: install cmd names pin, dir and setup";; *) bad "gstack: install cmd names pin, dir and setup" "$(gs "$GH" "" YT_GSTACK_INSTALL_CMD)";; esac
GI="$GH/.claude/skills/gstack"; mkdir -p "$GI/office-hours" "$GI/plan-ceo-review" "$GI/plan-eng-review" "$GI/bin"
printf '1.96.0.0\n' > "$GI/VERSION"; for s in office-hours plan-ceo-review plan-eng-review; do printf -- '---\nname: %s\n---\n' "$s" > "$GI/$s/SKILL.md"; done
eq "gstack: fake install -> available"        yes "$(gs "$GH" "" YT_GSTACK_AVAILABLE)"
eq "gstack: version read"                     1.96.0.0 "$(gs "$GH" "" YT_GSTACK_VERSION)"
eq "gstack: pin ok at exact pin"              yes "$(gs "$GH" "" YT_GSTACK_PIN_OK)"
eq "gstack: skill ok office-hours"            yes "$( . "$LIB"; HOME="$GH" yt_gstack_ctx >/dev/null; yt_gstack_skill_ok office-hours )"
eq "gstack: skill ok missing skill -> no"     no  "$( . "$LIB"; HOME="$GH" yt_gstack_ctx >/dev/null; yt_gstack_skill_ok ship )"
printf '1.95.3.0\n' > "$GI/VERSION"
eq "gstack: older version -> pin not ok"      no  "$(gs "$GH" "" YT_GSTACK_PIN_OK)"
eq "gstack: older version -> still available" yes "$(gs "$GH" "" YT_GSTACK_AVAILABLE)"
ALT="$TMP/gsalt"; mkdir -p "$ALT/office-hours" "$ALT/plan-ceo-review" "$ALT/plan-eng-review"; printf '2.0.0.0\n' > "$ALT/VERSION"
for s in office-hours plan-ceo-review plan-eng-review; do printf -- '---\nname: %s\n---\n' "$s" > "$ALT/$s/SKILL.md"; done
eq "gstack: GSTACK_HOME override wins"        2.0.0.0 "$(gs "$GH" "$ALT" YT_GSTACK_VERSION)"
eq "gstack: GSTACK_HOME dir reported"         "$ALT" "$(gs "$GH" "$ALT" YT_GSTACK_DIR)"
vg() { ( . "$LIB"; yt_vergte "$1" "$2" && printf yes || printf no ); }
eq "vergte: equal"                 yes "$(vg 1.96.0.0 1.96.0.0)"
eq "vergte: numeric not lexical"   yes "$(vg 1.100.0.0 1.96.0.0)"
eq "vergte: lower"                 no  "$(vg 1.9.0.0 1.96.0.0)"
eq "vergte: fewer components"      yes "$(vg 2.0 1.96.0.0)"
eq "vergte: empty lhs -> no"       no  "$(vg '' 1.96.0.0)"
# bun's launcher needs the real HOME (exit 126 under a foreign HOME), so this case keeps HOME and overrides only GSTACK_HOME.
if command -v bun >/dev/null 2>&1; then
  eq "bun: detected on this machine (>= 1.4.2)" yes "$( . "$LIB"; GSTACK_HOME="$ALT" yt_gstack_ctx >/dev/null; printf '%s' "$YT_BUN_OK" )"
else
  ok "bun: not installed here -- detection case skipped"
fi
eq "bun: absent PATH -> no" no "$( . "$LIB"; PATH=/nonexistent HOME="$GH" yt_gstack_ctx >/dev/null; printf '%s' "$YT_BUN_OK" )"

# ---- 12. preferences ----------------------------------------------------------
echo "# preferences"
PY="$TMP/prefs"; mkdir -p "$PY"
pref() { ( . "$LIB"; yt_pref "$@" ); }
prefs() { ( . "$LIB"; yt_prefs "$1" >/dev/null; printf '%s|%s|%s|%s|%s' "$YT_PREF_GRANULARITY" "$YT_PREF_AUTONOMY" "$YT_PREF_QUICK_LANE" "$YT_PREF_MINIMAL_CODE" "${YT_PREF_WARNINGS:-}" ); }
eq "pref: absent file -> default"            task "$(pref "$PY" granularity task)"
eq "pref: absent file, no default -> empty"  ""   "$(pref "$PY" granularity)"
eq "prefs: defaults without file"            "task|loop|on|on|" "$(prefs "$PY")"
printf -- '---\nautonomy: step\n---\n\n# Preferences\n\n## Ceremony\n\ngranularity: "slice"   # smallest unit\nquick_lane: off\ncommit_ref_pattern: '"'"'^feat\\({task}\\)'"'"'\n' > "$PY/PREFERENCES.md"
eq "pref: body value, quotes + trailing comment stripped" slice "$(pref "$PY" granularity task)"
eq "pref: frontmatter value"                 step "$(pref "$PY" autonomy loop)"
eq "pref: single quotes stripped"            '^feat\({task}\)' "$(pref "$PY" commit_ref_pattern)"
eq "prefs: mixed file"                       "slice|step|off|on|" "$(prefs "$PY")"
printf 'granularity: huge\nminimal_code: off\n' > "$PY/PREFERENCES.md"
eq "prefs: invalid granularity -> default + warning" "task|loop|on|off|granularity: 'huge' is not task|slice|milestone (using task)" "$(prefs "$PY")"
printf 'explain_level=brutal\n' > "$PY/PREFERENCES.md"
eq "pref: key=value legacy form accepted"    brutal "$(pref "$PY" explain_level default)"

# ---- 13. STATE lint -----------------------------------------------------------
echo "# state lint"
SL=$(new_repo statelint); mkdir -p "$SL/.ytstack"
lint() { ( . "$LIB"; yt_state_lint "$1" >/dev/null; printf '%s|%s' "${YT_STATE_WARN_COUNT:-x}" "${YT_STATE_WARNINGS:-}" ); }
write_state() { printf -- '---\nproject: fx\nlast_updated: %s\ncurrent_milestone: %s\nactive_slice: %s\nactive_task: %s\n---\n# State\n' "$1" "$2" "$3" "$4" > "$SL/.ytstack/STATE.md"; }
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
write_state "$NOW" M003 S01 T02
printf -- '---\nmilestone: M003\n---\n' > "$SL/.ytstack/M003-CONTEXT.md"; printf -- '---\nmilestone: M003\nstatus: in-progress\n---\n' > "$SL/.ytstack/M003-ROADMAP.md"
( cd "$SL" && git add -A && git commit -qm "state" ) >/dev/null 2>&1
eq "lint: clean state -> 0 warnings"                 "0|" "$(lint "$SL/.ytstack")"
rm -f "$SL/.ytstack/STATE.md"
case "$(lint "$SL/.ytstack")" in 1\|*STATE.md\ missing*) ok "lint: missing STATE.md -> single warning";; *) bad "lint: missing STATE.md" "$(lint "$SL/.ytstack")";; esac
write_state "yesterday" M3 S1 T02
case "$(lint "$SL/.ytstack")" in 3\|*) ok "lint: three malformed fields -> 3 warnings";; *) bad "lint: malformed fields" "$(lint "$SL/.ytstack")";; esac
case "$(lint "$SL/.ytstack")" in *last_updated*) ok "lint: names last_updated";; *) bad "lint: names last_updated";; esac
write_state "$NOW" M003 S01 T02
printf -- '---\nmilestone: M005\n---\n' > "$SL/.ytstack/M005-CONTEXT.md"
case "$(lint "$SL/.ytstack")" in *"behind"*M005*) ok "lint: pointer behind newest milestone (M005)";; *) bad "lint: pointer behind" "$(lint "$SL/.ytstack")";; esac
rm -f "$SL/.ytstack/M005-CONTEXT.md"
printf -- '---\ntask: T02\nclosed: 2026-01-01T00:00:00Z\n---\n' > "$SL/.ytstack/M003-S01-T02-SUMMARY.md"
case "$(lint "$SL/.ytstack")" in *"already has a summary"*) ok "lint: active task already summarized";; *) bad "lint: closed task active" "$(lint "$SL/.ytstack")";; esac
printf -- '---\ntask: T02\nclosed: draft\n---\n' > "$SL/.ytstack/M003-S01-T02-SUMMARY.md"
eq "lint: draft stub does not count as closed"       "0|" "$(lint "$SL/.ytstack")"
rm -f "$SL/.ytstack/M003-S01-T02-SUMMARY.md"
write_state "$NOW" none S01 T02
case "$(lint "$SL/.ytstack")" in *"milestone is none"*) ok "lint: slice/task set while milestone none";; *) bad "lint: slice while none" "$(lint "$SL/.ytstack")";; esac
write_state "2020-01-01T00:00:00Z" M003 S01 T02
( cd "$SL" && echo x > .ytstack/KNOWLEDGE.md && git add -A && git commit -qm "touch ytstack" ) >/dev/null 2>&1
case "$(lint "$SL/.ytstack")" in *"older than the newest commit"*) ok "lint: stale last_updated vs newest .ytstack commit";; *) bad "lint: stale last_updated" "$(lint "$SL/.ytstack")";; esac
write_state "$NOW" M003 S01 T02
printf -- '---\nmilestone: M003\nstatus: done\n---\n' > "$SL/.ytstack/M003-ROADMAP.md"
case "$(lint "$SL/.ytstack")" in *"status: done"*) ok "lint: done milestone still current with open slice";; *) bad "lint: done but current" "$(lint "$SL/.ytstack")";; esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
