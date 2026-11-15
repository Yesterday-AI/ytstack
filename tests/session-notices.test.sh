#!/usr/bin/env bash
# Tests for the notices a session gets about factory tools that are off
# (M031-S03): yt_factory_notices in hooks/lib/git-ctx.sh and its lines in the
# SessionStart injection.
#
# Contract:
#   risk      .ytstack/spec/ without REVIEW.md, or without an area that allows
#             auto_merge low or normal, while merge_by resolves to risk: one
#             line; merge_by human is a choice and silent
#   pr watch  only with a GitHub origin: no pr_watch line in ~/.ytstack/config
#             is one line, pr_watch=off is silent, pr_watch=on with a heartbeat
#             under 10 minutes is silent, a stale or missing heartbeat is one
#             line; the heartbeat comes from watch.sqlite3, else worker.lock
#   runtime   deploy or signal evidence without "Release" or "Signals" in
#             RUNTIME.md: one line that names the evidence
#   injection the lines appear on SessionStart startup and clear (and without a
#             source), never on resume or compact; a project with none of it
#             sees no factory text; the hook writes no file
#   version   hooks/version-notice (UserPromptSubmit) records the plugin version
#             of a session's first prompt out of tree and says once per
#             installed version "ytstack X installed, this session loaded A:
#             reload the skills you use" with the CHANGELOG entry titles in
#             between, bounded; installed = installed_plugins.json, else the
#             newest cached sibling without .orphaned_at
#
# HOME, CLAUDE_PLUGIN_DATA and the PR watch state are fixture directories.
#
# Run: /bin/bash tests/session-notices.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
H="$ROOT/hooks"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3' in: $(printf '%s' "$2" | tail -c 600)";; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "found '$3'";; *) ok "$1";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytnote.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
# A real jq binary, chosen before HOME moves (a version-manager shim needs it).
JQ=""
for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do [ -x "$c" ] && { JQ=$c; break; }; done
[ -n "$JQ" ] || JQ=$(command -v jq)
export HOME="$TMP/home"; mkdir -p "$HOME"
export CLAUDE_PLUGIN_DATA="$TMP/plugin-data"
export PR_WATCH_HOME="$TMP/prw"
unset YTSTACK_PR_WATCH_HOME CLAUDE_CONFIG_DIR 2>/dev/null || true

# repo <name>: a git checkout with a clean .ytstack. Sets D and Y.
repo() {
  D="$TMP/$1"; Y="$D/.ytstack"; mkdir -p "$Y"
  ( cd "$D" && git init -q && git config user.email t@t.t && git config user.name t \
    && printf -- '---\nproject: n\ncurrent_milestone: none\nactive_slice: none\nactive_task: none\nlast_updated: %s\n---\n\n# State\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .ytstack/STATE.md \
    && git add -A && git commit -qm seed ) >/dev/null 2>&1 || { echo "FATAL: fixture" >&2; exit 2; }
}
# notices: YT_FACTORY_NOTICES of D, from a fresh shell
notices() {
  NOTES=$( bash -c '. "$1/hooks/lib/git-ctx.sh"; yt_git_ctx "$2"; yt_resolve_yt_dir >/dev/null; yt_factory_notices "$YT_DIR" "$YT_TOPLEVEL"; printf "%s" "$YT_FACTORY_NOTICES"' _ "$ROOT" "$D" )
}
# ss <source>: the additionalContext of session-start for D
ss() {
  local src=""
  [ -z "$1" ] || src=",\"source\":\"$1\""
  CTX=$(printf '{"session_id":"n1","cwd":"%s","hook_event_name":"SessionStart"%s}' "$D" "$src" \
    | CLAUDE_PLUGIN_ROOT="$ROOT" bash "$H/session-start" 2>/dev/null | "$JQ" -r '.hookSpecificOutput.additionalContext // empty')
}

# ---- 1. nothing in use ----------------------------------------------------------
echo "# a project that uses none of the tools"
repo plain
notices; eq "no notices" "" "$NOTES"
ss startup; lacks "injection has no factory block" "$CTX" "Factory tools"

# ---- 2. risk routing --------------------------------------------------------------
echo "# risk routing"
repo risk
mkdir -p "$Y/spec"; printf -- '---\narea: core\nauto_merge: none\n---\n' > "$Y/spec/core.md"
notices; has "spec without REVIEW.md: a line" "$NOTES" "Risk routing is not set up (no spec/REVIEW.md, no area allows auto_merge low or normal)"
printf '# Review\n' > "$Y/spec/REVIEW.md"
notices; has "REVIEW.md, no area above none: still a line" "$NOTES" "(no area allows auto_merge low or normal)"
printf -- '---\narea: core\nauto_merge: low\n---\n' > "$Y/spec/core.md"
notices; eq "REVIEW.md and an area with auto_merge low: silent" "" "$NOTES"
rm "$Y/spec/REVIEW.md"; printf 'merge_by: human\n' > "$Y/PREFERENCES.md"
notices; eq "merge_by human is a choice: silent" "" "$NOTES"
printf 'merge_by: risk\n' > "$Y/PREFERENCES.md"
notices; has "merge_by risk without REVIEW.md: a line" "$NOTES" "(no spec/REVIEW.md)"
# auto_merge as ytstack-risk reads it: frontmatter only, quotes allowed (PR #66 review).
printf '# Review\n' > "$Y/spec/REVIEW.md"
printf -- '---\narea: core\nauto_merge: "low"\n---\n' > "$Y/spec/core.md"
notices; eq "a quoted auto_merge \"low\": silent" "" "$NOTES"
printf -- '---\narea: core\nauto_merge: none\n---\n\nExample:\n\nauto_merge: low\n' > "$Y/spec/core.md"
notices; has "auto_merge: low in the body only: a line" "$NOTES" "(no area allows auto_merge low or normal)"
rm "$Y/spec/REVIEW.md"

# ---- 3. PR watch ------------------------------------------------------------------
echo "# PR watch"
repo prw
notices; eq "no GitHub origin: silent" "" "$NOTES"
git -C "$D" remote add origin git@github.com:acme/shop.git
notices; has "GitHub origin, no config line: off" "$NOTES" "PR watch is off for this GitHub repository"
mkdir -p "$HOME/.ytstack"; printf 'pr_watch=off\n' > "$HOME/.ytstack/config"
notices; eq "pr_watch=off is a choice: silent" "" "$NOTES"
printf 'pr_watch=on\n' > "$HOME/.ytstack/config"
notices; has "on without any worker state: never ticked" "$NOTES" "its worker has never ticked"
mkdir -p "$PR_WATCH_HOME"; : > "$PR_WATCH_HOME/worker.lock"
notices; eq "on with a fresh worker.lock: silent" "" "$NOTES"
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$PR_WATCH_HOME/watch.sqlite3" "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT); INSERT INTO meta VALUES('heartbeat','$(( $(date +%s) - 1500 )).25');"
  notices; has "a heartbeat 25 minutes old wins over the lock: stale" "$NOTES" "last ticked 25 minutes ago"
  sqlite3 "$PR_WATCH_HOME/watch.sqlite3" "UPDATE meta SET value='$(date +%s).5' WHERE key='heartbeat'"
  notices; eq "a fresh heartbeat: silent" "" "$NOTES"
  rm -f "$PR_WATCH_HOME/watch.sqlite3"
else
  ok "sqlite3 not on PATH: heartbeat-from-database cases skipped"
fi
git -C "$D" remote set-url origin https://github.com/acme/shop
touch -t 202001010000 "$PR_WATCH_HOME/worker.lock"
notices; has "https origin, old lock: stale" "$NOTES" "PR watch is on, but its worker last ticked"
# pr_watch as hooks/pr-watch reads it: on when any line says on (PR #66 review).
printf 'pr_watch=on\npr_watch=off\n' > "$HOME/.ytstack/config"
notices; has "an on line before an off line: on, as the hook runs" "$NOTES" "PR watch is on, but its worker last ticked"
printf 'pr_watch=yes\n' > "$HOME/.ytstack/config"
notices; has "a value that is neither on nor off: the hook does not run, off" "$NOTES" "PR watch is off for this GitHub repository"
rm -f "$HOME/.ytstack/config"

# ---- 4. RUNTIME.md ----------------------------------------------------------------
echo "# RUNTIME.md sections"
repo rt
printf 'FROM scratch\n' > "$D/Dockerfile"
notices; has "Dockerfile without RUNTIME.md: Release" "$NOTES" 'RUNTIME.md has no "Release" section (the project deploys: Dockerfile): ytstack-watch release cannot run.'
printf '## Release\n\n- deployed: curl -fsS https://x/version\n' > "$Y/RUNTIME.md"
notices; eq "a Release section: silent" "" "$NOTES"
mkdir -p "$Y/incidents"; printf '# x\n' > "$Y/incidents/2026-11-15-outage.md"
notices; has "an incident without Signals: a line" "$NOTES" '"Signals" section (production reports: incidents/)'
lacks "and Release is not named again" "$NOTES" '"Release" section'
repo rt2
mkdir -p "$Y/signals"; printf -- '---\nid: F001\nkind: review\n---\n' > "$Y/signals/F001-x.md"
notices; eq "a review finding alone is no signal evidence" "" "$NOTES"
printf -- '---\nid: F002\nkind: errors\n---\n' > "$Y/signals/F002-y.md"
mkdir -p "$D/.github/workflows"; printf 'on: push\n' > "$D/.github/workflows/deploy-prod.yml"
notices; has "an errors finding and a deploy workflow: both named" "$NOTES" 'no "Release" section (the project deploys: .github/workflows/deploy-prod.yml) and no "Signals" section (production reports: signals/F002-y.md): ytstack-watch release and signal-intake cannot run.'

# ---- 5. the injection -------------------------------------------------------------
echo "# session-start"
repo inj
mkdir -p "$Y/spec"
before=$(find "$TMP/plugin-data" -type f 2>/dev/null | wc -l | tr -d ' ')
ss startup; has "startup: block" "$CTX" "Factory tools (said once per session):"
has "startup: the risk line" "$CTX" "- Risk routing is not set up"
ss clear;   has "clear: block" "$CTX" "Factory tools"
ss "";      has "no source: block" "$CTX" "Factory tools"
ss resume;  lacks "resume: no block" "$CTX" "Factory tools"
ss compact; lacks "compact: no block" "$CTX" "Factory tools"
has "compact still injects the state" "$CTX" "scope: project"
# issue #85: every SessionStart names the running version's bin directory
has "compact: YT_BIN names this version's bins" "$CTX" "
YT_BIN=$ROOT/bin"
# Near the cap the list shrinks to one pointer line (a directive of ~9,000 chars).
mkdir -p "$TMP/bigroot/skills/using-ytstack"
awk 'BEGIN { for (i = 0; i < 90; i++) printf "%0100d\n", i }' > "$TMP/bigroot/skills/using-ytstack/SKILL.md"
CTX=$(printf '{"session_id":"n2","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$D" \
  | CLAUDE_PLUGIN_ROOT="$TMP/bigroot" bash "$H/session-start" 2>/dev/null | "$JQ" -r '.hookSpecificOutput.additionalContext // empty')
has "near the cap: one pointer line" "$CTX" "Factory tools: 1 off (list cut for the 10,000-char cap): bin/ytstack-upkeep names them."
lacks "and not the list" "$CTX" "- Risk routing"
after=$(find "$TMP/plugin-data" -type f 2>/dev/null | wc -l | tr -d ' ')
eq "session-start wrote no state file" "$before" "$after"
eq "and nothing in the checkout" "" "$(git -C "$D" status --porcelain | grep -v '^?? .ytstack/spec' )"

# ---- 6. version notice (UserPromptSubmit) ------------------------------------------
echo "# version-notice"
CACHE="$TMP/cache/mkt/ytstack"
# plugin <version> [<changelog versions newest first>...]: a cached plugin root
plugin() {
  local v="$1" r="$CACHE/$1" c; shift
  mkdir -p "$r/.claude-plugin"
  printf '{\n  "name": "ytstack",\n  "version": "%s"\n}\n' "$v" > "$r/.claude-plugin/plugin.json"
  { printf '# Changelog\n\n## [Unreleased]\n'
    for c in "$@"; do printf '\n## [%s] - 2026-11-15\n\n### Added\n\n- **Feature of %s**: text\n  more text.\n- **Second of %s.** text\n\n### Fixed\n\n- **Fix of %s** (#1): text\n' "$c" "$c" "$c" "$c"; done
  } > "$r/CHANGELOG.md"
}
plugin 0.10.0 0.10.0 0.9.2
plugin 0.11.0 0.11.0 0.10.1 0.10.0 0.9.2
OLD="$CACHE/0.10.0"; NEW="$CACHE/0.11.0"
mkdir -p "$HOME/.claude/plugins"
installed() { printf '{"version":2,"plugins":{"ytstack@mkt":[{"scope":"user","installPath":"%s","version":"x"}],"other@mkt":[{"installPath":"/nowhere"}]}}\n' "$1" > "$HOME/.claude/plugins/installed_plugins.json"; }
# vn <session> <plugin root>: OUT of the hook for a prompt in D
vn() {
  OUT=$(printf '{"session_id":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"go"}' "$1" "$D" \
    | CLAUDE_PLUGIN_ROOT="$2" bash "$H/version-notice" 2>&1); EC=$?
  CTXV=$(printf '%s' "$OUT" | "$JQ" -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}
installed "$OLD"
vn v1 "$OLD"; eq "first prompt, nothing newer: exit 0 and silent" "0:" "$EC:$OUT"
eq "the session's version is recorded out of tree" "0.10.0" "$(cat "$CLAUDE_PLUGIN_DATA/sessions/v1/plugin-version" 2>/dev/null)"
installed "$NEW"
vn v1 "$OLD"
eq "after an update: JSON for UserPromptSubmit" "UserPromptSubmit" "$(printf '%s' "$OUT" | "$JQ" -r '.hookSpecificOutput.hookEventName' 2>/dev/null)"
has "names both versions" "$CTXV" "ytstack 0.11.0 installed, this session loaded 0.10.0: reload the skills you use"
has "lists the entries of 0.11.0" "$CTXV" "0.11.0: Feature of 0.11.0; Second of 0.11.0; Fix of 0.11.0"
has "and of 0.10.1" "$CTXV" "0.10.1: Feature of 0.10.1"
lacks "but not of the loaded version" "$CTXV" "Feature of 0.10.0"
vn v1 "$OLD"; eq "said once" "0:" "$EC:$OUT"
vn v1 "$NEW"; eq "a refreshed hook root in the same session: still once" "0:" "$EC:$OUT"
vn v2 "$NEW"; eq "a new session on the installed version: silent" "0:" "$EC:$OUT"
vn v2b "$OLD"; has "first prompt on a stale root: said at once" "$CTXV" "ytstack 0.11.0 installed, this session loaded 0.10.0"
rm "$HOME/.claude/plugins/installed_plugins.json"
vn v3 "$OLD"; eq "without installed_plugins.json, first prompt records" "0.10.0" "$(cat "$CLAUDE_PLUGIN_DATA/sessions/v3/plugin-version" 2>/dev/null)"
has "and the newest cached sibling counts as installed" "$CTXV" "ytstack 0.11.0 installed"
: > "$NEW/.orphaned_at"
vn v4 "$OLD"; eq "an orphaned sibling does not count" "0:" "$EC:$OUT"
rm "$NEW/.orphaned_at"
OUT=$(printf '{"cwd":"%s","hook_event_name":"UserPromptSubmit"}' "$D" | CLAUDE_PLUGIN_ROOT="$OLD" bash "$H/version-notice" 2>&1); EC=$?
eq "no session id: silent" "0:" "$EC:$OUT"
vn "../escape" "$OLD"; eq "a session id that is no plain name: silent" "0:" "$EC:$OUT"
lacks "and nothing written beside sessions/" "$(ls "$CLAUDE_PLUGIN_DATA")" "escape"
# Bounded: many versions in between stay one short line.
plugin 0.30.0 $(i=30; while [ $i -gt 9 ]; do printf '0.%s.0 ' $i; i=$((i - 1)); done)
installed "$CACHE/0.30.0"
vn v5 "$OLD"; has "many versions: said" "$CTXV" "ytstack 0.30.0 installed"
SHORT=${CTXV//$CACHE\/0.30.0\/CHANGELOG.md/F}
if [ "${#SHORT}" -le 900 ]; then ok "and bounded (${#SHORT} chars without the path)"; else bad "and bounded" "${#SHORT}"; fi
has "with the rest pointed at" "$CTXV" "more in"
OUT=$(printf '{"session_id":"v6","cwd":"%s"}' "$D" | CLAUDE_PLUGIN_ROOT="$OLD" YTSTACK_HOOK_FORMAT=plain bash "$H/version-notice" 2>&1)
has "plain format: raw text" "$OUT" "ytstack 0.30.0 installed, this session loaded 0.10.0"
# Which entries of installed_plugins.json count (PR #66 review): scope user,
# or project/local for this project only, and only this plugin's marketplace.
entries() { printf '{"version":2,"plugins":{"ytstack@mkt":[{"scope":"user","installPath":"%s"}%s]%s}}\n' "$OLD" "$1" "$2" > "$HOME/.claude/plugins/installed_plugins.json"; }
entries "" ",\"ytstack@othermkt\":[{\"scope\":\"user\",\"installPath\":\"$CACHE/0.30.0\"}]"
vn v7 "$OLD"; eq "another marketplace's newer ytstack does not count" "0:" "$EC:$OUT"
entries ",{\"scope\":\"project\",\"projectPath\":\"$TMP/elsewhere\",\"installPath\":\"$CACHE/0.30.0\"}" ""
vn v8 "$OLD"; eq "a project-scope install of another project does not count" "0:" "$EC:$OUT"
entries ",{\"scope\":\"local\",\"projectPath\":\"$D\",\"installPath\":\"$CACHE/0.30.0\"}" ""
vn v9 "$OLD"; has "a local-scope install of this project counts" "$CTXV" "ytstack 0.30.0 installed"
# The marker is written only after the notice was printed.
OUT=$(printf '{"session_id":"v10","cwd":"%s"}' "$D" | CLAUDE_PLUGIN_ROOT="$OLD" YTSTACK_HOOK_FORMAT=plain bash "$H/version-notice" 2>/dev/null >&-)
eq "a notice that could not be printed leaves no marker" "no" "$([ -e "$CLAUDE_PLUGIN_DATA/sessions/v10/notified-0.30.0" ] && echo yes || echo no)"
vn v10 "$OLD"; has "and is said on the next prompt" "$CTXV" "ytstack 0.30.0 installed"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
