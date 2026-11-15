#!/usr/bin/env bash
# Every evals/<case>/prompt.md frontmatter loads as YAML in `claude plugin eval`.
# A plain (unquoted) scalar must not hold ": " or " #": YAML reads the first as
# a new mapping and the second as a comment. 0.11.0 shipped `external-plan` with
# such a line and the case did not load at all. Without PyYAML in CI, this
# checks the one rule that broke, line by line.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "  ok   - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; [ -n "${2:-}" ] && echo "         $2"; }

lint() {
  awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && /^[A-Za-z_][A-Za-z0-9_]*: / {
      v = $0; sub(/^[A-Za-z_][A-Za-z0-9_]*: /, "", v)
      c = substr(v, 1, 1)
      if (c == "\"" || c == "\x27" || c == "[" || c == "{" || c == ">" || c == "|") next
      if (index(v, ": ") || index(v, " #")) print FILENAME ":" NR ": plain scalar holds \": \" or \" #\"; quote it or use >-"
    }
  ' "$1"
}

echo "# eval case frontmatter"
n=0
for f in "$ROOT"/evals/*/prompt.md; do
  [ -f "$f" ] || continue
  n=$((n + 1))
  out=$(lint "$f")
  if [ -z "$out" ]; then ok "${f#"$ROOT"/}"; else bad "${f#"$ROOT"/}" "$out"; fi
done
[ "$n" -gt 0 ] && ok "found $n cases" || bad "no eval cases found"

# The rule itself catches the 0.11.0 defect.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf -- '---\nruns: 1\nexpected_outcome: it writes `external_plans: plans mapped`\n---\nprompt\n' > "$T/prompt.md"
[ -n "$(lint "$T/prompt.md")" ] && ok "a plain scalar with ': ' is flagged" || bad "a plain scalar with ': ' is flagged"
printf -- '---\nexpected_outcome: >-\n  it writes `external_plans: plans mapped`\n---\n' > "$T/prompt.md"
[ -z "$(lint "$T/prompt.md")" ] && ok "a folded scalar passes" || bad "a folded scalar passes"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
