#!/usr/bin/env bash
# Tests for bin/ytstack-upstream: the upstream feedback channel's helper
# (M033, docs/ux/upstream-feedback.md).
#
# Contract:
#   mode   the effective setting: suggest by default, PREFERENCES.md over
#          ~/.ytstack/config; gh is asked only for file, and file without a
#          gh login is suggest with a note; the repository is named
#   draft  an issue body with version, host, OS and TODO lines under $TMPDIR
#          (or --out), never inside the checkout, never over an existing file;
#          refuses an unknown kind or a missing title; never calls gh
#   check  a filled draft passes; each rule fails on its own: a TODO left, an
#          empty Evidence section, no Searched line, an email address (noreply
#          excepted), a token-looking string, a home directory path
#
# Run: /bin/bash tests/ytstack-upstream.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-upstream"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-upstream is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytup.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
P="$TMP/proj"; H="$TMP/home"; FAKE="$TMP/fake"; DRAFTS="$TMP/drafts"
mkdir -p "$P/.ytstack" "$H" "$FAKE" "$DRAFTS"
( cd "$P" || exit 2; git init -q && git config user.email t@t.t && git config user.name t ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }
printf 'name: fixture\n' > "$P/.ytstack/PROJECT.md"

# A stand-in for gh: logs every call; `auth status` passes when GH_AUTH=yes.
cat > "$FAKE/gh" <<'EOF'
#!/bin/sh
echo "$*" >> "$GH_LOG"
[ "$1 $2" = "auth status" ] && { [ "$GH_AUTH" = yes ] && exit 0 || { echo "not logged in" >&2; exit 1; }; }
exit 0
EOF
chmod +x "$FAKE/gh"
GH_LOG="$TMP/gh.log"; : > "$GH_LOG"

run() { OUT=$(cd "$TMP" && PATH="$FAKE:$PATH" HOME="$H" TMPDIR="$DRAFTS" GH_LOG="$GH_LOG" GH_AUTH="${GH_AUTH:-yes}" bash "$BIN" "$@" 2>&1); EC=$?; }

echo "# usage"
run; eq "no command: exit 64" 64 "$EC"
run frobnicate; eq "unknown command: exit 64" 64 "$EC"
run -C "$TMP/nope" mode; eq "-C on a missing directory: exit 64" 64 "$EC"
run --help; eq "--help: exit 0" 0 "$EC"; has "--help names the three commands" "mode" "$OUT"

echo "# mode"
run -C "$P" mode
eq "default: exit 0" 0 "$EC"
has "default: suggest" "mode: suggest" "$OUT"
has "default: where it came from" "set: suggest (default)" "$OUT"
has "default: gh not asked" "gh: not checked" "$OUT"
has "the repository is named" "repo: Yesterday-AI/ytstack" "$OUT"
eq "suggest: gh was not called" "" "$(cat "$GH_LOG")"

printf 'upstream_feedback: off\n' > "$P/.ytstack/PREFERENCES.md"
run -C "$P" mode; has "PREFERENCES off: off" "mode: off" "$OUT"; has "and from PREFERENCES" "set: off (preferences)" "$OUT"

rm -f "$P/.ytstack/PREFERENCES.md"; mkdir -p "$H/.ytstack"; printf 'upstream_feedback=file\n' > "$H/.ytstack/config"
GH_AUTH=yes run -C "$P" mode
has "config file with a gh login: file" "mode: file" "$OUT"
has "and from the config" "set: file (config)" "$OUT"
has "gh: yes" "gh: yes" "$OUT"
has "gh was asked for its login" "auth status" "$(cat "$GH_LOG")"

GH_AUTH=no run -C "$P" mode
has "file without a gh login: suggest" "mode: suggest" "$OUT"
has "the setting stays visible" "set: file (config)" "$OUT"
has "gh: no" "gh: no" "$OUT"
has "a note says why" "note: file needs a signed-in gh" "$OUT"

printf 'upstream_feedback: suggest\n' > "$P/.ytstack/PREFERENCES.md"
run -C "$P" mode; has "PREFERENCES over the config" "set: suggest (preferences)" "$OUT"
printf 'upstream_feedback: always\n' > "$P/.ytstack/PREFERENCES.md"
run -C "$P" mode; has "invalid: suggest" "mode: suggest" "$OUT"; has "invalid: a warning line" "warning: upstream_feedback: 'always' is not suggest|file|off (using suggest)" "$OUT"
rm -f "$P/.ytstack/PREFERENCES.md" "$H/.ytstack/config"

echo "# draft"
: > "$GH_LOG"
run draft --kind gap --title "lane-retro has no upstream section" --host claude-code
eq "draft: exit 0" 0 "$EC"
D=$(printf '%s\n' "$OUT" | sed -n 's/^path: //p')
case "$D" in "$DRAFTS"/*) ok "draft: written under TMPDIR" ;; *) bad "draft: written under TMPDIR" "$D" ;; esac
[ -f "$D" ] && ok "draft: the file exists" || bad "draft: the file exists" "$D"
has "draft: prints the title" "title: lane-retro has no upstream section" "$OUT"
BODY=$(cat "$D" 2>/dev/null)
VER=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -1)
has "draft: kind" "Kind: gap" "$BODY"
has "draft: What happened" "## What happened" "$BODY"
has "draft: Evidence" "## Evidence" "$BODY"
has "draft: Proposal" "## Proposal" "$BODY"
has "draft: the ytstack version" "ytstack $VER" "$BODY"
has "draft: the host" "host claude-code" "$BODY"
has "draft: the OS" "$(uname -s)" "$BODY"
has "draft: the Searched line to fill" "Searched: TODO" "$BODY"
eq "draft: gh was not called" "" "$(cat "$GH_LOG")"
run draft --kind gap --title "x" --out "$D"; eq "draft: an existing file is not overwritten" 1 "$EC"
run draft --kind wish --title "x"; eq "draft: unknown kind -> 64" 64 "$EC"
run draft --kind bug; eq "draft: no title -> 64" 64 "$EC"
run draft --kind bug --title "x" --out "$TMP/mine.md"; eq "draft: --out" "$TMP/mine.md" "$(printf '%s\n' "$OUT" | sed -n 's/^path: //p')"
CLAUDECODE=1 run draft --kind bug --title "host detection" --out "$TMP/h.md"
has "draft: host detected in Claude Code" "host claude-code" "$(cat "$TMP/h.md")"

echo "# check"
good() {
  cat > "$TMP/good.md" <<'EOF'
Kind: gap

## What happened

The coordinator built its own PR babysitter; `ytstack-pr-watch` existed but nothing pointed at it.

## Evidence

- ytstack 0.9.1, Claude Code; `ytstack-pr-watch status` printed `off` for 3 sessions.
- 7 PRs were polled by hand, 41 `gh pr view` calls in one day.

## Proposal

The coordinate preamble names the PR watch when it is off.

---
ytstack 0.9.1 | host claude-code | Darwin
Searched: gh issue list --search "pr watch babysitter" -> no match
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
}
good
run check "$TMP/good.md"; eq "check: a filled draft passes" 0 "$EC"; has "check: says so" "draft ok" "$OUT"
run check "$D"; eq "check: the unfilled draft fails" 1 "$EC"; has "check: names a TODO line" "TODO" "$OUT"
run check "$TMP/none.md"; eq "check: a missing file fails" 1 "$EC"
run check; eq "check: no file -> 64" 64 "$EC"

mut() { # mut <name> <awk program over good.md> <expected text>
  good; awk "$2" "$TMP/good.md" > "$TMP/m.md"
  run check "$TMP/m.md"
  if [ "$EC" -eq 1 ]; then ok "check: $1 fails"; else bad "check: $1 fails" "exit $EC: $OUT"; fi
  has "check: $1 is named" "$3" "$OUT"
}
mut "a TODO left" '{ print } /^## Proposal/ { print "TODO: the proposal" }' "still a TODO"
mut "an empty Evidence section" '/^- / { next } { print }' "Evidence is empty"
mut "no Searched line" '!/^Searched:/' "no Searched: line"
mut "an empty Searched line" '{ sub(/^Searched:.*/, "Searched:"); print }' "no Searched: line"
mut "an email address" '{ print } /^## Evidence/ { print "Reported by jane.doe@example.com" }' "an email address"
# Built here, so that no token-looking literal sits in this file.
B64=$(printf 'Ab1%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14)
mut "a token-looking string" "{ print } /^## Evidence/ { print \"- the header carried $B64\" }" "a token-looking string"
hasnt "check: the token is not repeated in the report" "$B64" "$OUT"
mut "a macOS home path" '{ print } /^## Evidence/ { print "- ran /Users/jane/work/acme/bin/x" }' "a home directory path"
mut "a Linux home path" '{ print } /^## Evidence/ { print "- ran /home/jane/acme" }' "a home directory path"
good; printf 'Ran ~/work/x and /Users/Shared/x\n' >> "$TMP/good.md"
run check "$TMP/good.md"; eq "check: ~/ and /Users/Shared pass" 0 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
