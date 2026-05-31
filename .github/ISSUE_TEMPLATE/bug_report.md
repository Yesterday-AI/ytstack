---
name: Bug report
about: A ytstack skill, hook, or artifact misbehaved
title: "fix: <short description>"
labels: bug
assignees: ''
---

## What broke

<!-- One sentence. Which skill, hook, or artifact, and what went wrong. -->

## The session that triggered it

<!-- ytstack values real, observed problems over hypotheticals. What were you doing?
What did you (or the agent) say? Paste the relevant prompt + agent response if you can. -->

## Expected vs actual

- **Expected:**
- **Actual:**

## Environment

- ytstack version (README badge / plugin.json):
- Claude Code version:
- Install path: `yesterday-public-plugins` marketplace / self-marketplace / `--plugin-dir` local
- Greenfield (no `.ytstack/`) or brownfield (existing `.ytstack/`):
- Agent Teams in use (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)? yes / no

## Logs / artifacts

<!-- Relevant lines from the hook output, the injected SessionStart context, or the
.ytstack/ artifact that got mangled. Redact anything sensitive. -->
