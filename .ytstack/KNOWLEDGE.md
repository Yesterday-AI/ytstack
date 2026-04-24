# Knowledge

Patterns, rules, and lessons learned while building ytstack. This file is read by every future session. Keep it short. Keep it actionable.

## Conventions

- **UX contracts are mandatory.** Every skill must pass `docs/ux/*` checks. The `ytstack-skill-check` tool (planned M008 pre-release) enforces this in CI.
- **No 1:1 copying from upstream.** Vendored superpowers/gstack content is read-only. If we need to change behavior, wrap it in a ytstack-namespaced skill, don't modify the vendor.
- **Artifact-first thinking.** If a decision or learning would help future sessions, write it to `DECISIONS.md` or `KNOWLEDGE.md`, not just conversation.
- **Third-party methodology attribution is "inspired by", never verbatim.** Concepts adapted, prose rewritten. Do not name the external source in public artifacts.

## Lessons learned

- **Hook matcher `startup|clear|compact` is the key.** SessionStart hook only fires on these three events. `/reload-plugins` does NOT fire it, which means mid-session plugin enable produces dead-looking skills. Always test with `/clear` after install.
- **The `using-<plugin>` skill is a hook-injected prompt, not a regular skill.** superpowers demonstrates this: the SessionStart hook reads `skills/using-superpowers/SKILL.md` and injects the full content via `additionalContext`. That's why auto-triggering works -- it's forceful prompt priming, not passive skill availability.
- **Agent Teams replicate GSD's fresh-context-per-task natively.** Each teammate is a separate Claude Code session with its own 200k window. No need to build this ourselves.
- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` required** to enable Agent Teams. Version v2.1.32+ required.

## Gotchas -- and things we got wrong before

- **Competitive claims require skill-inventory checks.** Initial README drafts (2026-04-24) overclaimed that superpowers "offers nothing for planning" and gstack "offers nothing for execution." Both wrong. superpowers has `brainstorming`, `writing-plans`, `executing-plans`. gstack has `investigate` (equivalent to superpowers' systematic-debugging), `qa`, `review`, `ship`, and context-save/restore skills. The actual ytstack value-prop is cherry-picking the _non-overlapping best_ from each, plus adding GSD-style artifact hierarchy that neither has. Lesson: before any "X tool offers nothing for Y" statement, grep the actual skill dirs.

- **Project-state injection alone is not enough -- you need a directive.** The initial M002 SessionStart hook injected only project state (milestone / slice / task + next action). That told the agent _where_ it was, but not _what to do_ with ytstack. Result: ytstack skills sat dormant unless the user typed `/ytstack:<name>` manually. The superpowers pattern is clearer: their SessionStart hook injects the entire content of `using-superpowers/SKILL.md` -- a forceful directive with trigger map, anti-rationalization Red Flags, and "1% chance → invoke" compliance pressure. Without this primer, the plugin is a slash-command menu the user has to drive. With it, the agent reaches for skills proactively based on natural-language intent. See 2026-04-24 DECISIONS entry and `skills/using-ytstack/SKILL.md` for ytstack's version. Lesson: a SessionStart hook that only injects state produces a passive plugin; it needs to also prime the agent's behavior.

- **Don't cargo-cult templates. Cross-reference dependent files before designing a new artifact.** While writing the three `agents/` files (post-M009), we used `superpowers/agents/code-reviewer.md` as template and carried over its frontmatter verbatim -- which didn't include a `skills:` field. Result: three ytstack agents that are supposed to invoke ytstack skills, with no `skills` allowlist. The miss was caught on review ("die agents haben keine skills?????"), not by process. Root cause: we reached for a template instead of re-reading `skills/spawn-milestone-team/SKILL.md` (which references these agents and specifies what skills they'll use) and designing from purpose. Lesson: when creating a new file type (skill, agent, hook), FIRST read every other file that references or depends on this new file, THEN design from purpose. Templates are reference, not contract. Template-driven development produces files that look right and miss the point. See `docs/ux/agent-structure.md` (added to prevent this exact miss in future) and the 2026-04-24 DECISIONS entry on using-ytstack.

- **Bulk find-replace can corrupt meta-references.** While fixing 288 em-dash (`—`) warnings by bulk-replacing `—` → `--`, the same replacement hit docs/ux/writing-style.md's banned-punctuation rule itself (which was literally _describing_ the banned `—` character), leaving the rule reading "Em dashes (`--`)" -- self-contradictory. Same with KNOWLEDGE.md's lesson and REVIEW-NOTES' entry about the same issue. Lesson: before any bulk text replacement, grep for files where the text-being-replaced is the _subject of discussion_ (meta-references), not just content. Exclude or post-edit those files. Simple heuristic: if a file contains phrases like "banned", "converts X to Y", "rule about Y", the Y-references in that file are probably meta.

## Gotchas

- **Each bash code block in a SKILL.md runs in a separate shell.** Variables don't persist between blocks. Pass state via prose ("remember as `_X`") or disk files, never via shell variables across blocks.
- **Dot-prefixed directories under `~/.claude/skills/` are hidden from skill discovery.** We exploit this for `.deactivated/` snapshots. Claude Code only scans immediate non-dot children.
- **gstack SKILL.md files are auto-generated from `.tmpl` via `bun run gen:skill-docs`.** When reading vendored gstack content for reference, compare with the template, not just the generated MD.
- **Em dashes (`—`), "delve", "robust", "comprehensive" are banned.** See `docs/ux/writing-style.md` for the full list. macOS autocorrect silently converts `--` to `—`; disable smart-punctuation or run `bin/ytstack-check` pre-commit.
- **Headless `claude -p` blocks on Write permissions by default.** In M001 T05 smoke-test, first headless run stalled because `-p` mode cannot display or approve the Write-tool permission dialog. Fix: pass `--permission-mode acceptEdits` for file-creating skills, or `--dangerously-skip-permissions` for fully isolated sandbox/CI runs. Document this prominently for any automated-test scenario.
- **Headless mode may not register `--plugin-dir` skills for `Skill` tool invocation.** In the same smoke-test, the headless Claude reported that the `Skill` tool invocation for `ytstack:init-project` errored as "not registered in the harness", but the agent fell back to following the SKILL.md procedure manually -- producing correct output. This means: (1) our skills must work as "prompted instructions" without requiring the `Skill` tool, and (2) real interactive testing is still needed to verify the `Skill` tool registration works in non-headless mode. Worth an upstream bug report once reproduced in interactive mode.

## Terminology

- **Milestone (M###):** a shippable chunk of the roadmap. 1-7 slices per milestone.
- **Slice (S##):** 1-7 tasks inside a milestone, executable sequentially.
- **Task (T##):** one atomic unit that fits in one context window. If it doesn't, split into two tasks.
- **Artifact:** a persistent file in `.ytstack/` that survives across sessions.
- **Spec:** a design doc written before code, committed under `docs/ytstack/specs/`.
- **Handoff:** state written when a session ends, read when the next session starts.
- **Sentinel file:** marker in `~/.ytstack/.<name>-prompted` that indicates an "ask-once" question has been answered.
- **Tier:** question scope -- `core` (session-wide, persisted), `task` (single turn, not persisted), `background` (skippable, default-pickable).

## Related projects

- **superpowers** -- vendored in `vendor/superpowers/` from M005. https://github.com/obra/superpowers
- **gstack** -- vendored in `vendor/gstack/` from M004. Garry Tan's framework.
- **GSD v2** -- NOT vendored, but informs our artifact model. https://github.com/gsd-build/gsd-2
