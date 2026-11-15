#!/usr/bin/env bash
# Fixture: project csvexport with ytstack and upstream_feedback: suggest
# (the default, written out). Yesterday a coordinator session polled three
# pull requests by hand and wrote its own polling loop, although the plugin
# ships a PR watch; the person tells the session about it today. That is a
# gap in ytstack itself: under suggest the session drafts and checks an
# issue body with bin/ytstack-upstream and shows the person the draft path,
# and posts nothing. The same scenario under file is the case upstream-file.
set -eu
MODE=suggest
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
mkdir -p .ytstack scripts src
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small web app; users import and export their data as CSV.
EOF
cat > .ytstack/STATE.md <<EOF
---
project: csvexport
last_updated: $NOW
current_milestone: none
active_slice: none
active_task: none
---
# State

**Status:** M002 shipped yesterday through three lanes. No milestone in progress.

## Next action

Plan the next milestone.
EOF
printf '# Decisions\n\n- 2026-11-01: CSV via a streaming endpoint, not a background job.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n\n## Gotchas\n' > .ytstack/KNOWLEDGE.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\nupstream_feedback: %s\n' "$MODE" > .ytstack/PREFERENCES.md
printf '# Agents\n\nRun the tests with bash tests/run.sh.\n' > AGENTS.md
cat > scripts/poll-prs.sh <<'EOF'
#!/bin/sh
# Written by the coordinator session on 2026-11-14: polls the open pull
# requests every 60 seconds and prints their checks. 41 gh pr view calls that
# afternoon for PRs 12, 13 and 14.
while true; do
  for pr in 12 13 14; do gh pr view "$pr" --json statusCheckRollup; done
  sleep 60
done
EOF
chmod +x scripts/poll-prs.sh
echo "// export" > src/export.js
git add -A && git commit -qm "chore: scaffold"
