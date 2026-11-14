#!/usr/bin/env bash
# Tests for bin/ytstack-review-escapes (M030): which review-bot findings on a
# pull request the project's own reviewers missed.
#
# Contract:
#   rows      one TSV line per bot thread under a fixed header: bot,
#             resolution, match, role, path, lines, url, title
#   bot       author type Bot, a login ending in "[bot]", or a login in a
#             "bots:" list of REVIEW.md; a thread by a person is no bot thread
#   fixed     a later commit changed the thread's file within MARGIN lines of
#             its range; rejected: resolved without one; open: not resolved
#   caught    an own finding (a thread, or a review body line with a cited
#             path:line) carrying a role marker, on the same file and
#             overlapping lines, at the same or an earlier head; a body line
#             without a cited line and a finding at a later head match nothing
#   exit      10 with a fixed and escaped row, 0 without, 1 no own reviewers
#             (no host read at all), 2 usage, a broken section or a gh error
#   reads     GraphQL pages follow the cursors; one REST call per commit after
#             a resolved bot thread; the repository comes from origin
#
# No network and no real gh: a fake `gh` first in PATH answers from
# tests/fixtures/review-escapes/. graphql-<pr>[-tc=..][-rc=..][-cc=..].json
# answers a GraphQL call with those cursors, commit-<sha>.json a commit, and a
# file ending in .err makes the call fail with its text. graphql-47.json and
# its commit are recorded from Yesterday-AI/ytstack#47; the rest is shaped by
# hand. Every call is logged.
#
# Run: /bin/bash tests/ytstack-review-escapes.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-review-escapes"
FIX="$ROOT/tests/fixtures/review-escapes"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-review-escapes exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  bad "jq is available"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytescapes-test.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fakebin"; LOG="$TMP/gh.log"
mkdir -p "$FAKE"
cat > "$FAKE/gh" <<EOF
#!/usr/bin/env bash
FIX="\${GH_FIX:-$FIX}"
echo "\$*" | tr '\n' ' ' >> '$LOG'; echo >> '$LOG'
name=""
if [ "\$1 \$2" = "api graphql" ]; then
  pr=""; cur=""
  for a in "\$@"; do case "\$a" in pr=*) pr=\${a#pr=} ;; tc=*|rc=*|cc=*) cur="\$cur-\$a" ;; esac; done
  name="graphql-\$pr\$cur"
elif [ "\$1" = api ]; then
  case "\$2" in repos/acme/shop/commits/*|repos/Yesterday-AI/ytstack/commits/*) name="commit-\${2##*/}" ;; esac
fi
[ -n "\$name" ] || { echo "fake gh: unexpected call: \$*" >&2; exit 2; }
if [ -f "\$FIX/\$name.err" ]; then cat "\$FIX/\$name.err" >&2; exit 1; fi
[ -f "\$FIX/\$name.json" ] || { echo "fake gh: no fixture \$name" >&2; exit 1; }
cat "\$FIX/\$name.json"
EOF
chmod +x "$FAKE/gh"

# project <name> <REVIEW.md body or ->: a repository with an origin on github.com
project() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack/spec" "$d/docs/reviewers"
  ( cd "$d" && git init -q && git remote add origin git@github.com:acme/shop.git ) || exit 1
  echo code > "$d/docs/reviewers/code.md"; echo tests > "$d/docs/reviewers/tests.md"
  [ "$2" = - ] || printf '# Review policy\n\n%b' "$2" > "$d/.ytstack/spec/REVIEW.md"
  echo "$d"
}
# run <dir> <args...>: sets OUT, ERR and EC; the log starts empty
run() { local d="$1"; shift; : > "$LOG"; OUT=$(PATH="$FAKE:$PATH" bash "$BIN" -C "$d" "$@" 2>"$TMP/err"); EC=$?; ERR=$(cat "$TMP/err"); }
# row <n>: the fields 1-6 of output line n+1 (n counts the bot threads)
row() { printf '%s\n' "$OUT" | sed -n "$(($1 + 1))p" | cut -f1-6; }
calls() { awk 'NF { n++ } END { print n + 0 }' "$LOG"; }

ROLES='## Own reviewers\n\n- code | marker: (`code`) | lessons: docs/reviewers/code.md\n- tests | marker: (`tests`) | lessons: docs/reviewers/tests.md | bots: cursor\n'
P=$(project p "$ROLES")
T=$'\t'

echo "# a pull request with every case (two pages of threads)"
run "$P" --pr 101
eq "a fixed bot finding that escaped: exit 10" 10 "$EC"
eq "the header" "bot${T}resolution${T}match${T}role${T}path${T}lines${T}url${T}title" "$(printf '%s\n' "$OUT" | sed -n 1p)"
eq "six bot threads, the person's thread is none" 7 "$(printf '%s\n' "$OUT" | awk 'NF { n++ } END { print n }')"
eq "fixed + escaped: a later change on the lines, no own finding" "chatgpt-codex-connector${T}fixed${T}escaped${T}-${T}src/app.ts${T}10-12" "$(row 1)"
eq "fixed (within the margin) + caught by an own thread" "greptile-apps${T}fixed${T}caught${T}code${T}src/app.ts${T}39" "$(row 2)"
eq "a login from bots: is a bot; caught by a review body line with a cited line" "cursor${T}fixed${T}caught${T}tests${T}src/db.ts${T}20" "$(row 3)"
eq "rejected: resolved without a change on its lines" "chatgpt-codex-connector${T}rejected${T}escaped${T}-${T}src/db.ts${T}80" "$(row 4)"
eq "open: not resolved" "chatgpt-codex-connector${T}open${T}escaped${T}-${T}src/app.ts${T}100" "$(row 5)"
eq "a [bot] login on a whole file: lines '-'" "docs-helper${T}open${T}escaped${T}-${T}README.md${T}-" "$(row 6)"
eq "the url" "https://github.com/acme/shop/pull/101#discussion_r1" "$(printf '%s\n' "$OUT" | sed -n 2p | cut -f7)"
eq "the title: badge text kept, markup gone" "P1 Guard the empty cart" "$(printf '%s\n' "$OUT" | sed -n 2p | cut -f8)"
eq "a tab in the title becomes a space" "logic: \`total\` can be undefined before the check" "$(printf '%s\n' "$OUT" | sed -n 3p | cut -f8)"
eq "two GraphQL pages and one REST call per later commit" 4 "$(calls)"
has "page two follows the thread cursor" "tc=T2" "$(sed -n 2p "$LOG")"
has "and asks for the threads only" "t=true -F r=false -F c=false" "$(sed -n 2p "$LOG")"
has "the repository comes from origin" "owner=acme" "$(sed -n 1p "$LOG")"

echo "# matching rules"
# Row 1 stays escaped although two body lines carry the marker of code: one
# names src/app.ts without a line, one cites src/app.ts:11 at a later head.
# These two checks keep the fixture honest, so that row 1 tests both rules.
has "the fixture: a body line on the file without a cited line" "(\`code\`) the cart handling in src/app.ts" "$(jq -r '.data.repository.pullRequest.reviews.nodes[0].body' "$FIX/graphql-101.json")"
has "the fixture: a cited line, at the third commit" "(\`code\`) \`src/app.ts:11\`" "$(jq -r '.data.repository.pullRequest.reviews.nodes[2] | .body + " " + .commit.oid' "$FIX/graphql-101.json")"

# An own role that posts through a GitHub App (author type Bot) is still an own
# finding: the role marker wins over the author type.
FIX2="$TMP/fix-app"; cp -R "$FIX" "$FIX2"
jq '(.data.repository.pullRequest.reviewThreads.nodes[] | .comments.nodes[0] | select(.body | contains("(`code`)")) | .author)
      |= {"__typename": "Bot", "login": "acme-review-app"}' "$FIX/graphql-101.json" > "$FIX2/graphql-101.json"
has "the fixture: the own thread now comes from an app" "acme-review-app" "$(cat "$FIX2/graphql-101.json")"
export GH_FIX="$FIX2"; run "$P" --pr 101; unset GH_FIX
eq "an own finding posted by an app still catches" "greptile-apps${T}fixed${T}caught${T}code${T}src/app.ts${T}39" "$(row 2)"
eq "and is not listed as a bot thread itself" 7 "$(printf '%s\n' "$OUT" | awk 'NF { n++ } END { print n }')"

echo "# no escape"
run "$P" --pr 102
eq "only a rejected finding: exit 0" 0 "$EC"
eq "and its row" "chatgpt-codex-connector${T}rejected${T}escaped${T}-${T}src/db.ts${T}80" "$(row 1)"
eq "a thread on the newest commit needs no REST call" 1 "$(calls)"

echo "# recorded: Yesterday-AI/ytstack#47"
run "$P" --pr 47 --repo Yesterday-AI/ytstack
eq "two Codex findings fixed in the next commit, no own reviewer: exit 10" 10 "$EC"
eq "the first" "chatgpt-codex-connector${T}fixed${T}escaped${T}-${T}tools/pr-watch/prwatch/worker.py${T}290" "$(row 1)"
eq "the second, a range" "chatgpt-codex-connector${T}fixed${T}escaped${T}-${T}tools/pr-watch/prwatch/worker.py${T}281-283" "$(row 2)"
eq "the title" "P2 Keep expired watches out of reopen updates" "$(printf '%s\n' "$OUT" | sed -n 2p | cut -f8)"
eq "one GraphQL call, one commit read" 2 "$(calls)"
has "--repo wins over origin" "owner=Yesterday-AI" "$(sed -n 1p "$LOG")"

echo "# no own reviewers"
N=$(project none '## Never low\n\n- **/*.sql\n')
run "$N" --pr 101
eq "a REVIEW.md without the section: exit 1" 1 "$EC"
has "with a hint" "declares no own reviewers" "$OUT"
eq "and nothing read from the host" 0 "$(calls)"
N2=$(project nopolicy -)
run "$N2" --pr 101
eq "no REVIEW.md: exit 1" 1 "$EC"

echo "# errors"
run "$P" --pr 103
eq "a gh error: exit 2" 2 "$EC"
has "and its first line" "HTTP 502: Bad Gateway" "$ERR"
B=$(project broken '## Own reviewers\n\n- code | marker: (`code`) | lessons: docs/gone.md\n')
run "$B" --pr 101
eq "a broken Own reviewers section: exit 2" 2 "$EC"
has "names the problem" "lessons docs/gone.md does not exist" "$ERR"
run "$P"
eq "no --pr: exit 2" 2 "$EC"
run "$P" --pr abc
eq "a --pr that is no number: exit 2" 2 "$EC"
run "$P" --pr 101 --repo justname
eq "a --repo without owner: exit 2" 2 "$EC"
run "$P" --pr 101 --sideways
eq "an unknown argument: exit 2" 2 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
