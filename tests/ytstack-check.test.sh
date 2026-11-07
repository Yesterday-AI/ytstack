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
# vendor/: real dirs for the catalog roots so fixtures can be added, each real
# skill dir symlinked (read-only is fine for the cross-ref / sibling checks).
mkdir -p "$ROOT/vendor/superpowers/skills"
for d in "$SRC"/vendor/superpowers/skills/*/; do [ -d "$d" ] && ln -s "$d" "$ROOT/vendor/superpowers/skills/$(basename "$d")"; done
[ -d "$SRC/vendor/gstack" ] && ln -s "$SRC/vendor/gstack" "$ROOT/vendor/gstack"
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

# ---- 3b. inlined vendor text leaks (namespace + relative links) -------------
echo "# inline leaks"
FAKE_VENDOR="$ROOT/vendor/superpowers/skills/zz-fake"; mkdir -p "$FAKE_VENDOR"
printf -- '---\nname: zz-fake\ndescription: fake\n---\n# fake\n\nRun `superpowers:zz-other` next. See [notes](notes.md) and https://example.com/x.md.\n' > "$FAKE_VENDOR/SKILL.md"
FIX_WRAP="$ROOT/skills/zz-fixture-wrapper"; mkdir -p "$FIX_WRAP"
cat > "$FIX_WRAP/SKILL.md" <<'EOF'
---
name: zz-fixture-wrapper
description: "Fixture wrapper for ytstack-check tests. Not a real skill."
tier: core
version: 0.0.1
allowed-tools: Read
---

# zz-fixture-wrapper

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/zz-fake/SKILL.md"
```
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
F=$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'zz-fixture-wrapper')
eq "leaks: namespace leak without note flagged" 1 "$(printf '%s' "$F" | grep -c 'superpowers:zz-other')"
eq "leaks: relative link leak without note flagged" 1 "$(printf '%s' "$F" | grep -c 'notes.md')"
eq "leaks: absolute URL not flagged" 0 "$(printf '%s' "$F" | grep -c 'example.com')"
cat >> "$FIX_WRAP/SKILL.md" <<'EOF'

## Namespace note (ytstack)

Read `superpowers:zz-other` as `ytstack:zz-other`. Relative links such as `notes.md` resolve under `vendor/superpowers/skills/zz-fake/`.
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "leaks: note with token + 'resolve under' clears both" 0 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'zz-fixture-wrapper' | grep -c 'inlined vendor text')"
rm -rf "$FIX_WRAP" "$FAKE_VENDOR"

# ---- 3c. gstack wrapper install contract ------------------------------------
echo "# gstack wrappers"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "gstack wrappers: real tree passes the contract" 0 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep -c 'gstack wrapper')"
cp "$ROOT/skills/office-hours/SKILL.md" "$TMP/oh.bak"
printf '\n```!\ncat "${CLAUDE_SKILL_DIR}/../../vendor/gstack/office-hours/SKILL.md"\n```\n' >> "$ROOT/skills/office-hours/SKILL.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "gstack wrappers: vendor/gstack reference flagged" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'office-hours' | grep -c 'never inlined')"
cp "$TMP/oh.bak" "$ROOT/skills/office-hours/SKILL.md"
sed 's/yt_gstack_ctx/yt_nothing/g' "$TMP/oh.bak" > "$ROOT/skills/office-hours/SKILL.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "gstack wrappers: missing precheck flagged" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'office-hours' | grep -c 'yt_gstack_ctx')"
cp "$TMP/oh.bak" "$ROOT/skills/office-hours/SKILL.md"

# ---- 4. version agreement ---------------------------------------------------
echo "# versions"
PV=$(jq -r '.version' "$ROOT/.claude-plugin/plugin.json"); MV=$(jq -r '.plugins[0].version' "$ROOT/.claude-plugin/marketplace.json")
OUT=$("$CHECK" "$ROOT" 2>&1)
if [ "$PV" = "$MV" ]; then
  eq "versions agree ($PV): no version warning" 0 "$(printf '%s' "$OUT" | grep -c 'marketplace.json.*version')"
else
  eq "versions differ ($PV vs $MV): warning emitted" 1 "$(printf '%s' "$OUT" | grep -c 'marketplace.json.*version')"
fi

# ---- 5. metadata: migration (M019-S01-T01) ----------------------------------
echo "# metadata"
FIX_META="$ROOT/skills/zz-fixture-meta"; mkdir -p "$FIX_META"
cat > "$FIX_META/SKILL.md" <<'EOF'
---
name: zz-fixture-meta
description: "Fixture with legacy top-level keys."
tier: core
version: 0.0.1
kind: reference
triggers:
  - legacy fixture
allowed-tools: Read
---

# zz-fixture-meta
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "legacy top-level tier/version/kind/triggers -> one 'move under metadata' warning" 1 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*move under metadata')"
eq "legacy kind: reference still recognised (no Checklist fail)" 0 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*Checklist')"
cat > "$FIX_META/SKILL.md" <<'EOF'
---
name: zz-fixture-meta
description: "Fixture with metadata block."
metadata:
  tier: core
  version: 0.0.1
  kind: reference
  triggers:
    - new fixture
allowed-tools: Read
---

# zz-fixture-meta
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "metadata block -> no legacy warning" 0 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*move under metadata')"
eq "metadata.kind: reference recognised (no Checklist fail)" 0 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*Checklist')"
eq "metadata.tier/version present -> no missing warning" 0 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*missing metadata')"
cat > "$FIX_META/SKILL.md" <<'EOF'
---
name: zz-fixture-meta
description: "Fixture without tier/version anywhere."
allowed-tools: Read
---

# zz-fixture-meta

## Checklist

You MUST do it.

## Terminal State

Return.
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "no tier/version anywhere -> 'missing metadata.tier/version' warning" 1 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-meta.*missing metadata')"
rm -rf "$FIX_META"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "real tree: zero legacy top-level warnings" 0 "$(printf '%s' "$OUT" | grep -c 'move under metadata')"
eq "real tree: zero missing metadata warnings"  0 "$(printf '%s' "$OUT" | grep -c 'missing metadata')"

# ---- 6. description budget + trigger-only + invocability (M019-S01-T03) ------
echo "# descriptions"
FIX_DESC="$ROOT/skills/zz-fixture-desc"; mkdir -p "$FIX_DESC"
LONG=$(printf 'x%.0s' $(seq 1 1100))
cat > "$FIX_DESC/SKILL.md" <<EOF
---
name: zz-fixture-desc
description: "$LONG"
metadata:
  tier: core
  version: 0.0.1
  kind: reference
allowed-tools: Read
---

# zz-fixture-desc
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "description > 1,024 chars -> FAIL"                 1 "$(printf '%s' "$OUT" | grep -c '\[fail\].*zz-fixture-desc.*description.*1,024')"
eq "kind: reference without user-invocable -> WARN"    1 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-desc.*user-invocable')"
cat > "$FIX_DESC/SKILL.md" <<'EOF'
---
name: zz-fixture-desc
description: "RED-GREEN-REFACTOR: Step 1 write a test. Thin ytstack wrapper around the vendored thing. Uses four modes and six forcing questions."
metadata:
  tier: core
  version: 0.0.1
  kind: directive
user-invocable: false
allowed-tools: Read
---

# zz-fixture-desc
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "procedure-summary phrases in description -> one WARN" 1 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-desc.*procedure summary')"
eq "directive with user-invocable -> no invocability WARN" 0 "$(printf '%s' "$OUT" | grep -c 'zz-fixture-desc.*user-invocable')"
rm -rf "$FIX_DESC"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "real tree: zero description budget fails"      0 "$(printf '%s' "$OUT" | grep -c 'description.*1,024')"
eq "real tree: zero procedure-summary warnings"    0 "$(printf '%s' "$OUT" | grep -c 'procedure summary')"
eq "real tree: zero invocability warnings"         0 "$(printf '%s' "$OUT" | grep -c 'user-invocable')"

# ---- 7. agent subagent-contract fields (M019-S04) ----------------------------
echo "# agents"
FIX_AGENT="$ROOT/agents/zz-fixture-agent.md"
cat > "$FIX_AGENT" <<'EOF'
---
name: zz-fixture-agent
description: |
  Fixture agent.
  <example>one</example>
  <example>two</example>
model: inherit
isolation: sandbox
memory: global
hooks: []
tools:
  - Read
skills:
  - ytstack:resume-session
---

# zz-fixture-agent

Does the fixture thing. Does NOT do anything else.

## Subagent context

SUBAGENT-STOP applies.
EOF
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "agent: isolation other than worktree -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "zz-fixture-agent.*isolation 'sandbox'")"
eq "agent: memory outside user|project|local -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "zz-fixture-agent.*memory 'global'")"
eq "agent: hooks ignored for plugin subagents -> WARN" 1 "$(printf '%s' "$OUT" | grep -c "zz-fixture-agent.*'hooks' is ignored")"
rm -f "$FIX_AGENT"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "real agents: implementer runs in a worktree (no warning)" 0 "$(printf '%s' "$OUT" | grep -c 'implementer should run with isolation')"
eq "real agents: zero isolation/memory fails" 0 "$(printf '%s' "$OUT" | grep -c "agents/.*\(isolation\|memory\) '")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
