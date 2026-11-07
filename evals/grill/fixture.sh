#!/usr/bin/env bash
# Fixture: initialized .ytstack/ with a one-liner and one decision, no milestone, no pitch for the new idea.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p .ytstack
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > .ytstack/PROJECT.md <<'EOF'
---
name: csvexport
one-liner: CSV export for account owners that hands them every row of their data in one click
init_completed: 2026-11-01T10:00:00Z
scope: project
---
# csvexport

Small web app; users export their data as CSV. M001 (endpoint + button) shipped.
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

**Status:** M001 done and released. Nothing planned.

## Next action

Decide what the next milestone is.
EOF
printf '# Decisions\n\n## 2026-11-01: CSV via a streaming endpoint, not a background job\n\nChose streaming from a cursor; a job queue was rejected for operational cost.\n' > .ytstack/DECISIONS.md
printf '# Knowledge\n' > .ytstack/KNOWLEDGE.md
printf '# Runtime\n' > .ytstack/RUNTIME.md
printf '## Ceremony\n\ngranularity: task\nautonomy: loop\nquick_lane: on\nminimal_code: on\n' > .ytstack/PREFERENCES.md
echo "# csvexport" > README.md
git add -A && git commit -qm "chore: scaffold"
