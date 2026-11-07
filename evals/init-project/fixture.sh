#!/usr/bin/env bash
# Fixture: fresh repo with a validated pitch (OFFICE-HOURS.md), no .ytstack/.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
cat > OFFICE-HOURS.md <<'EOF'
---
name: csvexport
one-liner: CSV export for account owners that hands them every row of their data in one click
validated: 2026-11-01T09:00:00Z
---
# Office hours: csvexport

## Demand reality

Three customers asked support for a data export in the last month; two threatened to churn without it.

## Narrowest wedge

One endpoint, one button, no scheduling.
EOF
printf '# csvexport\n' > README.md
git add -A && git commit -qm "chore: pitch"
