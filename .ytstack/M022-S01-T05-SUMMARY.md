---
milestone: M022
slice: S01
task: T05
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S01-T05 -- Summary

## Commits

- The commit that carries this file (`M022-S01-T05: entry documents agree with the repository`).

## Outcome

`PROJECT.md` named both hosts, superpowers as a read-only subtree, gstack as an installed, tag-pinned dependency and the technical spec among the artifacts. Its "Current status" section no longer holds a status ("M001 in progress" was there); it points at `STATE.md`, `ROADMAP.md` and `spec/SPEC.md`. `KNOWLEDGE.md` named the CI gate (`ci.yml` and `plugin-check.yml` run `bin/ytstack-check`) where it used to deny one, described gstack as installed instead of vendored and got the glossary entry "Technical spec". `AGENTS.md` got a first paragraph under "Read first" that points at `.ytstack/spec/SPEC.md`, the spec in the artifact list and six gstack wrappers instead of "three planning wrappers". `NOTICE` listed six gstack-backed skills. `docs/concept.md` listed six superpowers wrappers and six gstack wrappers, got the bullet "Technical spec" in the artifact list and a suite count that went from 10 to the real number (15 in the working tree, which includes the M023 suite `ytstack-brief`).

## Deviations from plan

- The plan named three documents to reconcile (`PROJECT.md`, `KNOWLEDGE.md`, `ROADMAP.md`). The area agents found more that contradicted the code, and it was corrected as well: the gstack wrapper count in `AGENTS.md`, `README.md`, `QUICKSTART.md`, `NOTICE` and `docs/concept.md`, and the counts of suites, hooks, skills and eval cases in `README.md`.
- A file rides in one commit. The `ROADMAP.md` frontmatter (23 milestones, M022 current) and the section headings M016 to M019 are committed with S01-T01; the counts in `README.md` and `QUICKSTART.md` with S02-T05.

## Follow-ups

Found by the area agents and not fixed in this milestone. Each needs a decision or a live check.

- `hooks/task-created:95` exits 2 on drift and treats that as a warning that does not block. The host's hook reference says exit 2 on TaskCreated rolls the task creation back.
- `hooks/pre-tool-use-edit:135-139` prints its warning on stderr and exits 0. The host does not show stderr of an exit-0 hook to the model.
- `codex/hooks.json:12` sets `additionalContextLimit: 5000`. The Codex SessionStart injection measures about 13,300 characters.
- `docs/ux/skill-structure.md:289-305` and `docs/ux/askuserquestion-format.md:164-171` describe checks that `bin/ytstack-check` does not perform (`AskUserQuestion` bodies, preamble flags, a 1800-line limit) and name the tool `ytstack-skill-check`.
- `docs/ux/askuserquestion-format.md:121` says `YTSTACK_NON_INTERACTIVE=ask` restores asking. The preambles treat any non-empty value as on.
- `skills/summarize-task/SKILL.md:372` (Granularity note) promises the pattern `^M###-S##:`. `yt_commit_ref_pattern` renders `^M###-S##-:` for an empty task.
- `.ytstack/DECISIONS.md:126-141` (non-interactive mode in every superpowers wrapper) and `:218` (`CLAUDE_PLUGIN_ROOT` in skills) are not what the code does, and no entry supersedes them.
- `vendor/README.md:8` and `:14` still describe a `vendor/gstack/` subtree. Not edited: the file sits under `vendor/`.
- `docs/concept.md:159` says "Eleven skills", and from `:280` on the file describes the retired `ystacks` marketplaces.
- `.ytstack/VENDOR-INVENTORY.md` is a snapshot of 2026-04-24. Its frontmatter (`:3`) and its first paragraph (`:9`) still call gstack a vendored upstream, and `:17` names three gstack wrappers.
- `skills/init-project/SKILL.md:212` (Step 5) uses `$_PITCH_SLUG`, which the preamble never sets.

## Spec

none -- no behaviour or contract changes: the documents now say what the code already did

## Verification

Command: `bash bin/ytstack-spec lint` and the six greps of the plan -- passed at the working tree on top of `f4f54ab` in the local checkout. Lint printed `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`. The greps printed the corrected statements at `PROJECT.md:38`, `KNOWLEDGE.md:7`, `ROADMAP.md:4` and `:6`, `AGENTS.md:56`, `NOTICE:34` and `docs/concept.md:256`.

Not checked: the eleven follow-ups above were read in the files, not reproduced in a live session. The documents under `docs/` were not swept for further stale statements beyond what the area agents reported.
