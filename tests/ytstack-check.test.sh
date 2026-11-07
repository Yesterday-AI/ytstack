#!/usr/bin/env bash
# Tests for the M016 resolver-contract rules in bin/ytstack-check (S02-T05).
#
#   - banned patterns in skills/**/SKILL.md and hooks/* (not hooks/lib, not
#     hooks.json, comments ignored): `[ -d .git ]`, basename slug,
#     CLAUDE_PROJECT_DIR (hooks only), `~/.ytstack/.` sentinel paths
#   - shell preambles must source hooks/lib/git-ctx.sh
#   - plugin.json / marketplace.json version agreement (warn)
#
# Fixture skills/hooks are created inside the repo under a `zz-fixture-*`
# name and removed by the trap, so the checker sees them like real files.
#
# Run: /bin/bash tests/ytstack-check.test.sh   (exit 0 = all pass)

set -uo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

# Work on a copy of the plugin tree (the real checkout may be read-only, e.g.
# in the Linux container, and must never receive fixture files).
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytcheck.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/plugin"; mkdir -p "$ROOT"
for d in bin skills hooks agents docs .claude-plugin; do [ -e "$SRC/$d" ] && cp -R "$SRC/$d" "$ROOT/"; done
[ -d "$SRC/vendor" ] && ln -s "$SRC/vendor" "$ROOT/vendor"   # wrapper cross-ref checks read vendor/ (read-only is fine)
CHECK="$ROOT/bin/ytstack-check"
[ -x "$CHECK" ] || chmod +x "$CHECK"

FIX_SKILL="$ROOT/skills/zz-fixture-banned"
FIX_HOOK="$ROOT/hooks/zz-fixture-hook"

# ---- 1. clean tree: no fails, section present ------------------------------
echo "# clean tree"
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
if [ "$EC" -eq 0 ] || [ "$EC" -eq 2 ]; then ok "clean tree: exit 0/2 (no fails)"; else bad "clean tree: exit 0/2" "exit $EC: $(printf '%s' "$OUT" | grep '\[fail\]' | head -3 | tr '\n' ' ')"; fi
eq "clean tree: no banned-pattern fails" 0 "$(printf '%s' "$OUT" | grep -c 'banned pattern')"

# ---- 2. fixture skill with every banned pattern ----------------------------
echo "# fixture skill"
mkdir -p "$FIX_SKILL"
cat > "$FIX_SKILL/SKILL.md" <<'EOF'
---
name: zz-fixture-banned
description: "Fixture for ytstack-check tests. Not a real skill."
tier: core
version: 0.0.1
allowed-tools: Read
---

# zz-fixture-banned

## Preamble

```bash
_IS_GIT=$([ -d .git ] && echo yes || echo no)
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
touch "$HOME/.ytstack/.init-project-${_PROJECT_SLUG}-completed"
# [ -d .git ] in a comment must not count
echo "HAS_YTSTACK: no"
```

## Procedure

(fixture)

## Checklist

1. nothing

## Terminal State

Return.
EOF
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
eq "fixture skill: checker fails (exit 1)" 1 "$EC"
F=$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'zz-fixture-banned')
eq "fixture skill: flags [ -d .git ]"          1 "$(printf '%s' "$F" | grep -c 'rev-parse --is-inside-work-tree')"
eq "fixture skill: flags basename slug"        1 "$(printf '%s' "$F" | grep -c 'basename')"
eq "fixture skill: flags sentinel path"        1 "$(printf '%s' "$F" | grep -c 'sentinel')"
eq "fixture skill: flags missing shared resolver" 1 "$(printf '%s' "$F" | grep -c 'shared resolver')"
eq "fixture skill: comment line not counted (exactly 3 pattern hits)" 3 "$(printf '%s' "$F" | grep -c 'banned pattern')"
rm -rf "$FIX_SKILL"

# ---- 3. fixture hook: CLAUDE_PROJECT_DIR on a code line vs in a comment ---
echo "# fixture hook"
printf '#!/usr/bin/env bash\n# CLAUDE_PROJECT_DIR is pinned to session start -- comment only\n. "$(dirname "$0")/lib/git-ctx.sh"\nexit 0\n' > "$FIX_HOOK"
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
eq "hook comment only: no fail"  0 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep -c 'zz-fixture-hook')"
printf '#!/usr/bin/env bash\nPROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"\n. "$(dirname "$0")/lib/git-ctx.sh"\nexit 0\n' > "$FIX_HOOK"
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
eq "hook code line: exit 1"      1 "$EC"
eq "hook code line: one fail naming CLAUDE_PROJECT_DIR" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'zz-fixture-hook' | grep -c 'CLAUDE_PROJECT_DIR')"
rm -f "$FIX_HOOK"

# ---- 4. version agreement ---------------------------------------------------
echo "# versions"
PV=$(jq -r '.version' "$ROOT/.claude-plugin/plugin.json"); MV=$(jq -r '.plugins[0].version' "$ROOT/.claude-plugin/marketplace.json")
OUT=$("$CHECK" "$ROOT" 2>&1)
if [ "$PV" = "$MV" ]; then
  eq "versions agree ($PV): no version warning" 0 "$(printf '%s' "$OUT" | grep -c 'marketplace.json.*version')"
else
  eq "versions differ ($PV vs $MV): warning emitted" 1 "$(printf '%s' "$OUT" | grep -c 'marketplace.json.*version')"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
