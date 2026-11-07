---
milestone: M017
project: ytstack
created: 2026-11-07T14:00:00Z
size: M
---

# M017 -- Context

## Goal

ytstack tracks its upstreams the way each upstream wants to be consumed: superpowers stays a read-only subtree pulled to the v7.0.2 tag with a leak check on the inlined text; gstack stops being a 39 MB vendored copy that our `cat`-wrapper can no longer render and becomes an installed, tag-pinned dependency that the three planning wrappers detect, invoke and post-process. The vulnerable vendored `Dockerfile.ci` leaves the repo (closes #25). Release 0.3.0.

## Exit criteria

- `vendor/superpowers/` at upstream `22f0b46` (tag v7.0.2) via `git subtree pull --squash`; the three wrapped SKILL.md paths exist; `tests/run-all.sh` and `bin/ytstack-check` green; wrapper postambles translate the leaked `superpowers:verification-before-completion` namespace to `ytstack:` and the relative `writing-good-tests.md` link to the vendor path; `ytstack-check` fails on new leaks (`superpowers:` namespace, relative `.md` links) in inlined vendor text.
- `vendor/gstack/` removed from the tree (`git rm -r`); nothing outside `docs/research/` and history references `vendor/gstack`; `ytstack-check` cross-ref and sibling checks handle a missing `vendor/gstack` and instead verify the wrappers' install contract.
- `hooks/lib/git-ctx.sh` gains `yt_gstack_ctx`: `YT_GSTACK_DIR` (`${GSTACK_HOME:-$HOME/.claude/skills/gstack}`), `YT_GSTACK_AVAILABLE`, `YT_GSTACK_VERSION` (from `VERSION`), `YT_GSTACK_SKILL_OK` per wrapped skill, `YT_BUN` (bun >= 1.4.2 present).
- The three wrappers (`office-hours`, `plan-ceo-review`, `plan-eng-review`) run a precheck, invoke the installed gstack skill through the Skill tool, then do the ytstack post-processing; when gstack is missing they stop with the pinned install command (`git clone --branch <tag> https://github.com/garrytan/gstack ~/.claude/skills/gstack && (cd ~/.claude/skills/gstack && ./setup --no-browser)`) and never produce an empty procedure.
- Live validation: gstack cloned at the pinned tag into a temporary `HOME`, `./setup --no-browser` run with bun 1.4.4, the installed layout (`VERSION`, `<skill>/SKILL.md`, `sections/`, `bin/gstack-skill-start`) recorded in KNOWLEDGE, wrapper preambles report `GSTACK_AVAILABLE: yes` against it and `no` against an empty HOME.
- Docs: NOTICE (gstack = required install, not vendored), README install + "Where ytstack writes", QUICKSTART prerequisites (bun + gstack), `docs/concept.md`, `AGENTS.md` (hard rule "never modify vendored content" narrowed to superpowers), `.ytstack/VENDOR-INVENTORY.md` split (vendored vs installed), `docs/methodology.md`; `SECURITY.md` stating that no CI image is built from this repo and how #25 was resolved; CHANGELOG 0.3.0; `plugin.json` + `marketplace.json` 0.3.0.
- Evidence posted on #25.

## Size

M -- 2 slices, 7 tasks (S01 superpowers pull, S02 gstack de-vendor + docs + release).

## Decisions locked in discuss phase

- 2026-11-07: strategy locked in DECISIONS "Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency" (option B).
- 2026-11-07: wrappers invoke the installed gstack skill through the Skill tool (its own preamble, sections and Bun helpers run natively) rather than `cat`-inlining the installed skeleton; ytstack keeps only precheck + post-processing. Reason: the v1.9x skeletons reference `sections/*.md` and `bin/gstack-skill-start` by absolute path, so inlining would reproduce the broken-preamble class of #20.
- 2026-11-07: pin tag = latest gstack stable at execution time (v1.96.0.0 on 2026-11-05 per research; re-check `gh release list` in S02-T01). The pin is a documented recommendation checked by the precheck (`VERSION` >= pin), not enforced.
- 2026-11-07: Bun is an accepted dependency for the three planning wrappers only; every other ytstack skill and hook stays bash-only.

## Open questions

- Does Claude Code expose gstack's user-level skills under their bare names (`office-hours`) when ytstack's namespaced `ytstack:office-hours` also exists? Verify in S02-T04 live validation (list skills with gstack installed in the temp HOME via `claude --help`/`/skills` is not scriptable; fall back to the documented skill-discovery rules and record the answer).
- Marketplace catalog (`yesterday-public-plugins`) must mention the new prerequisite; separate repo, operator authorization.

## Research basis

`docs/research/2026-11-07-notes/vendor-upstream-drift.md`; report point 6.
