#!/usr/bin/env bash
# Opt-in live validation of the installed-gstack contract (M017-S02-T04).
#
# Runs only when GSTACK_HOME points at a real gstack checkout/install
# (e.g. a `git clone --branch v1.96.0.0 https://github.com/garrytan/gstack`).
# Without GSTACK_HOME it prints a skip line and exits 0 so run-all.sh stays
# green on machines without gstack.
#
#   GSTACK_HOME=~/.claude/skills/gstack /bin/bash tests/gstack-live.test.sh
#
# Asserts: VERSION >= ytstack's pin, the three wrapped skills exist with
# sections/, the skill-start helper exists, frontmatter names are the bare
# skill names (Skill-tool targets), and yt_gstack_ctx + the three wrapper
# preambles report the install correctly.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LIB="$ROOT/hooks/lib/git-ctx.sh"

if [ -z "${GSTACK_HOME:-}" ] || [ ! -f "${GSTACK_HOME}/VERSION" ]; then
  echo "gstack-live: GSTACK_HOME not set or no VERSION file -- skipped (0 passed, 0 failed)"
  exit 0
fi
GSTACK_HOME=$(cd "$GSTACK_HOME" && pwd -P)

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytgl.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

echo "# install layout ($GSTACK_HOME)"
VER=$(head -1 "$GSTACK_HOME/VERSION" | tr -d '[:space:]')
PIN=$( . "$LIB"; printf '%s' "$YT_GSTACK_PIN" )
if ( . "$LIB"; yt_vergte "$VER" "$PIN" ); then ok "VERSION $VER >= pin $PIN"; else bad "VERSION $VER >= pin $PIN"; fi
for s in office-hours plan-ceo-review plan-eng-review; do
  [ -f "$GSTACK_HOME/$s/SKILL.md" ] && ok "$s/SKILL.md present" || bad "$s/SKILL.md present"
  eq "$s: frontmatter name is the bare skill name" "$s" "$(sed -n 's/^name: *//p' "$GSTACK_HOME/$s/SKILL.md" | head -1 | tr -d '"')"
  [ -d "$GSTACK_HOME/$s/sections" ] && ok "$s/sections/ present (skeleton layout)" || ok "$s: no sections/ dir (monolithic SKILL.md)"
done
[ -x "$GSTACK_HOME/bin/gstack-skill-start" ] || [ -f "$GSTACK_HOME/bin/gstack-skill-start" ] && ok "bin/gstack-skill-start present" || bad "bin/gstack-skill-start present"

echo "# lib against the install"
OUT=$( . "$LIB"; GSTACK_HOME="$GSTACK_HOME" yt_gstack_ctx >/dev/null; printf '%s|%s|%s|%s' "$YT_GSTACK_AVAILABLE" "$YT_GSTACK_VERSION" "$YT_GSTACK_PIN_OK" "$(yt_gstack_skill_ok office-hours)" )
eq "yt_gstack_ctx: available|version|pin_ok|skill_ok" "yes|$VER|yes|yes" "$OUT"

echo "# wrapper preambles against the install"
extract() {
  local skill="$1" src="$ROOT/skills/$1/SKILL.md" out="$TMP/pre-$1.sh"
  awk 'BEGIN{p=0} /^```(bash|!)[[:space:]]*$/ && p==0 {p=1; next} /^```[[:space:]]*$/ && p==1 {exit} p==1 {print}' "$src" \
    | sed "s|\${CLAUDE_SKILL_DIR}|$ROOT/skills/$skill|g" > "$out"
  printf '%s' "$out"
}
FIX="$TMP/fixture"; mkdir -p "$FIX/.ytstack"; ( cd "$FIX" && git init -q && git config user.email t@t.t && git config user.name t && printf 'current_milestone: none\n' > .ytstack/STATE.md && echo x > f && git add -A && git commit -qm seed ) >/dev/null 2>&1
for s in office-hours plan-ceo-review plan-eng-review; do
  P=$(extract "$s")
  OUT=$( cd "$FIX" && GSTACK_HOME="$GSTACK_HOME" bash "$P" 2>/dev/null )
  has "$s: GSTACK_AVAILABLE yes"   "$OUT" "GSTACK_AVAILABLE: yes"
  has "$s: GSTACK_VERSION $VER"    "$OUT" "GSTACK_VERSION: $VER"
  has "$s: GSTACK_SKILL_OK yes"    "$OUT" "GSTACK_SKILL_OK: yes"
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
