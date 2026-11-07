---
milestone: M017
slice: S02
project: ytstack
created: 2026-11-07T14:00:00Z
status: planned
task_count: 5
completed_tasks: 1
---

# M017-S02 -- Slice Plan

**Goal:** gstack is an installed, tag-pinned dependency: the lib detects it, the three planning wrappers invoke it through the Skill tool and post-process, the vendored copy is gone, the checker and docs reflect the new contract, #25 is resolved, 0.3.0 ships.

## Tasks

- [x] T01 -- `yt_gstack_ctx` in `hooks/lib/git-ctx.sh`: `YT_GSTACK_DIR` (`${GSTACK_HOME:-$HOME/.claude/skills/gstack}`), `YT_GSTACK_AVAILABLE`, `YT_GSTACK_VERSION` (`VERSION` file), `yt_gstack_skill_ok <name>` (SKILL.md present), `YT_BUN_VERSION` + `YT_BUN_OK` (>= 1.4.2), `YT_GSTACK_PIN` constant + `YT_GSTACK_PIN_OK`; unit tests with a fake install under a temp HOME and with an empty HOME.
- [ ] T02 -- Rewrite the three wrappers: preamble adds the gstack precheck echoes; body = HARD-GATE on `GSTACK_AVAILABLE=no` (message with the pinned install command, stop), else "Invoke the Skill tool with `<name>` (installed gstack), then post-process" with the existing ytstack artifact rules; remove the `cat vendor/gstack/...` blocks; descriptions mention "installed gstack" instead of "vendored"; `tests/skill-preambles.test.sh` asserts `GSTACK_AVAILABLE: no` under an empty HOME and `yes` under a fake install.
- [ ] T03 -- Remove `vendor/gstack/` (`git rm -r`), update `bin/ytstack-check`: cross-ref/sibling checks skip absent vendors, new check that each gstack wrapper names an install path and the pinned tag; update `AGENTS.md`, `NOTICE`, `README.md` (install prerequisites, repo layout), `QUICKSTART.md`, `docs/concept.md`, `docs/methodology.md`, `.ytstack/VENDOR-INVENTORY.md` (vendored vs installed), `.gitignore` (drop gstack-specific lines if any); grep proves no `vendor/gstack` reference remains outside `docs/research/` and `.ytstack/` history files.
- [ ] T04 -- Live validation in a temp HOME: `git clone --branch <latest stable tag> https://github.com/garrytan/gstack` into `$TMP/home/.claude/skills/gstack`, run `./setup --no-browser` with bun 1.4.4, record VERSION, layout and the `gstack-skill-start` behaviour in KNOWLEDGE; run the three wrapper preambles with `HOME=$TMP/home` and assert `GSTACK_AVAILABLE: yes`, `GSTACK_VERSION` set, all three `SKILL_OK: yes`; note the Skill-name collision answer (CONTEXT open question).
- [ ] T05 -- Release 0.3.0: `SECURITY.md` (no CI image built here; #25 resolution; how to report), CHANGELOG 0.3.0, `plugin.json` + `marketplace.json` 0.3.0, DECISIONS/KNOWLEDGE/VENDOR hold note, evidence comment on #25 ("closing on release"), clean-clone verification (`run-all`, `ytstack-check`, `plugin validate`), local tag `v0.3.0`.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: `ls vendor/` shows only `superpowers`; `bin/ytstack-check` 0 fails; wrappers refuse cleanly without gstack and route to the Skill tool with it.

## Notes

- The pinned tag is read from `gh release list -R garrytan/gstack --limit 3` at T01 time and written once into the lib (`YT_GSTACK_PIN`).
- `git rm -r vendor/gstack` is a tracked-content removal (reversible via history); nothing untracked lives there.
