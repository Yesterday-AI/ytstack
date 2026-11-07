#!/usr/bin/env bash
# Schema/contract tests for hooks/hooks.json (M016-S01-T06).
#
#   - SessionStart also fires on `fork`.
#   - Every command hook declares shell: bash and points at an existing,
#     syntactically valid hooks/<name> file.
#   - Fail-open: no onFailure: block anywhere (advisory hooks must never
#     block tools when they crash; see issue #19).
#   - SessionEnd timeout reflects the 1.5 s plugin budget.
#
# Run: /bin/bash tests/hooks-json.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
J="$ROOT/hooks/hooks.json"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }

jq -e . "$J" >/dev/null 2>&1 && ok "hooks.json is valid JSON" || { bad "hooks.json is valid JSON"; echo "$PASS passed, $FAIL failed"; exit 1; }

eq "ships exactly the nine events" \
  "PostToolUse PreCompact PreToolUse SessionEnd SessionStart Stop TaskCompleted TaskCreated TeammateIdle" \
  "$(jq -r '.hooks | keys | sort | join(" ")' "$J")"

M=$(jq -r '.hooks.SessionStart[0].matcher' "$J")
for src in startup resume clear compact fork; do
  case "|$M|" in *"|$src|"*) ok "SessionStart matcher has $src";; *) bad "SessionStart matcher has $src" "$M";; esac
done

# Every command handler: shell bash + command file exists + bash -n clean
while IFS=$'\t' read -r ev shell cmd; do
  [ "$shell" = "bash" ] && ok "$ev: shell is bash" || bad "$ev: shell is bash" "$shell"
  f=${cmd#*\$\{CLAUDE_PLUGIN_ROOT\}/}; f=${f%\"*}; f=${f%% *}; f="$ROOT/${f#/}"
  [ -f "$f" ] && ok "$ev: command file exists ($(basename "$f"))" || bad "$ev: command file exists" "$f"
  bash -n "$f" 2>/dev/null && ok "$ev: command file parses" || bad "$ev: command file parses" "$f"
  case "$f" in */hooks/*) ok "$ev: command is under hooks/";; *) bad "$ev: command is under hooks/" "$f";; esac
done < <(jq -r '.hooks | to_entries[] | .key as $ev | .value[].hooks[] | select(.type=="command") | [$ev, (.shell // "unset"), .command] | @tsv' "$J")

eq "no onFailure: block anywhere" 0 "$(jq '[.hooks[][].hooks[] | select(.onFailure=="block")] | length' "$J")"
eq "all handlers synchronous (async false)" 0 "$(jq '[.hooks[][].hooks[] | select(.async==true)] | length' "$J")"
T=$(jq '.hooks.SessionEnd[0].hooks[0].timeout // 0' "$J")
if [ "$T" -le 2 ] && [ "$T" -ge 1 ]; then ok "SessionEnd timeout within budget ($T s)"; else bad "SessionEnd timeout within budget" "$T"; fi
eq "PreToolUse matcher covers Edit|Write|MultiEdit" "Edit|Write|MultiEdit" "$(jq -r '.hooks.PreToolUse[0].matcher' "$J")"
eq "PostToolUse matcher is Bash" "Bash" "$(jq -r '.hooks.PostToolUse[0].matcher' "$J")"

if command -v claude >/dev/null 2>&1; then
  if (cd "$ROOT" && claude plugin validate . >/tmp/ytcheck-validate.txt 2>&1); then ok "claude plugin validate . exits 0"; else bad "claude plugin validate . exits 0" "$(tail -3 /tmp/ytcheck-validate.txt | tr '\n' ' ')"; fi
else
  ok "claude CLI not on PATH -- plugin validate skipped"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
