#!/usr/bin/env bash
# Tests for bin/ytstack-gstack-diff (DECISIONS 2026-11-14): the upstream sync
# report for the six skills ytstack adapted from gstack. Uses a local fixture
# repository as the upstream (--source), never the network.
#
# Run: /bin/bash tests/ytstack-gstack-diff.test.sh   (exit 0 = all pass)

set -uo pipefail
SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }
lacks() { case "$2" in *"$3"*) bad "$1" "found '$3'";; *) ok "$1";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytgsd.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
SKILLS="office-hours plan-ceo-review plan-eng-review retro ship document-release"

# Fixture plugin: the script plus six skills with a baseline.
PLUG="$TMP/plugin"; mkdir -p "$PLUG/bin"
cp "$SRC_ROOT/bin/ytstack-gstack-diff" "$PLUG/bin/"
for s in $SKILLS; do
  mkdir -p "$PLUG/skills/$s"
  printf -- '---\nname: %s\nmetadata:\n  tier: task\n  version: 1.0.0\n  upstream: "gstack v1.0.0 (%s/, commit abc)"\n---\n# %s\n' "$s" "$s" "$s" > "$PLUG/skills/$s/SKILL.md"
done
D="$PLUG/bin/ytstack-gstack-diff"

# Fixture upstream with three tags.
UP="$TMP/gstack"; mkdir -p "$UP"
( cd "$UP" && git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false && git config tag.gpgsign false
  for s in $SKILLS; do mkdir -p "$s/sections"; echo "v1 $s" > "$s/SKILL.md"; echo "tmpl" > "$s/SKILL.md.tmpl"; done
  mkdir review; echo ethos > ETHOS.md; echo checklist > review/checklist.md
  git add -A && git commit -qm v1 && git tag v1.0.0
  echo "tmpl changed" > ship/SKILL.md.tmpl; git commit -qam "tmpl only" && git tag v1.0.1
  echo "v2 ship" > ship/SKILL.md; echo "new section" > ship/sections/tests.md; echo "unrelated" > README.md
  git add -A && git commit -qm v2 && git tag v1.1.0 ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }

echo "# up to date"
OUT=$(bash "$D" --source "$UP" v1.0.0 2>&1); EC=$?
eq "baseline == target: exit 0" 0 "$EC"
has "baseline == target: reports no change" "$OUT" "== ship: v1.0.0 -> v1.0.0, no upstream change"

echo "# template-only change"
OUT=$(bash "$D" --source "$UP" v1.0.1 2>&1); EC=$?
eq "*.tmpl changes are ignored: exit 0" 0 "$EC"

echo "# behind"
OUT=$(bash "$D" --source "$UP" 2>&1); EC=$?
eq "newest tag picked by default, ship behind: exit 3" 3 "$EC"
has "names the newest tag" "$OUT" "target v1.1.0"
has "ship: two files changed" "$OUT" "== ship: v1.0.0 -> v1.1.0, 2 file(s) changed"
has "full diff shows the new line" "$OUT" "+v2 ship"
has "other skills: no change" "$OUT" "== retro: v1.0.0 -> v1.1.0, no upstream change"
lacks "README outside the skill paths is not shown" "$OUT" "unrelated"
OUT=$(bash "$D" --source "$UP" --stat 2>&1)
has "--stat lists the section file" "$OUT" "ship/sections/tests.md"
lacks "--stat shows no diff body" "$OUT" "+v2 ship"

echo "# shared files"
( cd "$UP" && echo "ethos v2" > ETHOS.md && git commit -qam ethos && git tag v1.2.0 ) >/dev/null 2>&1
OUT=$(bash "$D" --source "$UP" --stat v1.2.0 2>&1)
has "ETHOS.md change reaches every skill" "$OUT" "== retro: v1.0.0 -> v1.2.0, 1 file(s) changed"

echo "# errors"
OUT=$(bash "$D" --source "$UP" v9.9.9 2>&1); EC=$?
eq "unknown tag: exit 1" 1 "$EC"
OUT=$(bash "$D" --source "$TMP/nope" 2>&1); EC=$?
eq "source not a repo: exit 2" 2 "$EC"
sed -i.bak '/upstream:/d' "$PLUG/skills/retro/SKILL.md"
OUT=$(bash "$D" --source "$UP" v1.0.0 2>&1); EC=$?
eq "missing baseline: exit 3" 3 "$EC"
has "missing baseline named" "$OUT" "retro: no metadata.upstream baseline"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
