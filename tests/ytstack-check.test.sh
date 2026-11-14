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

# ---- 3c. skills adapted from gstack: self-contained contract (2026-11-14) ----
echo "# adapted gstack skills"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "adapted: real tree passes the contract" 0 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep -c 'adapted from gstack')"
cp "$ROOT/skills/office-hours/SKILL.md" "$TMP/oh.bak"
printf '\n```bash\n~/.claude/skills/gstack/bin/gstack-slug\n```\n' >> "$ROOT/skills/office-hours/SKILL.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "adapted: gstack runtime path flagged" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'office-hours' | grep -c 'gstack runtime')"
cp "$TMP/oh.bak" "$ROOT/skills/office-hours/SKILL.md"
grep -v '^  upstream:' "$TMP/oh.bak" > "$ROOT/skills/office-hours/SKILL.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "adapted: missing metadata.upstream flagged" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'office-hours' | grep -c 'metadata.upstream')"
cp "$TMP/oh.bak" "$ROOT/skills/office-hours/SKILL.md"
mkdir -p "$ROOT/skills/office-hours/references"; ln -s /etc/hosts "$ROOT/skills/office-hours/references/zz-link.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "adapted: symlink in the skill dir flagged" 1 "$(printf '%s' "$OUT" | grep '\[fail\]' | grep 'office-hours' | grep -c 'symlink')"
rm -f "$ROOT/skills/office-hours/references/zz-link.md"; rmdir "$ROOT/skills/office-hours/references" 2>/dev/null

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

# ---- technical spec (M022): own spec linted, "Keeping this true" copies in sync
echo "# technical spec"
eq "no .ytstack/spec in the tree: spec check skipped" 0 "$(printf '%s' "$OUT" | grep -c '\] spec:')"
eq "scaffold skills carry the maintenance block verbatim" 0 "$(printf '%s' "$OUT" | grep -c "'Keeping this true' block differs")"
mkdir -p "$ROOT/.ytstack/spec"
printf -- '---\nproject: fx\n---\n\n# fx\n\n## Areas\n\n| Area | Covers | Status | File |\n|---|---|---|---|\n| core | x | planned | [core.md](core.md) |\n\n## Keeping this true\n\n- x\n' > "$ROOT/.ytstack/spec/SPEC.md"
printf -- '---\narea: core\nstatus: planned\npaths: []\nverified_at: none\n---\n\n## Purpose\n\nx\n\n## Where implemented\n\nx\n\n## How to verify\n\nx\n\n## Decisions that apply now\n\nx\n' > "$ROOT/.ytstack/spec/core.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "well-formed own spec: no spec finding" 0 "$(printf '%s' "$OUT" | grep -c '\] spec:')"
printf '\n## History\n\nx\n' >> "$ROOT/.ytstack/spec/core.md"
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
eq "own spec with a format error -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "\[fail\] spec: core.md: section '## History'")"
eq "own spec with a format error -> exit 1" 1 "$EC"
rm -rf "$ROOT/.ytstack"
cp "$ROOT/skills/init-project/SKILL.md" "$TMP/init.bak"
sed 's/^- A task plan names its \*\*Spec impact\*\*.*/- A task plan may name a spec impact./' "$TMP/init.bak" > "$ROOT/skills/init-project/SKILL.md"
OUT=$("$CHECK" "$ROOT" 2>&1)
eq "a drifted copy of the maintenance block -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "init-project/SKILL.md: the 'Keeping this true' block differs")"
cp "$TMP/init.bak" "$ROOT/skills/init-project/SKILL.md"

# ---- standing instructions, one file per entry (issue #57) -------------------
echo "# standing entries"
PRJ="$TMP/project"; SD="$PRJ/.ytstack/standing"; mkdir -p "$PRJ/.ytstack"
entry() { # entry <name> <given> <scope> <supersedes> [body]
  printf -- '---\ngiven: %s\nscope: %s\nsupersedes: %s\n---\n\n%s\n' "$2" "$3" "$4" "${5-An instruction.}" > "$SD/$1.md"
}
OUT=$("$CHECK" --standing "$PRJ" 2>&1); EC=$?
eq "--standing without a directory: exit 0 (STANDING.md alone is valid)" 0 "$EC"
mkdir -p "$SD"
entry 20261114T1225Z-at-most-ten 2026-11-14T12:25:00Z "every author" ""
entry 20261114T1436Z-at-most-fifteen 2026-11-14T14:36:00Z "every lane" 20261114T1225Z-at-most-ten
printf '# Standing\n' > "$SD/README.md"
OUT=$("$CHECK" --standing "$PRJ" 2>&1); EC=$?
eq "--standing: well-formed entries, README ignored -> exit 0" 0 "$EC"
eq "--standing: counts the entries" 1 "$(printf '%s' "$OUT" | grep -c 'OK: 2 standing entries')"
OUT=$("$CHECK" --standing "$PRJ/.ytstack" 2>&1); EC=$?
eq "--standing: the .ytstack dir itself is accepted" 0 "$EC"
entry 20261114T1500Z-gone 2026-11-14T15:00:00Z "x" 20261114T0900Z-never-written
entry 20261114T1510Z-later 2026-11-14T15:10:00Z "x" 20261114T1600Z-future.md
entry 20261114T1600Z-future 2026-11-14T16:00:00Z "x" ""
entry 20261114T1520Z-bad-given 2026-11-14 "x" ""
entry 20261114T1530Z-wrong-minute 2026-11-14T15:31:00Z "x" ""
entry 20261114T1540Z-no-scope 2026-11-14T15:40:00Z "" ""
entry 20261114T1550Z-no-body 2026-11-14T15:50:00Z "x" "" ""
entry 20261114T1555Z-self 2026-11-14T15:55:00Z "x" 20261114T1555Z-self
printf 'no frontmatter\n' > "$SD/20261114T1700Z-plain.md"
printf -- '---\ngiven: 2026-11-14T17:00:00Z\nscope: x\n---\n\nx\n' > "$SD/Report-Results.md"
OUT=$("$CHECK" --standing "$PRJ" 2>&1); EC=$?
eq "--standing: broken entries -> exit 1" 1 "$EC"
eq "supersedes naming no entry -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1500Z-gone.md: supersedes '20261114T0900Z-never-written' names no entry")"
eq "supersedes naming a newer entry (.md suffix allowed) -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1510Z-later.md: supersedes '20261114T1600Z-future', which is newer")"
eq "given not an ISO time -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1520Z-bad-given.md: given '2026-11-14' is not an ISO UTC time")"
eq "given and the name differ -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1530Z-wrong-minute.md: given 2026-11-14T15:31:00Z and the time in the name differ")"
eq "empty scope -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1540Z-no-scope.md: scope is empty")"
eq "no body -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1550Z-no-body.md: no instruction below the frontmatter")"
eq "supersedes itself -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1555Z-self.md: supersedes names the entry itself")"
eq "no frontmatter -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1700Z-plain.md: no frontmatter")"
eq "a name without the UTC prefix -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "Report-Results.md: name is not")"
eq "the well-formed entries stay quiet" 0 "$(printf '%s' "$OUT" | grep -c "at-most-\(ten\|fifteen\)")"
# optional seconds: 12:25:30 is newer than 12:25 (Codex finding on PR #63)
rm -f "$SD"/*.md
entry 20261114T1225Z-old 2026-11-14T12:25:00Z "x" ""
entry 20261114T122530Z-new 2026-11-14T12:25:30Z "x" 20261114T1225Z-old
OUT=$("$CHECK" --standing "$PRJ" 2>&1); EC=$?
eq "seconds: 12:25:30 may supersede 12:25 -> exit 0" 0 "$EC"
entry 20261114T1225Z-old 2026-11-14T12:25:00Z "x" 20261114T122530Z-new
entry 20261114T122530Z-new 2026-11-14T12:25:30Z "x" ""
OUT=$("$CHECK" --standing "$PRJ" 2>&1)
eq "seconds: 12:25 superseding 12:25:30 -> newer FAIL" 1 "$(printf '%s' "$OUT" | grep -c "1225Z-old.md: supersedes '20261114T122530Z-new', which is newer")"
# impossible dates and times, in the name and in given
rm -f "$SD"/*.md
entry 20261340T2960Z-bad-name 2026-13-40T29:60Z "x" ""
entry 20240229T1200Z-leap-day 2024-02-29T12:00:00Z "x" ""
entry 20250229T1200Z-no-leap-day 2025-02-29T12:00:00Z "x" ""
entry 20261114T2359Z-bad-given-seconds 2026-11-14T23:59:60Z "x" ""
entry 20261131T1200Z-november-31 2026-11-31T12:00Z "x" ""
OUT=$("$CHECK" --standing "$PRJ" 2>&1)
eq "time: month 13, day 40, hour 29, minute 60 in the name -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "20261340T2960Z-bad-name.md: the time in the name is not a real")"
eq "time: 29 February of a leap year passes" 0 "$(printf '%s' "$OUT" | grep -c "standing/20240229T1200Z-leap-day.md")"
eq "time: 29 February of a common year -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "no-leap-day.md: the time in the name is not a real")"
eq "time: 31 November -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "november-31.md: the time in the name is not a real")"
eq "time: second 60 in given -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "bad-given-seconds.md: given 2026-11-14T23:59:60Z is not a real")"
rm -f "$SD"/*.md
# user scope: no .ytstack in the repository, the entries under ~/.ytstack/projects/<repo key>
UREPO="$TMP/userscope"; mkdir -p "$UREPO" "$TMP/home"
( cd "$UREPO" && git init -q ) >/dev/null 2>&1
UKEY=$(cd "$UREPO" && HOME="$TMP/home" bash -c '. "$1"; yt_git_ctx "$PWD"; printf %s "$YT_REPO_KEY"' x "$SRC/hooks/lib/git-ctx.sh")
USD="$TMP/home/.ytstack/projects/$UKEY/standing"; mkdir -p "$USD"
printf -- '---\ngiven: 2026-11-14T12:25:00Z\nscope: x\nsupersedes: 20261114T0900Z-missing\n---\n\nx\n' > "$USD/20261114T1225Z-user.md"
# the real interpreter: a version-manager shim may not run with another HOME
PYREAL=$(python3 -c 'import sys; print(sys.executable)')
OUT=$(cd "$UREPO" && HOME="$TMP/home" "$PYREAL" "$CHECK" --standing 2>&1); EC=$?
eq "user scope: --standing from the repository finds ~/.ytstack/projects/<key> -> exit 1" 1 "$EC"
eq "user scope: the broken entry is named" 1 "$(printf '%s' "$OUT" | grep -c "1225Z-user.md: supersedes '20261114T0900Z-missing' names no entry")"
OUT=$(cd "$TMP/home" && HOME="$TMP/nohome" "$PYREAL" "$CHECK" --standing 2>&1); EC=$?
eq "no .ytstack anywhere: still exit 0" 0 "$EC"
# the plugin's own .ytstack/standing/ is part of the full run
mkdir -p "$ROOT/.ytstack/standing"
entry 20261114T1500Z-gone 2026-11-14T15:00:00Z "x" 20261114T0900Z-never-written
cp "$SD/20261114T1500Z-gone.md" "$ROOT/.ytstack/standing/"
OUT=$("$CHECK" "$ROOT" 2>&1); EC=$?
eq "full run: a broken own standing entry -> FAIL" 1 "$(printf '%s' "$OUT" | grep -c "\[fail\] .ytstack/standing/20261114T1500Z-gone.md: supersedes")"
eq "full run: exit 1" 1 "$EC"
rm -rf "$ROOT/.ytstack"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
