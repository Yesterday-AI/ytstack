#!/usr/bin/env bash
# Tests for bin/ytstack-standing: the write and read path of the standing
# instructions (.ytstack/standing/, docs/ux/coordinator-format.md; issues
# #72, #73, #74).
#
# Contract:
#   add --here   one entry file in the resolved .ytstack/standing/, name from
#                UTC now and a slug, given/scope/supersedes and the optional
#                keys, the text as body; ytstack-check --standing must pass,
#                else nothing is written (exit 1); user scope is always --here
#   add          in a dedicated worktree outside the checkout on
#                standing/<YYYYMMDD>: commit, push, one PR per day (gh pr
#                create, or ytstack-pr-watch create with pr_watch=on), a second
#                add the same day updates it; the checkout stays unchanged;
#                push failure -> exit 3 with the commit kept
#   end          a kind-end entry that supersedes the one it closes, with its scope
#   list         active entries (pending ones from standing branches marked),
#                ended ones (until passed, until-check exit 0), conditions to
#                check, failed checks; commands are bounded by
#                YTSTACK_STANDING_TIMEOUT; --no-checks runs none; the first line
#                counts the session's human prompts since the newest entry
#
# Run: /bin/bash tests/ytstack-standing.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-standing"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }
grep_q() { grep "$@" >/dev/null; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-standing exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytstanding.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
# A version-manager shim needs the real HOME: pick the binaries before HOME moves.
PY=$( . "$ROOT/hooks/lib/git-ctx.sh"; yt_python )
[ -n "$PY" ] || { echo "FATAL: python3 not found"; exit 2; }
export YTSTACK_PYTHON="$PY"
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME"
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID CLAUDE_PLUGIN_DATA PLUGIN_DATA 2>/dev/null
export GIT_CONFIG_NOSYSTEM=1
git config --global user.email t@t.t; git config --global user.name t
git config --global commit.gpgsign false; git config --global init.defaultBranch main

# ---- the fake host ---------------------------------------------------------------
FAKE="$TMP/fakebin"; GH_FIX="$TMP/host"; mkdir -p "$FAKE" "$GH_FIX"
cat > "$FAKE/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_FIX/log"
case "${1:-} ${2:-}" in
  "pr list")   [ ! -f "$GH_FIX/list.out" ] || cat "$GH_FIX/list.out" ;;
  "pr create") [ ! -f "$GH_FIX/create.fail" ] || exit 1; echo "https://github.com/acme/demo/pull/5" ;;
  "api repos/acme/demo/pulls/5") echo '{"number": 5}' ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$FAKE/gh"
export PATH="$FAKE:$PATH" GH_FIX

# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
NAME_RE='^[0-9]{8}T[0-9]{4}Z-[a-z0-9-]+\.md$'

# ---- 1. --here: write, validate ----------------------------------------------------
echo "# add --here"
P="$TMP/p"; mkdir -p "$P/.ytstack"; ( cd "$P" && git init -q ) || exit 2
run "$P" add "Merge green pull requests promptly. Ask first for anything red." --scope "the coordinator" --here
eq "add --here: exit 0" 0 "$EC"
F=$(ls "$P/.ytstack/standing" | head -1)
if printf '%s\n' "$F" | grep -Eq "$NAME_RE"; then ok "name <YYYYMMDDTHHMMZ>-<slug>.md ($F)"; else bad "name pattern" "$F"; fi
has "slug from the first words" "merge-green-pull-requests-promptly" "$F"
C=$(cat "$P/.ytstack/standing/$F")
has "given in the minute of the name" "given: $(printf '%s' "$F" | sed -E 's/^([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})Z.*/\1-\2-\3T\4:\5:00Z/')" "$C"
has "scope" "scope: the coordinator" "$C"
has "empty supersedes" "supersedes: " "$C"
has "the text is the body" "Merge green pull requests promptly." "$C"
hasnt "no optional key when not given" "until" "$C"
eq "the entry passes ytstack-check --standing" 0 "$("$PY" "$ROOT/bin/ytstack-check" --standing "$P" >/dev/null 2>&1; echo $?)"

run "$P" add "Hold merges" --scope "every lane" --until 2020-01-01T00:00Z --here
eq "until before given: exit 1" 1 "$EC"; has "names the problem" "not after given" "$OUT"
run "$P" add "Hold merges" --scope "every lane" --until tomorrow --here
eq "until not ISO: exit 1" 1 "$EC"
eq "nothing written by the refused adds" 1 "$(ls "$P/.ytstack/standing" | grep -c .)"
run "$P" add "No scope" --here; eq "add without --scope: exit 64" 64 "$EC"
run "$P" add "Hold" --scope x --supersedes 20200101T0000Z-nothing --here
eq "supersedes an unknown entry: exit 1" 1 "$EC"

# ---- 2. list: active, ended, to check, failed checks ---------------------------------
echo "# list"
L="$TMP/l"; SD="$L/.ytstack/standing"; mkdir -p "$SD"; ( cd "$L" && git init -q ) || exit 2
w() { printf -- '---\ngiven: %s\nscope: %s\nsupersedes:\n%b---\n\n%s\n' "$2" "$3" "$4" "$5" > "$SD/$1.md"; }
w 20261101T1000Z-old-window 2026-11-01T10:00:00Z "every lane" 'until: 2026-11-01T12:37Z\n' "Hold merges until the measurement ends."
w 20261101T1100Z-pr-hold 2026-11-01T11:00:00Z "every lane" 'until-condition: PR #1879 merged\n' "Do not touch PR 1336 while the v2 plan runs."
w 20261101T1200Z-done-by-check 2026-11-01T12:00:00Z "the coordinator" 'until-check: exit 0\n' "Raise the PR limit during the load test."
w 20261101T1300Z-lanes-file 2026-11-01T13:00:00Z "the coordinator" 'check: echo "LANES.md last changed 14 h ago"; exit 1\n' "Lanes are tracked in LANES.md at all times."
w 20261101T1400Z-slow 2026-11-01T14:00:00Z "the coordinator" 'until-check: sleep 30\n' "A slow condition."
w 20261101T1500Z-plain 2026-11-01T15:00:00Z "every reviewer" '' "Every review names the reviewed commit."
start=$(date +%s)
OUT=$(YTSTACK_STANDING_TIMEOUT=1 bash "$BIN" -C "$L" list 2>&1); EC=$?
took=$(( $(date +%s) - start ))
eq "list: exit 0" 0 "$EC"
has "first line names the newest entry" "newest entry: 20261101T1500Z-plain (" "$OUT"
has "no session -> prompts not counted" "human prompts since: not counted" "$OUT"
has "active section counts" "active (4):" "$OUT"
has "an active entry with scope and first sentence" "- 20261101T1500Z-plain (every reviewer): Every review names the reviewed commit." "$OUT"
has "until passed -> ended" "- 20261101T1000Z-old-window: until 2026-11-01T12:37Z passed" "$OUT"
has "until-check exit 0 -> ended" "- 20261101T1200Z-done-by-check: until-check exited 0" "$OUT"
has "until-condition -> to check" "- 20261101T1100Z-pr-hold: PR #1879 merged" "$OUT"
has "a failed check is shown with its output" "- 20261101T1300Z-lanes-file: exit 1: LANES.md last changed 14 h ago" "$OUT"
has "a slow until-check times out and stays active" "A slow condition. [until-check timed out]" "$OUT"
if [ "$took" -le 4 ]; then ok "the timeout bounds the run ($took s)"; else bad "the timeout bounds the run" "$took s"; fi
OUT=$(bash "$BIN" -C "$L" list --no-checks 2>&1)
hasnt "--no-checks: no until-check runs" "until-check exited 0" "$OUT"
hasnt "--no-checks: no check runs" "check failed" "$OUT"
has "--no-checks says so" "not run: --no-checks" "$OUT"
has "--no-checks: time-based expiry still applies" "until 2026-11-01T12:37Z passed" "$OUT"

# ---- 3. end ---------------------------------------------------------------------------
echo "# end"
run "$L" end 20261101T1100Z-pr-hold --reason "PR #1879 merged at 2026-11-02T09:00Z" --here
eq "end: exit 0" 0 "$EC"
E=$(ls "$SD" | grep end-pr-hold)
C=$(cat "$SD/$E" 2>/dev/null)
has "end entry: kind end" "kind: end" "$C"
has "end entry: supersedes the closed one" "supersedes: 20261101T1100Z-pr-hold" "$C"
has "end entry: copies the scope" "scope: every lane" "$C"
has "end entry: body names the reason" "Ended: PR #1879 merged at 2026-11-02T09:00Z." "$C"
OUT=$(bash "$BIN" -C "$L" list --no-checks 2>&1)
hasnt "the closed entry is gone from the list" "- 20261101T1100Z-pr-hold" "$OUT"
hasnt "the end entry is no instruction" "Ended:" "$OUT"
eq "ytstack-check --standing accepts the end entry" 0 "$("$PY" "$ROOT/bin/ytstack-check" --standing "$L" >/dev/null 2>&1; echo $?)"
run "$L" end 20200101T0000Z-nothing --reason x --here; eq "end of an unknown entry: exit 1" 1 "$EC"

# ---- 4. prompt counter ----------------------------------------------------------------
echo "# prompts since the newest entry"
SESS="$XDG_STATE_HOME/ytstack/sessions/sess-1"; mkdir -p "$SESS"
printf '%s\n' "$L/.ytstack" > "$SESS/coordinate"
printf '%s\n%s\n%s\n' 1000 "$(date +%s)" "$(date +%s)" > "$SESS/prompts"
OUT=$(CLAUDE_CODE_SESSION_ID=sess-1 bash "$BIN" -C "$L" list --no-checks 2>&1)
has "two prompts after the newest entry are counted" "human prompts since: 2" "$OUT"

# ---- 5. user scope is always --here ----------------------------------------------------
echo "# user scope"
U="$TMP/u"; mkdir -p "$U"; ( cd "$U" && git init -q && git commit -q --allow-empty -m seed ) || exit 2
KEY=$( . "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$U"; printf '%s' "$YT_REPO_KEY" )
mkdir -p "$HOME/.ytstack/projects/$KEY"
run "$U" add "Status only at slice boundaries." --scope "this project"
eq "user scope add: exit 0" 0 "$EC"
eq "written into the user-scope directory" 1 "$(ls "$HOME/.ytstack/projects/$KEY/standing" 2>/dev/null | grep -c .)"
eq "nothing in the checkout" "" "$(git -C "$U" status --porcelain)"

# ---- 6. default: dedicated worktree, one PR per day ------------------------------------
echo "# add: worktree, commit, push, PR"
BARE="$TMP/remote.git"; git init -q --bare "$BARE"
M="$TMP/m"; git init -q "$M"
( cd "$M" || exit 2
  git config url."$BARE".insteadOf https://github.com/acme/demo.git
  git remote add origin https://github.com/acme/demo.git
  mkdir .ytstack && printf 'x\n' > .ytstack/STATE.md && git add -A && git commit -qm seed && git push -q -u origin main
  git remote set-head origin main ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }
DAY=$(date -u +%Y%m%d)
rm -f "$GH_FIX/log"
run "$M" add "Never merge a red main." --scope "every lane"
eq "add: exit 0" 0 "$EC"
has "names the branch of the day" "committed on standing/$DAY" "$OUT"
has "a new PR is opened" "standing PR opened: https://github.com/acme/demo/pull/5" "$OUT"
LOG=$(cat "$GH_FIX/log" 2>/dev/null)
has "gh pr create on the day branch against main" "pr create --repo acme/demo --base main --head standing/$DAY" "$LOG"
eq "the checkout is unchanged" "" "$(git -C "$M" status --porcelain)"
[ ! -d "$M/.ytstack/standing" ] && ok "no entry in the checkout's tree" || bad "no entry in the checkout's tree"
REMOTE_FILES=$(git --git-dir="$BARE" ls-tree --name-only "standing/$DAY" -- .ytstack/standing/ 2>/dev/null)
has "pushed: the remote branch has the entry" "never-merge-a-red-main" "$REMOTE_FILES"
WT="$XDG_STATE_HOME/ytstack/repos"
case "$OUT" in *"$TMP/state/ytstack/repos/"*standing-worktree*) ok "the worktree is outside the checkout" ;; *) bad "the worktree is outside the checkout" "$OUT" ;; esac
SUBJ=$(git --git-dir="$BARE" log -1 --format=%s "standing/$DAY")
has "commit subject" "chore: standing: " "$SUBJ"

echo 7 > "$GH_FIX/list.out"; rm -f "$GH_FIX/log"
run "$M" add "Status only at slice boundaries." --scope "this project"
eq "second add: exit 0" 0 "$EC"
has "the open PR of the day is updated" "standing PR #7 updated" "$OUT"
hasnt "no second PR" "pr create" "$(cat "$GH_FIX/log" 2>/dev/null)"
eq "two commits on the day branch" 2 "$(git --git-dir="$BARE" rev-list --count "main..standing/$DAY")"

OUT=$(bash "$BIN" -C "$M" list --no-checks 2>&1)
has "list in the checkout shows the unmerged entries as pending" "(pending: standing/$DAY)" "$OUT"
has "both pending entries are active" "active (2):" "$OUT"

echo "# push failure"
rm -f "$GH_FIX/list.out"
git -C "$M" config url."$TMP/nowhere.git".insteadOf https://github.com/acme/demo.git
git -C "$M" config --unset url."$BARE".insteadOf
run "$M" add "Keep the PR limit at 15." --scope "the coordinator"
eq "push fails: exit 3" 3 "$EC"
has "says the commit stays" "the commit stays" "$OUT"
git -C "$M" config --unset url."$TMP/nowhere.git".insteadOf
git -C "$M" config url."$BARE".insteadOf https://github.com/acme/demo.git

echo "# pr-watch create when the PR watch is on"
# ytstack-pr-watch create reads `git remote get-url origin`, which applies
# insteadOf: keep the GitHub URL for fetch (refused at once, no network) and
# push to the bare repository.
git -C "$M" config --unset url."$BARE".insteadOf
git -C "$M" config remote.origin.pushurl "$BARE"
mkdir -p "$HOME/.ytstack"; printf 'pr_watch=on\n' > "$HOME/.ytstack/config"
rm -f "$GH_FIX/list.out" "$GH_FIX/log"
OUT=$(GIT_ALLOW_PROTOCOL=file CLAUDE_CODE_SESSION_ID=sess-1 YTSTACK_PR_WATCH_HOME="$TMP/prw" bash "$BIN" -C "$M" add "Review every push once." --scope "every reviewer" 2>&1); EC=$?
eq "add with pr_watch=on: exit 0" 0 "$EC"
has "the PR comes from ytstack-pr-watch create" "monitor registered" "$OUT"
has "and gh created it" "pr create --repo acme/demo" "$(cat "$GH_FIX/log" 2>/dev/null)"
eq "the push of the earlier failed commit went out too" 4 "$(git --git-dir="$BARE" rev-list --count "main..standing/$DAY")"
rm -f "$HOME/.ytstack/config"
git -C "$M" config --unset remote.origin.pushurl
git -C "$M" config url."$BARE".insteadOf https://github.com/acme/demo.git

# ---- 7. which commands run (review of PR #87) ------------------------------------
echo "# commands run only from merged entries"
OUT=$(bash "$BIN" -C "$M" list 2>&1)
eq "pending entries' commands do not run (nothing to run in them yet)" "" "$(printf '%s' "$OUT" | grep 'check failed')"
# an attacker pushes a branch standing/evil with a check; no local branch tracks it
OTHER="$TMP/other"; git clone -q "$BARE" "$OTHER" 2>/dev/null
( cd "$OTHER" || exit 2; git switch -q -c standing/evil; mkdir -p .ytstack/standing
  printf -- '---\ngiven: 2026-11-15T10:00:00Z\nscope: the coordinator\nsupersedes:\ncheck: touch %s/PWNED\n---\n\nHarmless looking.\n' "$TMP" > .ytstack/standing/20261115T1000Z-x.md
  git add -A && git commit -qm evil && git push -q origin standing/evil ) >/dev/null 2>&1
git -C "$M" fetch -q origin 2>/dev/null
OUT=$(bash "$BIN" -C "$M" list 2>&1)
[ ! -e "$TMP/PWNED" ] && ok "a remote-only branch's check does not run" || bad "a remote-only branch's check does not run"
hasnt "a remote-only branch is not read at all" "20261115T1000Z-x" "$OUT"
# a pending entry on this machine's standing branch with a check
OUT=$(bash "$BIN" -C "$M" add "Keep LANES.md current." --scope "the coordinator" --check "touch $TMP/RAN-PENDING; exit 1" 2>&1)
OUT=$(bash "$BIN" -C "$M" list 2>&1)
[ ! -e "$TMP/RAN-PENDING" ] && ok "a pending entry's check does not run" || bad "a pending entry's check does not run"
has "and says so" "[check not run: pending] (pending: standing/$DAY)" "$OUT"
# an entry in the checkout that is not on the default branch
mkdir -p "$M/.ytstack/standing"
printf -- '---\ngiven: 2026-11-15T09:00:00Z\nscope: the coordinator\nsupersedes:\ncheck: touch %s/RAN-LOCAL; exit 1\n---\n\nLocal only.\n' "$TMP" > "$M/.ytstack/standing/20261115T0900Z-local.md"
OUT=$(bash "$BIN" -C "$M" list 2>&1)
[ ! -e "$TMP/RAN-LOCAL" ] && ok "an unmerged working-tree entry's check does not run" || bad "an unmerged working-tree entry's check does not run"
has "and says why" "[check not run: not on origin/main]" "$OUT"
( cd "$M" && git add .ytstack/standing/20261115T0900Z-local.md && git commit -qm local && git push -q origin main ) >/dev/null 2>&1
OUT=$(bash "$BIN" -C "$M" list 2>&1)
[ -e "$TMP/RAN-LOCAL" ] && ok "once on the default branch the check runs" || bad "once on the default branch the check runs" "$OUT"
has "and its failure is shown" "- 20261115T0900Z-local: exit 1" "$OUT"

echo "# pending entries reach the lines of the injection and the briefs"
L2=$( . "$ROOT/hooks/lib/git-ctx.sh"; yt_standing_lines "$M/.ytstack" coordinator )
has "a pending entry is in yt_standing_lines, marked" "keep-lanes-md-current (the coordinator): Keep LANES.md current. [pending:standing/$DAY]" "$L2"
L3=$( . "$ROOT/hooks/lib/git-ctx.sh"; yt_standing_lines "$M/.ytstack" lane )
hasnt "the role filter applies to pending entries" "keep-lanes-md-current" "$L3"

echo "# an earlier day's pending branch: supersede it, push it first"
( cd "$M" || exit 2; git switch -q -c standing/20200101 origin/main; mkdir -p .ytstack/standing
  printf -- '---\ngiven: 2020-01-01T10:00:00Z\nscope: every lane\nsupersedes:\nuntil: 2020-01-02T00:00Z\n---\n\nHold merges.\n' > .ytstack/standing/20200101T1000Z-hold.md
  git add -A && git commit -qm old && git switch -q main ) >/dev/null 2>&1
git --git-dir="$BARE" rev-parse -q --verify standing/20200101 >/dev/null && bad "fixture: the old branch is unpushed" || ok "fixture: the old branch is unpushed"
git --git-dir="$BARE" branch -q -D "standing/$DAY" 2>/dev/null; git -C "$M" branch -q -D "standing/$DAY" 2>/dev/null
git -C "$XDG_STATE_HOME/ytstack/repos"/*/standing-worktree switch -q --detach 2>/dev/null
git -C "$M" branch -q -D "standing/$DAY" 2>/dev/null; git -C "$M" update-ref -d "refs/remotes/origin/standing/$DAY"
OUT=$(bash "$BIN" -C "$M" end 20200101T1000Z-hold --reason "the window passed" 2>&1); EC=$?
eq "end of an entry on an earlier day's pending branch: exit 0" 0 "$EC"
has "the earlier unpushed branch was pushed first" "pushed the earlier standing branch standing/20200101" "$OUT"
git --git-dir="$BARE" rev-parse -q --verify standing/20200101 >/dev/null && ok "and is on origin now" || bad "and is on origin now"
has "the new day's branch carries the earlier entry" "20200101T1000Z-hold.md" "$(git --git-dir="$BARE" ls-tree --name-only "standing/$DAY" -- .ytstack/standing/)"

echo "# timeouts, the command limit, one-line values"
K="$TMP/k"; KS="$K/.ytstack/standing"; mkdir -p "$KS"; ( cd "$K" && git init -q ) || exit 2
printf -- '---\ngiven: 2026-11-01T10:00:00Z\nscope: x\nsupersedes:\nuntil-check: sleep 43; echo late\n---\n\nSlow.\n' > "$KS/20261101T1000Z-slow.md"
OUT=$(YTSTACK_STANDING_TIMEOUT=1 bash "$BIN" -C "$K" list 2>&1)
sleep 1
eq "a timeout ends the command's children too" 0 "$(ps -eo args 2>/dev/null | grep -c '[s]leep 43')"
rm -f "$KS"/*.md
for i in 10 11 12 13 14 15 16 17 18 19 20; do
  printf -- '---\ngiven: 2026-11-01T10:%s:00Z\nscope: x\nsupersedes:\ncheck: true\n---\n\nEntry %s.\n' "$i" "$i" > "$KS/20261101T10${i}Z-e$i.md"
done
OUT=$(bash "$BIN" -C "$K" list 2>&1)
eq "past 10 commands one entry says it was not run" 1 "$(printf '%s\n' "$OUT" | grep -c 'check not run: limit of 10 commands per list')"
run "$K" add "Hold." --scope x --until "2026-12-01T00:00Z
until: 2027-01-01T00:00Z" --here
eq "--until with a newline: exit 64" 64 "$EC"
run "$K" add "Hold." --scope x --supersedes "a
b" --here
eq "--supersedes with a newline: exit 64" 64 "$EC"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
