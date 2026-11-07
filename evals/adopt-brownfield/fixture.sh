#!/usr/bin/env bash
# Fixture: mature repo (README, docs/, CHANGELOG, ADR, several commits), no .ytstack/.
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
mkdir -p docs/adr src
cat > README.md <<'EOF'
# csvexport

Export service for the account dashboard. Node 22, Hono, PostgreSQL.

## Run

    npm install && npm run dev

## Docs

See docs/architecture.md and docs/adr/.
EOF
cat > docs/architecture.md <<'EOF'
# Architecture

Single Hono service. `/export` streams CSV straight from a cursor; no job queue.
Auth via session cookie checked by `src/auth.ts`.
EOF
cat > docs/adr/0001-streaming-not-jobs.md <<'EOF'
# ADR 0001: stream exports, no background jobs

Accepted 2026-09-10. Exports are streamed from a DB cursor; a job queue was rejected for operational cost.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.2.0 - 2026-10-20
- gzip responses above 10 MB

## 1.1.0 - 2026-09-15
- /export endpoint
EOF
printf '{"name":"csvexport","version":"1.2.0","scripts":{"dev":"node src/index.js","test":"node --test"}}\n' > package.json
printf 'export const version = "1.2.0";\n' > src/index.js
git add -A && git commit -qm "chore: initial import"
printf 'export function auth() { return true; }\n' > src/auth.js && git add -A && git commit -qm "feat: session auth"
printf '\n## 1.2.1 - 2026-11-01\n- fix header line\n' >> CHANGELOG.md && git add -A && git commit -qm "fix: header line"
