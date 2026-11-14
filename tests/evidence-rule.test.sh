#!/usr/bin/env bash
# Tests for the evidence reuse rule (review R1 on PR 37).
#
# Contract:
#   An earlier verification PASS is reused only for the same commit, the same
#   environment and the same command. On another commit the check runs again:
#   unchanged planned files do not make an earlier result valid, because a
#   check also reads files its plan does not name.
#
#   1. The case behind the rule, in a git fixture: task A plans app.sh, its
#      check also reads helper.sh; a later commit breaks helper.sh. The
#      path-limited diff over the planned file is empty, the check fails now.
#   2. Every text that states the rule says "same commit" and none allows
#      reuse on a path-limited diff over the plan's files.
#
# Run: /bin/bash tests/evidence-rule.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytevid.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

# ---- 1. the imported-helper case ----------------------------------------------
echo "# imported helper"
R="$TMP/repo"; mkdir -p "$R"
( cd "$R" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false ) >/dev/null 2>&1
printf 'ok() { return 0; }\n' > "$R/helper.sh"
printf '. ./helper.sh\nok\n' > "$R/app.sh"
( cd "$R" && git add -A && git commit -qm "A: app" ) >/dev/null 2>&1
C1=$(git -C "$R" rev-parse HEAD)
( cd "$R" && bash app.sh ); eq "the check passes at C1" 0 "$?"
printf 'ok() { return 1; }\n' > "$R/helper.sh"
( cd "$R" && git add -A && git commit -qm "B: helper" ) >/dev/null 2>&1
git -C "$R" diff --quiet "$C1" HEAD -- app.sh
eq "the planned file is unchanged since C1 (path-limited diff exits 0)" 0 "$?"
( cd "$R" && bash app.sh ); eq "and the check fails at HEAD: C1's PASS does not carry over" 1 "$?"

# ---- 2. the texts that state the rule ------------------------------------------
echo "# rule texts"
for f in agents/verifier.md skills/spawn-milestone-team/SKILL.md skills/minimal-code/SKILL.md \
         skills/verification-before-completion/SKILL.md .ytstack/spec/skills.md; do
  if [ ! -f "$ROOT/$f" ]; then bad "$f exists"; continue; fi
  # A reuse rule keyed on a path-limited diff over the plan's files is the bug.
  if grep -n 'git diff --quiet' "$ROOT/$f" | grep -i "files" >/dev/null; then
    bad "$f: no reuse on a path-limited diff over the plan's files" "$(grep -n 'git diff --quiet' "$ROOT/$f" | head -1)"
  else
    ok "$f: no reuse on a path-limited diff over the plan's files"
  fi
done
for f in agents/verifier.md skills/spawn-milestone-team/SKILL.md .ytstack/spec/skills.md; do
  if grep -i "same commit" "$ROOT/$f" >/dev/null; then ok "$f: reuse needs the same commit"
  else bad "$f: reuse needs the same commit"; fi
done
for f in agents/verifier.md skills/spawn-milestone-team/SKILL.md; do
  if grep -i "imported helper" "$ROOT/$f" >/dev/null; then ok "$f: names the imported-helper case"
  else bad "$f: names the imported-helper case"; fi
done

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
