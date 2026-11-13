#!/usr/bin/env bash
# Tests for bin/ytstack-finish-lane: the steps that take a delegated lane from
# the worker's report to a merge at the reviewed commit.
#
# Contract:
#   leftovers   in scope / out of scope / junk; junk wins over scope
#   commit      refuses junk, out-of-scope files and unmerged paths and stages
#               nothing; commits the in-scope files, staged or not
#   push        the branch reaches origin with upstream; a rejected push leaves
#               origin as it was
#   open-pr     prints the number of the pull request it opened
#   wait-head   passes when the host shows the local tip; a stale host head
#               fails with both commits
#   body-check  flags a backticked path the diff removed or that is not at the
#               head; commands, branches and fenced blocks are not paths
#   gates       each gate fails alone; all hold: exit 0 and the time of the read
#   merge       only when the gates hold, pinned to the reviewed commit
#   route       the lines of `ytstack-risk route` for the lane's plan, with the
#               worker of the lane's row as the author: exit 0 for
#               "unattended", 10 for "person"; a reviewer who is the worker, a
#               lane without a row and a lane without a plan are "person"; no
#               host is read
#   usage       exit 64
#
# The host is a fake `gh` first in PATH that answers from fixture files and
# logs its arguments; origin is a local bare repository. Nothing leaves the
# machine. route runs the real bin/ytstack-risk on a fixture repository.
#
# Run: /bin/bash tests/ytstack-finish-lane.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-finish-lane"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ] || ! command -v jq >/dev/null 2>&1; then
  bad "bin/ytstack-finish-lane is executable and jq is there for the fake gh"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytfinish.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

# ---- the fake host ----------------------------------------------------------------
# Fixtures in $GH_FIX: view.json (gh pr view), graphql.json (gh api graphql),
# create.out (gh pr create), *.fail to make a call fail, merge.queue to accept a
# merge without merging. A --jq filter is applied with jq, as gh applies its own.
GH_FIX="$TMP/host"; FAKE="$TMP/fakebin"; mkdir -p "$GH_FIX" "$FAKE"
cat > "$FAKE/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_FIX/log"
jqf=""; prev=""
for a in "$@"; do [ "$prev" = "--jq" ] && jqf="$a"; prev="$a"; done
answer() {
  [ -f "$1" ] || { echo "fake gh: no fixture $1" >&2; exit 1; }
  if [ -n "$jqf" ]; then jq -r "$jqf" "$1"; else cat "$1"; fi
}
case "${1:-} ${2:-}" in
  "pr create")   [ ! -f "$GH_FIX/create.fail" ] || { echo "fake gh: create failed" >&2; exit 1; }; cat "$GH_FIX/create.out" ;;
  "pr view")     [ ! -f "$GH_FIX/view.fail" ] || { echo "fake gh: view failed" >&2; exit 1; }; answer "$GH_FIX/view.json" ;;
  "api graphql") answer "$GH_FIX/graphql.json" ;;
  "pr merge")
    [ ! -f "$GH_FIX/merge.fail" ] || { echo "fake gh: head commit does not match" >&2; exit 1; }
    [ -f "$GH_FIX/merge.queue" ] || { jq '.state = "MERGED"' "$GH_FIX/view.json" > "$GH_FIX/view.tmp" && mv "$GH_FIX/view.tmp" "$GH_FIX/view.json"; } ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$FAKE/gh"

# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$(PATH="$FAKE:$PATH" GH_FIX="$GH_FIX" bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
calls() { cat "$GH_FIX/log" 2>/dev/null; }
quiet() { rm -f "$GH_FIX/log"; }
# grp <title>: the entries under one group of a leftovers listing in OUT, sorted
grp() { printf '%s\n' "$OUT" | awk -v t="$1" '/^[^ ]/ { on = (index($0, t ": ") == 1); next } on { sub(/^  /, ""); print }' | LC_ALL=C sort | tr '\n' '|'; }
head_of() { git -C "$1" rev-parse HEAD; }
staged() { git -C "$1" diff --cached --name-only; }

# new_lane <name>: a checkout on branch "lane", one base commit on main, origin
# a bare repository next to it. The user's global ignore file is switched off:
# what it ignores (.DS_Store on many machines) would never show up as a leftover.
new_lane() {
  local d="$TMP/$1" o="$TMP/$1-origin.git"
  git init -q --bare -b main "$o"
  mkdir -p "$d/src" "$d/tests"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
    git config core.excludesFile /dev/null
    echo a > src/a.sh; echo b > src/b.sh; echo d > src/d.sh; echo old > tests/old.test.sh; echo r > README.md; echo l > LICENSE
    git add src tests README.md LICENSE && git commit -qm base
    git remote add origin "$o" && git push -q -u origin main && git checkout -q -b lane ) >/dev/null 2>&1
  echo "$d"
}
# change <dir> <message>: one more commit on the current branch
change() { ( cd "$1" && echo "$2" >> src/a.sh && git add src/a.sh && git commit -qm "$2" ) >/dev/null 2>&1; }

# ---- 1. leftovers -------------------------------------------------------------
echo "# leftovers"
L=$(new_lane left)
( cd "$L" && mkdir -p docs node_modules/x src/node_modules
  echo a2 >> src/a.sh; echo n > "src/new file.sh"; rm src/d.sh
  echo r2 >> README.md; echo n > docs/note.md
  echo s > .env.local; echo l > debug.log; echo l > src/trace.log; echo x > .DS_Store
  echo m > node_modules/x/index.js; echo m > src/node_modules/y.js
  dd if=/dev/zero of=big.bin bs=1024 count=1025 2>/dev/null; echo s > small.bin )
run "$L" leftovers --scope src tests/
eq "leftovers lists and exits 0" 0 "$EC"
eq "in scope: changed, deleted and new files under the scope" "src/a.sh|src/d.sh|src/new file.sh|" "$(grp "in scope")"
eq "out of scope: everything else that is no junk" "README.md|docs/note.md|small.bin|" "$(grp "out of scope")"
eq "junk: by name, under node_modules, and the untracked file above 1 MB; junk wins over scope" \
  ".DS_Store (.DS_Store)|.env.local (.env*)|big.bin (untracked, above 1 MB)|debug.log (*.log)|node_modules/x/index.js (node_modules/)|src/node_modules/y.js (node_modules/)|src/trace.log (*.log)|" "$(grp "junk")"
has "each group carries its count" "out of scope: 3" "$OUT"
run "$L" leftovers
has "without --scope nothing is out of scope" "out of scope: 0" "$OUT"
has "and everything that is no junk is in scope" "in scope: 6" "$OUT"
( cd "$L" && echo "KEY=" > .env.example )
run "$L" leftovers
hasnt "a committed template (.env.example) is not junk" ".env.example (" "$OUT"
( cd "$L" && rm -f .env.example )
run "$L" leftovers --scope 'src/*.sh' --scope README.md
eq "a scope may be a pattern, and --scope may repeat" "README.md|src/a.sh|src/d.sh|src/new file.sh|" "$(grp "in scope")"
eq "leftovers stages nothing" "" "$(staged "$L")"

# ---- 2. commit ----------------------------------------------------------------
echo "# commit"
H=$(head_of "$L")
run "$L" commit --message "M001-S01-T01: tokens" --scope src tests
eq "junk and out-of-scope files: commit refuses" 1 "$EC"
has "it lists the junk" ".env.local (.env*)" "$OUT"
has "it lists the out-of-scope files" "  README.md" "$OUT"
eq "nothing is staged" "" "$(staged "$L")"
eq "and nothing is committed" "$H" "$(head_of "$L")"
( cd "$L" && rm -f .env.local debug.log src/trace.log .DS_Store big.bin && rm -rf node_modules src/node_modules )
run "$L" commit --message "M001-S01-T01: tokens" --scope src tests
eq "out-of-scope files alone: commit refuses" 1 "$EC"
hasnt "no junk is left to list" "(" "$(printf '%s\n' "$OUT" | grep -v '^ytstack-finish-lane:')"
eq "nothing is staged" "" "$(staged "$L")"
# What is left is in scope; part of it is already staged: a rename and a deletion.
( cd "$L" && git checkout -q -- README.md && rm -f docs/note.md small.bin && git mv src/b.sh src/c.sh && git rm -q tests/old.test.sh )
run "$L" commit --message "M001-S01-T01: tokens" --scope src tests
eq "in-scope files: commit succeeds" 0 "$EC"
has "it names the commit and the branch" "committed $(git -C "$L" rev-parse --short HEAD) on lane: 6 file(s)" "$OUT"
eq "the commit holds the changed, new, deleted and renamed files" "src/a.sh|src/b.sh|src/c.sh|src/d.sh|src/new file.sh|tests/old.test.sh|" \
  "$(git -C "$L" show --no-renames --name-only --format= HEAD | sort | tr '\n' '|')"
eq "with the message" "M001-S01-T01: tokens" "$(git -C "$L" log -1 --format=%s)"
eq "the worktree is clean afterwards" "" "$(git -C "$L" status --porcelain)"
run "$L" commit --message "again"
eq "nothing left: commit refuses" 1 "$EC"
has "and says so" "nothing to commit" "$OUT"

U=$(new_lane unmerged)
( cd "$U" && echo lane >> src/a.sh && git commit -qam lane && git checkout -q main && echo main >> src/a.sh && git commit -qam main
  git checkout -q lane && git merge main ) >/dev/null 2>&1
H=$(head_of "$U")
run "$U" commit --message "resolve"
eq "an unfinished merge: commit refuses" 1 "$EC"
has "and names the reason" "unmerged paths" "$OUT"
eq "the conflict is not committed" "$H" "$(head_of "$U")"

# The script cannot overwrite a remote, stage everything or switch signing off.
eq "no force, stage-all, signing or administrator override in the script" 0 \
  "$(grep -c -E -- '--force|push +-f|add +(-A|--all|\.)|gpg-?sign|--no-verify|--admin|--auto' "$BIN")"

# ---- 3. push ------------------------------------------------------------------
echo "# push"
P=$(new_lane push); O="$TMP/push-origin.git"
change "$P" one
run "$P" push
eq "push succeeds" 0 "$EC"
eq "origin has the branch at the local tip" "$(head_of "$P")" "$(git -C "$O" rev-parse refs/heads/lane)"
eq "the upstream is set" "origin/lane" "$(git -C "$P" rev-parse --abbrev-ref 'lane@{upstream}')"
has "it prints the branch and the commit" "pushed lane at $(head_of "$P") to origin" "$OUT"
# Somebody else pushed to the branch: the push is rejected and stays rejected.
git clone -q "$O" "$TMP/other" >/dev/null 2>&1
( cd "$TMP/other" && git config user.email o@o.o && git config user.name o && git config commit.gpgsign false
  git checkout -q lane && echo theirs > theirs.txt && git add theirs.txt && git commit -qm theirs && git push -q origin lane ) >/dev/null 2>&1
THEIRS=$(head_of "$TMP/other")
change "$P" two
run "$P" push
eq "a push that would overwrite origin fails" 1 "$EC"
eq "origin keeps the other commit" "$THEIRS" "$(git -C "$O" rev-parse refs/heads/lane)"
( cd "$P" && git checkout -q --detach ) >/dev/null 2>&1
run "$P" push
eq "a detached HEAD is not pushed" 1 "$EC"
has "and the reason is named" "detached HEAD" "$OUT"
( cd "$P" && git checkout -q lane ) >/dev/null 2>&1

# ---- 4. open-pr ---------------------------------------------------------------
echo "# open-pr"
printf 'What changed: tokens.\n' > "$TMP/body.md"
echo "https://github.com/acme/app/pull/7" > "$GH_FIX/create.out"
quiet
OUT=$(cd "$TMP" && PATH="$FAKE:$PATH" GH_FIX="$GH_FIX" bash "$BIN" -C "$P" open-pr --title "Add tokens" --body-file body.md --base main 2>&1); EC=$?
eq "open-pr succeeds" 0 "$EC"
eq "and prints the number" 7 "$OUT"
eq "gh got the title, the body file, the branch and the base" "pr create --title Add tokens --body-file $TMP/body.md --head lane --base main" "$(calls)"
touch "$GH_FIX/create.fail"
run "$P" open-pr --title T --body-file "$TMP/body.md"
eq "gh fails: open-pr fails" 1 "$EC"
rm -f "$GH_FIX/create.fail"; echo "something else" > "$GH_FIX/create.out"
run "$P" open-pr --title T --body-file "$TMP/body.md"
eq "no pull request URL in the answer: open-pr fails" 1 "$EC"
run "$P" open-pr --title T --body-file "$TMP/none.md"
eq "an unreadable body file: exit 64" 64 "$EC"

# ---- 5. wait-head -------------------------------------------------------------
echo "# wait-head"
TIP=$(head_of "$P"); OLD=$(git -C "$P" rev-parse HEAD~1)
jq -n --arg h "$TIP" '{headRefOid: $h}' > "$GH_FIX/view.json"
quiet; run "$P" wait-head --pr 7
eq "the host shows the local tip: pass" 0 "$EC"
has "it names the commit" "$TIP" "$OUT"
jq -n --arg h "$OLD" '{headRefOid: $h}' > "$GH_FIX/view.json"
quiet; run "$P" wait-head --pr 7 --timeout 1
eq "a stale host head: fail" 1 "$EC"
has "with the host's commit" "host head:  $OLD" "$OUT"
has "and the local commit" "local head: $TIP" "$OUT"
eq "it asked the host again before it gave up" "2" "$(calls | grep -c '^pr view 7 ')"
eq "and called nothing else" "" "$(calls | grep -v '^pr view 7 ')"
touch "$GH_FIX/view.fail"
run "$P" wait-head --pr 7 --timeout 0
eq "the host cannot be read: fail" 1 "$EC"
has "the head is called unknown" "unknown" "$OUT"
rm -f "$GH_FIX/view.fail"

# ---- 6. body-check ------------------------------------------------------------
echo "# body-check"
B=$(new_lane body)
( cd "$B" && echo a2 >> src/a.sh && echo n > tests/new.test.sh && git rm -q tests/old.test.sh LICENSE
  git add src/a.sh tests/new.test.sh && git commit -qm "replace the test" ) >/dev/null 2>&1
BH=$(head_of "$B"); B7=$(git -C "$B" rev-parse --short=7 HEAD)
cat > "$TMP/good.md" <<'EOF'
Changed `src/a.sh` and added `tests/new.test.sh:1-3`; the `src/` directory keeps its layout.
Verified with `bash tests/new.test.sh` on `origin/main`; `merge_by` stays as it is, see `ytstack/M001-S01`.

```
`tests/old.test.sh` printed nothing
```
EOF
run "$B" body-check --body-file "$TMP/good.md" --base main
eq "a body that names what is there: pass" 0 "$EC"
eq "three paths were checked; a command, a branch and a fenced block are no paths" "body ok: 3 path(s) checked at $B7" "$OUT"
cat > "$TMP/stale.md" <<'EOF'
Covered by `tests/old.test.sh` and `src/nope.sh`. See `LICENSE` and `src/a.sh`.
EOF
run "$B" body-check --body-file "$TMP/stale.md" --base main
eq "a body that names a removed path: fail" 1 "$EC"
has "the test the diff removed is flagged" "stale: \`tests/old.test.sh\` -- removed by the diff against main" "$OUT"
has "a removed file without a directory is flagged" "stale: \`LICENSE\` -- removed by the diff against main" "$OUT"
has "a path that never existed is flagged" "stale: \`src/nope.sh\` -- not at $B7" "$OUT"
eq "one line per stale reference, nothing else" 3 "$(printf '%s\n' "$OUT" | grep -c .)"
run "$B" body-check --body-file "$TMP/stale.md"
has "without a base the removed test is still not at the head" "stale: \`tests/old.test.sh\` -- not at $B7" "$OUT"
run "$B" body-check --body-file "$TMP/good.md" --base nowhere
eq "an unknown base: fail, no guess" 1 "$EC"
has "it names the fetch" "git fetch origin nowhere" "$OUT"
jq -n --arg h "$BH" --rawfile b "$TMP/stale.md" '{headRefOid: $h, baseRefName: "main", body: ($b | gsub("\n"; "\r\n"))}' > "$GH_FIX/view.json"
run "$B" body-check --pr 7
eq "the pull request's body is read from the host: fail" 1 "$EC"
has "with the removed test" "stale: \`tests/old.test.sh\` -- removed by the diff against main" "$OUT"
jq -n --arg h "$BH" --rawfile b "$TMP/good.md" '{headRefOid: $h, baseRefName: "main", body: $b}' > "$GH_FIX/view.json"
run "$B" body-check --pr 7
eq "a correct body on the host: pass" 0 "$EC"
jq -n --rawfile b "$TMP/good.md" '{headRefOid: "0123456789012345678901234567890123456789", baseRefName: "main", body: $b}' > "$GH_FIX/view.json"
run "$B" body-check --pr 7
eq "a host head that is not in the checkout: fail" 1 "$EC"
has "it says so" "not in this checkout" "$OUT"

# ---- 7. gates -----------------------------------------------------------------
echo "# gates"
G="$P"; SHA="$TIP"
# host: a pull request at $SHA whose gates all hold, 3 open pull requests, one resolved thread
host() {
  jq -n --arg h "$SHA" '{state: "OPEN", headRefOid: $h, mergeable: "MERGEABLE",
    statusCheckRollup: [
      {__typename: "CheckRun", name: "build", status: "COMPLETED", conclusion: "SUCCESS", workflowName: "ci"},
      {__typename: "CheckRun", name: "docs", status: "COMPLETED", conclusion: "SKIPPED", workflowName: "ci"},
      {__typename: "StatusContext", context: "preview", state: "SUCCESS"} ],
    reviews: [
      {author: {login: "rev"}, state: "COMMENTED", submittedAt: "2026-11-13T10:00:00Z", commit: {oid: $h},
       body: "Verdict: approved\r\nReviewed commit: \($h)"} ]}' > "$GH_FIX/view.json"
  jq -n '{data: {repository: {pullRequests: {totalCount: 3},
    pullRequest: {reviewThreads: {totalCount: 1, pageInfo: {hasNextPage: false}, nodes: [{isResolved: true}]}}}}}' > "$GH_FIX/graphql.json"
  rm -f "$GH_FIX"/*.fail "$GH_FIX/merge.queue" "$GH_FIX/log"
}
# tweak <file> <jq filter>: change one fixture
tweak() { jq "$2" "$GH_FIX/$1.json" > "$GH_FIX/$1.tmp" && mv "$GH_FIX/$1.tmp" "$GH_FIX/$1.json"; }
# only <name> <gate>: exit 1 and exactly this gate fails
only() {
  local f; f=$(printf '%s\n' "$OUT" | grep '^FAIL ' | sed 's/:.*//' | tr '\n' ',')
  if [ "$EC" = 1 ] && [ "$f" = "FAIL $2," ]; then ok "$1"; else bad "$1" "exit $EC, failing: ${f:-none} in: $OUT"; fi
}
gates() { run "$G" gates --pr 7 --reviewed-head "$SHA" "$@"; }

host; gates
eq "all gates hold: exit 0" 0 "$EC"
eq "one line per gate, all ok" "ok   head,ok   checks,ok   review,ok   threads,ok   mergeable," "$(printf '%s\n' "$OUT" | sed '$d' | sed 's/:.*//' | tr '\n' ',')"
case "$(printf '%s\n' "$OUT" | tail -1)" in
  "read 20"[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ok "the last line is the UTC time of the read" ;;
  *) bad "the last line is the UTC time of the read" "$(printf '%s\n' "$OUT" | tail -1)" ;;
esac
has "the checks line counts them and names the commit" "ok   checks: 3 concluded successfully on ${SHA:0:7}" "$OUT"
has "the threads were read for this pull request" "-F number=7" "$(calls)"
host; run "$G" gates --pr 7 --reviewed-head "${SHA:0:7}" --max-open 3
eq "a short commit id and a limit that is just met: exit 0" 0 "$EC"
has "the limit has its own line" "ok   open-prs: 3 open, limit 3" "$OUT"

host; tweak view '.headRefOid = "ffffffffffffffffffffffffffffffffffffffff"'; gates
only "the head moved after the review" head
has "both commits are named" "the host shows fffffff, the review saw ${SHA:0:7}" "$OUT"
host; tweak view '.statusCheckRollup[0].status = "IN_PROGRESS" | .statusCheckRollup[0].conclusion = ""'; gates
only "a pending check" checks
has "the check is named with its state" "build (IN_PROGRESS)" "$OUT"
host; tweak view '.statusCheckRollup[0].conclusion = "FAILURE"'; gates
only "a failed check" checks
has "the check is named with its conclusion" "build (FAILURE)" "$OUT"
host; tweak view '.statusCheckRollup[2].state = "PENDING"'; gates
only "a pending commit status" checks
host; tweak view '.statusCheckRollup = []'; gates
only "no checks at all" checks
has "has its own line" "FAIL checks: none on ${SHA:0:7}" "$OUT"
gates --allow-no-checks
eq "no checks with --allow-no-checks: exit 0" 0 "$EC"
host; tweak view '.reviews[0].state = "CHANGES_REQUESTED"'; gates
only "changes requested on the head" review
has "the reviewer is named" "changes requested by rev" "$OUT"
host; tweak view '.reviews[0].state = "CHANGES_REQUESTED" | .reviews[0].commit.oid = "0000000000000000000000000000000000000000"'; gates
eq "changes requested on an earlier commit do not count" 0 "$EC"
has "the head has no review then" "ok   review: none on ${SHA:0:7}" "$OUT"
host; tweak view '.reviews[0].state = "CHANGES_REQUESTED" | .reviews += [.reviews[0] | .state = "APPROVED" | .submittedAt = "2026-11-13T11:00:00Z"]'; gates
eq "a reviewer's newer review replaces the older one" 0 "$EC"
host; tweak view '.reviews += [{author: {login: "sam"}, state: "CHANGES_REQUESTED", submittedAt: "2026-11-13T09:00:00Z", commit: {oid: .headRefOid}, body: ""}]'; gates
only "another reviewer's changes requested stand beside a newer comment" review
host; tweak graphql '.data.repository.pullRequest.reviewThreads |= (.totalCount = 2 | .nodes += [{isResolved: false}])'; gates
only "an unresolved thread" threads
has "the count is printed" "1 unresolved of 2" "$OUT"
host; tweak graphql '.data.repository.pullRequest.reviewThreads |= (.totalCount = 140 | .pageInfo.hasNextPage = true)'; gates
only "more threads than were read" threads
host; tweak view '.mergeable = "CONFLICTING"'; gates
only "a conflict" mergeable
host; tweak view '.mergeable = "UNKNOWN"'; gates
only "mergeability the host has not decided" mergeable
host; tweak view '.state = "CLOSED"'; gates
only "a closed pull request" mergeable
host; gates --max-open 2
only "too many open pull requests" open-prs
has "count and limit are printed" "3 open, limit 2" "$OUT"

host; gates --verdict-pattern '^Verdict: approved$'
eq "the newest review matches the verdict pattern: exit 0" 0 "$EC"
has "the line names the pattern" "matches '^Verdict: approved\$'" "$OUT"
host; tweak view '.reviews[0].body = "Verdict: changes requested"'; gates --verdict-pattern '^Verdict: approved$'
only "the newest review does not match the verdict pattern" review
host; tweak view '.reviews = []'; gates --verdict-pattern '^Verdict: approved$'
only "no review on the head, with a verdict pattern" review

host; touch "$GH_FIX/view.fail"; gates
only "the host cannot be read" host
hasnt "no gate is reported as holding" "ok   " "$OUT"

# ---- 8. merge -----------------------------------------------------------------
echo "# merge"
host; run "$G" merge --pr 7 --at "${SHA:0:12}"
eq "all gates hold: merge succeeds" 0 "$EC"
has "the merge is pinned to the full reviewed commit" "pr merge 7 --squash --match-head-commit $SHA" "$(calls)"
eq "it prints what it merged and where" "merged #7 at $SHA (squash)" "$(printf '%s\n' "$OUT" | tail -1)"
has "after the gate lines" "ok   head: ${SHA:0:7} is the reviewed commit" "$OUT"
host; run "$G" merge --pr 7 --at "$SHA" --method rebase --max-open 5 --verdict-pattern 'approved'
eq "method and gate options pass through" 0 "$EC"
has "the method reaches gh" "pr merge 7 --rebase --match-head-commit $SHA" "$(calls)"
has "the limit was checked" "ok   open-prs: 3 open, limit 5" "$OUT"
host; tweak view '.headRefOid = "ffffffffffffffffffffffffffffffffffffffff"'; run "$G" merge --pr 7 --at "$SHA"
eq "the head moved after the review: merge refuses" 1 "$EC"
has "the gate is named" "FAIL head:" "$OUT"
hasnt "and gh is not asked to merge" "pr merge" "$(calls)"
host; tweak view '.statusCheckRollup[0].conclusion = "FAILURE"'; run "$G" merge --pr 7 --at "$SHA"
eq "a failed check: merge refuses" 1 "$EC"
hasnt "and gh is not asked to merge" "pr merge" "$(calls)"
host; touch "$GH_FIX/merge.fail"; run "$G" merge --pr 7 --at "$SHA"
eq "the host rejects the pinned merge: fail" 1 "$EC"
hasnt "nothing is reported as merged" "merged #7" "$OUT"
host; touch "$GH_FIX/merge.queue"; run "$G" merge --pr 7 --at "$SHA"
eq "accepted but not merged (a queue): fail" 1 "$EC"
has "the host's state is named" "the host reports OPEN" "$OUT"

# ---- 9. route -----------------------------------------------------------------
echo "# route"
# A project with one area (src/**, auto_merge: low) and a lane whose worker
# changed one file under it. The checkout of the coordinating session holds
# LANES.md with the worker and the lane's plan with the review record.
RT="$TMP/route"; mkdir -p "$RT/src" "$RT/.ytstack/spec"
( cd "$RT" || exit 1
  git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false || exit 1
  echo a > src/a.sh
  printf -- '---\narea: core\nstatus: implemented\npaths:\n  - src/**\nauto_merge: low\n---\n\n# core\n\n## Invariants and security boundaries\n\n- x\n\n## Decisions that apply now\n\n- none\n' > .ytstack/spec/core.md
  git add -A && git commit -qm base && git checkout -q -b lane && echo b >> src/a.sh && git commit -qam "M001-S01-T01: change a" && git checkout -q main ) >/dev/null 2>&1
RB=$(git -C "$RT" rev-parse main); RH=$(git -C "$RT" rev-parse lane)
# lanes <claimed by>: the lanes table with one row for M001-S01
lanes() {
  printf -- '---\nupdated: 2026-11-13T10:00:00Z\n---\n\n# Lanes\n\n| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |\n|---|---|---|---|---|---|---|---|---|---|\n| M001-S01 | implement | in-review | %s | lane | - | 7 | - | 1 | - |\n' "$1" > "$RT/.ytstack/LANES.md"
}
# rplan <reviewer>: the lane's plan with one approving round by that reviewer
rplan() {
  printf -- '---\nstatus: in-progress\n---\n\n# Slice Plan\n\n## Review\n\n- Round 1: %s..%s -- approved; blocking: 0; follow-ups: 0; risk: low; invariants: none; by: %s\n' \
    "${RB:0:7}" "${RH:0:7}" "$1" > "$RT/.ytstack/M001-S01-PLAN.md"
}
route() { quiet; run "$RT" route --lane M001-S01 --base "$RB" --head "${RH:0:12}"; }

lanes "impl-M001-S01 2026-11-13T09:00Z"; rplan review-M001-S01; route
eq "an approved low change in an area that allows low: exit 0" 0 "$EC"
eq "the first line says what was read" "lane: M001-S01; author: impl-M001-S01; plan: .ytstack/M001-S01-PLAN.md" "$(printf '%s\n' "$OUT" | sed -n 1p)"
has "then the lines of ytstack-risk route" "route: unattended
class: low
ceiling: low" "$OUT"
eq "no host was read" "" "$(calls)"
rplan impl-M001-S01; route
eq "the reviewer is the lane's worker: exit 10" 10 "$EC"
has "the route is person" "route: person" "$OUT"
has "and says why" "reason: review -- the reviewer 'impl-M001-S01' is the author of the change" "$OUT"
rplan review-M001-S01; lanes "-"; route
eq "nobody holds the lane's row: exit 10" 10 "$EC"
has "the author is unknown" "lane: M001-S01; author: unknown; plan:" "$OUT"
has "so the reviewer cannot be told from the author" "reason: review -- no --author given" "$OUT"
rm -f "$RT/.ytstack/LANES.md"; route
eq "no lanes table at all: exit 10" 10 "$EC"
lanes "impl-M001-S01 2026-11-13T09:00Z"; rm -f "$RT/.ytstack/M001-S01-PLAN.md"; route
eq "a lane without a plan: exit 10" 10 "$EC"
eq "it is person, with the one reason" "lane: M001-S01; author: impl-M001-S01; plan: none
route: person
reason: review -- lane M001-S01 has no plan file (M001-S01-PLAN.md under $RT/.ytstack): there is no review record to read" "$OUT"
rplan review-M001-S01
quiet; run "$RT" route --lane M001-S01 --base "$RB" --head 0123456789abcdef
eq "a head that is no commit of the repository: exit 65, not unattended" 65 "$EC"
quiet; run "$TMP/plain-route" route --lane M001-S01 --base "$RB" --head "$RH"
eq "-C to a missing directory: exit 64" 64 "$EC"

# ---- 10. usage ----------------------------------------------------------------
echo "# usage"
host
run "$G";                                              eq "no command: exit 64" 64 "$EC"
run "$G" publish;                                      eq "unknown command: exit 64" 64 "$EC"
run "$G" leftovers --scope;                            eq "--scope without a path: exit 64" 64 "$EC"
run "$G" leftovers --all;                              eq "unknown option: exit 64" 64 "$EC"
run "$G" commit --scope src;                           eq "commit without --message: exit 64" 64 "$EC"
run "$G" push --force-with-lease;                      eq "push takes no option: exit 64" 64 "$EC"
run "$G" open-pr --title T;                            eq "open-pr without a body file: exit 64" 64 "$EC"
run "$G" wait-head --pr seven;                         eq "a pull request that is no number: exit 64" 64 "$EC"
run "$G" wait-head --pr 7 --timeout soon;              eq "a timeout that is no number: exit 64" 64 "$EC"
run "$G" body-check;                                   eq "body-check without a body: exit 64" 64 "$EC"
run "$G" body-check --pr 7 --body-file "$TMP/good.md"; eq "body-check with two bodies: exit 64" 64 "$EC"
run "$G" gates --pr 7;                                 eq "gates without the reviewed commit: exit 64" 64 "$EC"
run "$G" gates --pr 7 --reviewed-head HEAD;            eq "a reviewed commit that is no commit id: exit 64" 64 "$EC"
run "$G" gates --pr 7 --reviewed-head "$SHA" --verdict-pattern '(';  eq "an invalid verdict pattern: exit 64" 64 "$EC"
run "$G" gates --pr 7 --at "$SHA";                     eq "--at belongs to merge: exit 64" 64 "$EC"
run "$G" merge --pr 7 --at "$SHA" --method fast;       eq "an unknown merge method: exit 64" 64 "$EC"
run "$G" merge --pr 7 --at;                            eq "an option without its value: exit 64" 64 "$EC"
run "$G" route --base "$SHA" --head "$SHA";            eq "route without a lane: exit 64" 64 "$EC"
run "$G" route --lane M001-S01 --base main --head "$SHA"; eq "route with a branch name as the base: exit 64" 64 "$EC"
run "$G" route --lane 'M001 S01' --base "$SHA" --head "$SHA"; eq "a lane reference with a space: exit 64" 64 "$EC"
eq "no usage error reached the host" "" "$(calls)"
run "$TMP/nowhere" leftovers;                          eq "-C to a missing directory: exit 64" 64 "$EC"
mkdir -p "$TMP/plain"; run "$TMP/plain" leftovers
eq "a directory that is no git worktree: exit 1" 1 "$EC"
run "$G" help
eq "help: exit 0" 0 "$EC"
has "help lists the commands" "ytstack-finish-lane merge" "$OUT"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
