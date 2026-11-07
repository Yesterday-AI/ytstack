# shellcheck shell=bash
# ytstack shared context library -- source it, never execute it.
#
#   . "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-ctx.sh"
#   yt_read_stdin                 # hook payload -> YT_CWD, YT_SESSION_ID, ...
#   yt_git_ctx "${YT_CWD:-$PWD}"  # git context of the dir the agent works in
#   YT_DIR=$(yt_resolve_yt_dir)   # .ytstack dir (project or user scope)
#   STATE=$(yt_state_dir)         # out-of-tree per-session state dir
#
# Contract (DECISIONS 2026-11-07 "Hooks never write relative to
# CLAUDE_PROJECT_DIR"): Claude Code pins CLAUDE_PROJECT_DIR to the
# session-start directory and it does NOT follow the agent into a linked
# worktree; only the hook payload's `cwd` does. Every hook and skill preamble
# therefore resolves its target through this library and never writes
# relative to CLAUDE_PROJECT_DIR or a basename slug.
#
# Portability: macOS /bin/bash 3.2 and Linux bash 5. No arrays, no `local -n`,
# no `readlink -f`, no `flock`. Every function sets YT_* globals and returns 0,
# so callers do not need `set -e` guards. Keys are the first 16 hex chars of
# sha256 (readable paths; collision risk is irrelevant at this scale).

# yt_sha16 <string> -> 16 hex chars. Keys only need to be stable and
# collision-free at the scale of one machine's repos, so the fastest native
# digest wins: md5 (C, ~5 ms) over shasum (perl, ~110 ms). Hooks run on a
# 1.5 s budget and call this twice.
yt_sha16() {
  if [ -x /sbin/md5 ]; then
    printf '%s' "$1" | /sbin/md5 -q | cut -c1-16
  elif command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$1" | md5sum | cut -c1-16
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-16
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -c1-16
  else
    printf '%s' "$1" | cksum | cut -d' ' -f1
  fi
}

# yt_jq -> path of a real jq binary, preferring system/homebrew binaries over
# version-manager shims (an asdf shim costs ~150-250 ms per call). Empty when
# jq is unavailable or YT_FORCE_NO_JQ is set. Cached in YT_JQ.
yt_jq() {
  if [ -n "${YT_FORCE_NO_JQ:-}" ]; then YT_JQ=""; printf ''; return 0; fi
  if [ -z "${YT_JQ+x}" ]; then
    YT_JQ=""
    local c
    for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do
      if [ -x "$c" ]; then YT_JQ="$c"; break; fi
    done
    if [ -z "$YT_JQ" ] && command -v jq >/dev/null 2>&1; then YT_JQ=$(command -v jq); fi
  fi
  printf '%s' "$YT_JQ"
}

# yt_canon <path> -> canonical absolute dir path (symlinks resolved), or the
# input unchanged when it is not a directory.
yt_canon() {
  if [ -d "$1" ]; then
    (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

# yt_python -> path of a real python3, preferring homebrew/local binaries over
# version-manager shims and over the macOS /usr/bin/python3 stub (0.4-1 s
# startup). Empty when none exists. Cached in YT_PY.
yt_python() {
  if [ -z "${YT_PY+x}" ]; then
    YT_PY=""
    local c
    for c in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
      if [ -x "$c" ]; then YT_PY="$c"; break; fi
    done
    if [ -z "$YT_PY" ] && command -v python3 >/dev/null 2>&1; then YT_PY=$(command -v python3); fi
  fi
  printf '%s' "$YT_PY"
}

# yt_read_stdin: capture the hook payload once (idempotent) and parse the
# fields hooks need. Uses jq, falls back to python3 (or YT_FORCE_NO_JQ=1).
# YT_CWD is kept only when it names an existing directory.
yt_read_stdin() {
  if [ -z "${YT_STDIN+x}" ]; then
    if [ -t 0 ]; then YT_STDIN=""; else YT_STDIN=$(cat 2>/dev/null); fi
  fi
  YT_CWD=""; YT_SESSION_ID=""; YT_HOOK_EVENT=""; YT_TOOL_CMD=""; YT_TOOL_EXIT=""
  YT_TRIGGER=""; YT_REASON=""
  [ -n "$YT_STDIN" ] || return 0
  local out="" jq_bin
  jq_bin=$(yt_jq)
  if [ -n "$jq_bin" ]; then
    out=$(printf '%s' "$YT_STDIN" | "$jq_bin" -r '
      "YT_CWD="        + ((.cwd // "") | tostring | @sh) + " " +
      "YT_SESSION_ID=" + ((.session_id // "") | tostring | @sh) + " " +
      "YT_HOOK_EVENT=" + ((.hook_event_name // "") | tostring | @sh) + " " +
      "YT_TRIGGER="    + ((.trigger // "") | tostring | @sh) + " " +
      "YT_REASON="     + ((.reason // "") | tostring | @sh) + " " +
      "YT_TOOL_CMD="   + (((.tool_input | objects | .command) // "") | tostring | @sh) + " " +
      "YT_TOOL_EXIT="  + (((.tool_response | objects | .exit_code) // .exit_code // "") | tostring | @sh)
    ' 2>/dev/null) || out=""
  elif [ -n "$(yt_python)" ]; then
    out=$(printf '%s' "$YT_STDIN" | "$(yt_python)" -I -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
if not isinstance(d, dict):
    d = {}
def s(v):
    return "" if v is None else str(v)
ti = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
tr = d.get("tool_response") if isinstance(d.get("tool_response"), dict) else {}
ex = tr.get("exit_code")
if ex is None:
    ex = d.get("exit_code")
print("YT_CWD=%s YT_SESSION_ID=%s YT_HOOK_EVENT=%s YT_TRIGGER=%s YT_REASON=%s YT_TOOL_CMD=%s YT_TOOL_EXIT=%s" % tuple(
    shlex.quote(s(x)) for x in (d.get("cwd"), d.get("session_id"), d.get("hook_event_name"), d.get("trigger"), d.get("reason"), ti.get("command"), ex)))
' 2>/dev/null) || out=""
  fi
  if [ -n "$out" ]; then eval "$out"; fi
  if [ -n "$YT_CWD" ] && [ ! -d "$YT_CWD" ]; then YT_CWD=""; fi
  return 0
}

# yt_git_ctx [dir]: resolve the Git context of <dir> (default: YT_CWD, then
# $PWD). Sets YT_IS_GIT, YT_TOPLEVEL, YT_GIT_DIR, YT_COMMON_DIR,
# YT_IS_LINKED, YT_MAIN_TOPLEVEL, YT_REPO_KEY, YT_WT_KEY.
yt_git_ctx() {
  local dir="${1:-${YT_CWD:-$PWD}}"
  YT_IS_GIT=no; YT_IS_LINKED=no
  YT_TOPLEVEL=""; YT_GIT_DIR=""; YT_COMMON_DIR=""; YT_MAIN_TOPLEVEL=""
  YT_REPO_KEY=""; YT_WT_KEY=""
  [ -d "$dir" ] || dir="$PWD"
  dir=$(yt_canon "$dir")

  if [ "$(git -C "$dir" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
    YT_IS_GIT=yes
    YT_TOPLEVEL=$(yt_canon "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)")

    # --path-format=absolute needs git >= 2.31; fall back to the older flags.
    YT_GIT_DIR=$(git -C "$dir" rev-parse --path-format=absolute --git-dir 2>/dev/null) \
      || YT_GIT_DIR=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)
    YT_GIT_DIR=$(yt_canon "$YT_GIT_DIR")

    YT_COMMON_DIR=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
      || YT_COMMON_DIR=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)
    case "$YT_COMMON_DIR" in
      /*) ;;                                 # already absolute
      "") YT_COMMON_DIR="$YT_GIT_DIR" ;;     # very old git: assume not linked
      *)  YT_COMMON_DIR="$dir/$YT_COMMON_DIR" ;;  # relative to <dir>
    esac
    YT_COMMON_DIR=$(yt_canon "$YT_COMMON_DIR")

    if [ "$YT_GIT_DIR" != "$YT_COMMON_DIR" ]; then YT_IS_LINKED=yes; fi
    case "$YT_COMMON_DIR" in
      */.git) YT_MAIN_TOPLEVEL="${YT_COMMON_DIR%/.git}" ;;
    esac
    YT_REPO_KEY=$(yt_sha16 "$YT_COMMON_DIR")
  else
    YT_TOPLEVEL="$dir"
    YT_REPO_KEY=$(yt_sha16 "$YT_TOPLEVEL")
  fi
  YT_WT_KEY=$(yt_sha16 "$YT_TOPLEVEL")
  return 0
}

# yt_state_base -> root of the out-of-tree state tree.
# Order: CLAUDE_PLUGIN_DATA (Claude Code), PLUGIN_DATA (Codex adapter),
# $XDG_STATE_HOME/ytstack, ~/.local/state/ytstack.
yt_state_base() {
  printf '%s' "${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_STATE_HOME:-$HOME/.local/state}/ytstack}}"
}

# yt_state_wt_dir -> per-repo, per-worktree state dir (created). Falls back
# to <toplevel>/.ytstack/.local when the base is not writable and a .ytstack
# dir exists; otherwise to a tmp dir -- never into a tree without .ytstack.
yt_state_wt_dir() {
  YT_STATE_FALLBACK=no
  YT_STATE_WT_DIR="$(yt_state_base)/repos/${YT_REPO_KEY:-unknown}/worktrees/${YT_WT_KEY:-unknown}"
  if ! mkdir -p "$YT_STATE_WT_DIR" 2>/dev/null; then
    YT_STATE_FALLBACK=yes
    local top="${YT_TOPLEVEL:-$PWD}"
    if [ -d "$top/.ytstack" ]; then
      YT_STATE_WT_DIR="$top/.ytstack/.local"
    else
      YT_STATE_WT_DIR="${TMPDIR:-/tmp}/ytstack-$(id -u 2>/dev/null || echo u)/repos/${YT_REPO_KEY:-unknown}/worktrees/${YT_WT_KEY:-unknown}"
    fi
    mkdir -p "$YT_STATE_WT_DIR" 2>/dev/null || true
  fi
  printf '%s' "$YT_STATE_WT_DIR"
}

# yt_state_dir -> per-session state dir (created). Session-keyed files are
# single-writer, which is the concurrency model (no flock on macOS).
yt_state_dir() {
  yt_state_wt_dir >/dev/null
  YT_STATE_DIR="$YT_STATE_WT_DIR/sessions/${YT_SESSION_ID:-nosession}"
  mkdir -p "$YT_STATE_DIR" 2>/dev/null || true
  printf '%s' "$YT_STATE_DIR"
}

# yt_commit_ref_pattern <yt_dir> <M###> <S##> <T##> -> ERE that identifies
# this task's commits in `git log` subjects. Source: `commit_ref_pattern:` in
# <yt_dir>/PREFERENCES.md (surrounding quotes stripped, otherwise literal),
# default '^M###-S##-T##:'. Tokens M### / S## / T## / {task} are rendered.
yt_commit_ref_pattern() {
  local ytd="$1" m="$2" s="$3" t="$4" pat=""
  if [ -n "$ytd" ] && [ -f "$ytd/PREFERENCES.md" ]; then
    pat=$(sed -n 's/^commit_ref_pattern: *//p' "$ytd/PREFERENCES.md" | head -1)
    pat="${pat#\"}"; pat="${pat%\"}"
    pat="${pat#\'}"; pat="${pat%\'}"
  fi
  [ -n "$pat" ] || pat='^M###-S##-T##:'
  pat="${pat//\{task\}/$m-$s-$t}"
  pat="${pat//M###/$m}"
  pat="${pat//S##/$s}"
  pat="${pat//T##/$t}"
  printf '%s' "$pat"
}

# yt_task_commits <toplevel> <pattern> -> YT_COMMITS (lines "- `sha` -- subject")
# and YT_COMMITS_SOURCE=task-ref|branch|none.
#   1. subjects matching <pattern> (ERE) anywhere in history
#   2. else: commits on the current branch since its merge-base with the
#      default branch (origin/HEAD, origin/main, main, master -- first that
#      resolves and is not HEAD itself); squash-merge / conventional-commit
#      repos land here
#   3. else none
yt_task_commits() {
  local top="$1" pat="$2" base="" cand
  YT_COMMITS=""; YT_COMMITS_SOURCE=none; YT_COMMITS_BASE=""
  [ -d "$top" ] || return 0
  YT_COMMITS=$(git -C "$top" log --no-merges -E --grep "$pat" --pretty=format:'- `%h` -- %s' 2>/dev/null)
  if [ -n "$YT_COMMITS" ]; then YT_COMMITS_SOURCE=task-ref; return 0; fi
  local head; head=$(git -C "$top" rev-parse HEAD 2>/dev/null) || return 0
  for cand in origin/HEAD origin/main origin/master main master; do
    base=$(git -C "$top" merge-base HEAD "$cand" 2>/dev/null) || continue
    [ -n "$base" ] && [ "$base" != "$head" ] && break
    base=""
  done
  if [ -n "$base" ]; then
    YT_COMMITS=$(git -C "$top" log --no-merges --pretty=format:'- `%h` -- %s' "$base..HEAD" 2>/dev/null)
    if [ -n "$YT_COMMITS" ]; then YT_COMMITS_SOURCE=branch; YT_COMMITS_BASE=$(git -C "$top" rev-parse --short "$base" 2>/dev/null); fi
  fi
  return 0
}

# yt_ensure_gitignore <toplevel> -> make sure <toplevel>/.gitignore ignores
# `.ytstack/.local/` (the in-tree fallback for volatile session state).
# Idempotent; appends a marked block, never touches other lines, never ignores
# the user-owned `.ytstack/HANDOFF.md`. Sets YT_GITIGNORE=written|unchanged|skipped.
yt_ensure_gitignore() {
  local top="$1" gi
  YT_GITIGNORE=skipped
  [ -d "$top" ] || return 0
  gi="$top/.gitignore"
  if [ -f "$gi" ] && grep -q '^\.ytstack/\.local/$' "$gi" 2>/dev/null; then
    YT_GITIGNORE=unchanged; return 0
  fi
  {
    # own line even when the existing file lacks a trailing newline
    if [ -s "$gi" ] && [ "$(tail -c 1 "$gi" 2>/dev/null | od -An -c | tr -d ' ')" != '\n' ]; then printf '\n'; fi
    [ -s "$gi" ] && printf '\n'
    printf '# ytstack local state (fallback session dir; see hooks/lib/git-ctx.sh)\n.ytstack/.local/\n'
  } >> "$gi" 2>/dev/null && YT_GITIGNORE=written
  return 0
}

# ---- gstack as an installed dependency (M017, DECISIONS 2026-11-07) --------
# ytstack's three planning wrappers (office-hours, plan-ceo-review,
# plan-eng-review) invoke the gstack skills installed under
# ${GSTACK_HOME:-$HOME/.claude/skills/gstack}. YT_GSTACK_PIN is the release
# ytstack is tested against (gstack tag v<pin>); newer is accepted, older warns.
YT_GSTACK_PIN="1.96.0.0"
YT_BUN_MIN="1.4.2"

# yt_vergte <a> <b>: dotted-numeric compare, success when a >= b. Missing
# components count as 0; non-numeric parts are ignored. bash 3.2, no arrays.
yt_vergte() {
  local a="$1" b="$2" x y i=0
  [ -n "$a" ] || return 1
  while [ $i -lt 6 ]; do
    x="${a%%.*}"; y="${b%%.*}"
    x="${x//[!0-9]/}"; y="${y//[!0-9]/}"
    x="${x:-0}"; y="${y:-0}"
    if [ "$x" -gt "$y" ]; then return 0; fi
    if [ "$x" -lt "$y" ]; then return 1; fi
    case "$a" in *.*) a="${a#*.}";; *) a="";; esac
    case "$b" in *.*) b="${b#*.}";; *) b="";; esac
    [ -z "$a" ] && [ -z "$b" ] && return 0
    i=$((i+1))
  done
  return 0
}

# yt_gstack_skill_ok <name> -> yes|no (SKILL.md present in the install)
yt_gstack_skill_ok() {
  if [ -n "${YT_GSTACK_DIR:-}" ] && [ -f "$YT_GSTACK_DIR/$1/SKILL.md" ]; then printf 'yes'; else printf 'no'; fi
}

# yt_gstack_ctx: sets YT_GSTACK_DIR, YT_GSTACK_AVAILABLE, YT_GSTACK_VERSION,
# YT_GSTACK_PIN_OK, YT_BUN, YT_BUN_VERSION, YT_BUN_OK, YT_GSTACK_INSTALL_CMD.
yt_gstack_ctx() {
  YT_GSTACK_DIR="${GSTACK_HOME:-$HOME/.claude/skills/gstack}"
  YT_GSTACK_AVAILABLE=no; YT_GSTACK_VERSION=""; YT_GSTACK_PIN_OK=no
  YT_BUN=""; YT_BUN_VERSION=""; YT_BUN_OK=no
  if [ -f "$YT_GSTACK_DIR/VERSION" ]; then
    YT_GSTACK_VERSION=$(head -1 "$YT_GSTACK_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')
    if [ "$(yt_gstack_skill_ok office-hours)" = yes ] && [ "$(yt_gstack_skill_ok plan-ceo-review)" = yes ] && [ "$(yt_gstack_skill_ok plan-eng-review)" = yes ]; then
      YT_GSTACK_AVAILABLE=yes
    fi
    if yt_vergte "$YT_GSTACK_VERSION" "$YT_GSTACK_PIN"; then YT_GSTACK_PIN_OK=yes; fi
  fi
  if command -v bun >/dev/null 2>&1; then
    YT_BUN=$(command -v bun)
    YT_BUN_VERSION=$("$YT_BUN" --version 2>/dev/null | head -1 | tr -d '[:space:]')
    if yt_vergte "$YT_BUN_VERSION" "$YT_BUN_MIN"; then YT_BUN_OK=yes; fi
  fi
  YT_GSTACK_INSTALL_CMD="git clone --branch v$YT_GSTACK_PIN https://github.com/garrytan/gstack \"$YT_GSTACK_DIR\" && (cd \"$YT_GSTACK_DIR\" && ./setup --no-browser)"
  return 0
}

# yt_resolve_yt_dir -> the .ytstack dir for the resolved toplevel: project
# scope (<toplevel>/.ytstack) first, then user scope keyed by YT_REPO_KEY.
# Sets YT_DIR and YT_SCOPE (project|user|none). No basename slugs.
yt_resolve_yt_dir() {
  local top="${YT_TOPLEVEL:-$PWD}"
  YT_DIR=""; YT_SCOPE=none
  if [ -d "$top/.ytstack" ]; then
    YT_DIR="$top/.ytstack"; YT_SCOPE=project
  elif [ -n "${YT_REPO_KEY:-}" ] && [ -d "$HOME/.ytstack/projects/$YT_REPO_KEY" ]; then
    YT_DIR="$HOME/.ytstack/projects/$YT_REPO_KEY"; YT_SCOPE=user
  fi
  printf '%s' "$YT_DIR"
}
