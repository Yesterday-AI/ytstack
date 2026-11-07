#!/usr/bin/env bash
# Run every tests/*.test.sh from a neutral cwd (a failed `cd` inside a suite
# must never land in the real checkout). Exit 1 on the first failing suite.
#
#   bash tests/run-all.sh            # macOS/Linux, current bash
#   bash tests/run-all.sh --linux    # same, inside a Linux container (bash 5, git, jq, python3)
#
# --linux needs a working Docker daemon; otherwise it prints a clear skip line
# and exits 0 so local runs stay green.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

if [ "${1:-}" = "--linux" ]; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "run-all --linux: docker unavailable, skipped"
    exit 0
  fi
  # alpine/git ships git; add bash, jq, python3 for the suites. Read-only mount;
  # suites write only to mktemp dirs.
  # alpine/git's entrypoint is `git`; override it.
  exec docker run --rm --entrypoint sh -v "$ROOT":/w:ro -w /w alpine/git:latest \
    -c 'apk add --no-cache bash jq python3 coreutils >/dev/null 2>&1 && git config --global safe.directory "*" && bash tests/run-all.sh'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ytrun.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 2

echo "ytstack test suites ($(bash --version | head -1 | sed 's/GNU bash, version //; s/ (.*//'), $(uname -s))"
status=0
for t in "$ROOT"/tests/*.test.sh; do
  name=$(basename "$t" .test.sh)
  out=$(bash "$t" 2>&1); ec=$?
  last=$(printf '%s\n' "$out" | tail -1)
  if [ $ec -eq 0 ]; then
    printf '  PASS  %-22s %s\n' "$name" "$last"
  else
    printf '  FAIL  %-22s %s\n' "$name" "$last"
    printf '%s\n' "$out" | grep '^  FAIL' | head -10
    status=1
    break
  fi
done
[ $status -eq 0 ] && echo "ALL SUITES PASSED" || echo "SUITE FAILURE"
exit $status
