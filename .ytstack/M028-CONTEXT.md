---
milestone: M028
project: ytstack
created: 2026-11-14T09:00:00Z
size: M
---

# M028 -- Context

## Goal

ytstack ships its own adaptations of the six gstack skills it curates, runs them without any gstack install, and keeps them in step with gstack releases through a recorded baseline and a diff tool.

## Exit criteria

- `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and `document-release` are self-contained: bash, git and gh only; no `~/.claude/skills/gstack` path, no gstack binary, no Bun, no symlink; each carries `metadata.upstream`.
- The ytstack contract of each skill (artifact path, frontmatter keys, Terminal State) is unchanged.
- `bin/ytstack-gstack-diff` reports upstream changes per skill since its baseline; the skills are synced to the newest gstack tag at release time.
- `yt_gstack_ctx` and the gstack install path are gone from lib, tests and docs; QUICKSTART tells upgraders how to remove a leftover global gstack registration.
- `bash tests/run-all.sh`, `bin/ytstack-check`, the Codex tests and `claude plugin validate .` pass.

## Size

M -- 3 slices. See `M028-ROADMAP.md`.

## Planning input

The maintainer found ~65 gstack skills registered in `~/.claude/skills/` by gstack's `./setup` (installed for ytstack's sake), asked for them to be removed, for ytstack to ship copies of only the needed skills, and for upstream gstack changes to be considered on every upgrade. Chosen path A (own adaptations) over a 1:1 copy with runtime. Numbered M028 because open PRs #37 and #38 carry M022 to M027 and the main checkout holds M020 planning.

## Decisions locked in discuss phase

2026-11-14: DECISIONS "The six gstack skills become ytstack's own adaptations, synced with upstream; no gstack install".

2026-11-14: The adaptation is drafted from gstack v1.96.0.0 (the tested baseline) by one subagent per skill, then synced to the newest gstack tag with `bin/ytstack-gstack-diff` in S03, so the sync procedure is exercised once before release.

## Open questions

(none)
