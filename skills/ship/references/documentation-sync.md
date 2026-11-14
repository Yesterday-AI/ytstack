# ship: documentation sync

Read this from Procedure step 11. Every ship runs this audit, including docs-only changes and branches that were pushed before. "No edits needed" is an executed audit with result `current`, never a skip.

The audit runs in a fresh-context subagent (it reads the docs against the diff without the bias of the session that wrote the code). You validate what it did. For a full standalone pass after merge (release notes, cross-doc narrative, the doc debt backlog), the user runs `ytstack:document-release`; this step is the narrowed pre-push form.

**Attempt budget:** one audit plus at most one repair re-audit. Never a third.

## Prepare

1. Note the current state so you can check what the child changed: `git status --porcelain > "$(mktemp)"` and `git diff --stat` (print both; keep the temp file path).
2. Discover the doc roots: `README*`, `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING*`, `ARCHITECTURE*`, `docs/**`, nested `README.md` next to changed code, `.ytstack/PROJECT.md` and `.ytstack/KNOWLEDGE.md` when `HAS_YTSTACK` is `yes`. `CHANGELOG.md`, `VERSION`, manifests and `TODOS.md` are not doc roots here (steps 8-10 own them).

## Dispatch

Agent tool, `subagent_type: "general-purpose"`, `run_in_background: false`.

````text
You are the documentation audit of a ship run. Branch: <branch>. Base: <base>.
Diff: `git diff origin/<base>` plus `git diff --cached`, plus these untracked files: <list>.
Doc roots: <list>.

1. Classify the change: new features (new files, commands, skills, flags, endpoints,
   env vars, config keys), changed behaviour, removed functionality, infrastructure.
2. Build a coverage map: for each new or changed public surface item, is there
   reference (README tables, CLAUDE.md / AGENTS.md lists, API docs), how-to, tutorial and
   explanation coverage? Zero coverage = critical gap; reference-only = common gap.
3. Check ASCII and Mermaid diagrams in the doc roots for entities the diff renamed, split,
   removed or moved.
4. Read each relevant doc file in full before editing it. Make factual updates directly:
   paths, counts, command names, flags, version numbers in prose, table rows, stale
   cross-references, cross-doc factual contradictions.
5. Do NOT: touch git (no add, commit, stash, checkout), edit CHANGELOG.md, VERSION,
   package manifests, lockfiles or TODOS.md, run generators, delete content, or rewrite
   narrative, philosophy, security guidance or large sections. Those are blockers to
   report, not edits to make. Do not generate missing doc pages; report them as gaps.
   Preserve existing user content. Do not ask the user anything.

Return a short report, then on the LAST line, nothing after it, one JSON object:
{"status":"updated|current|blocked","files_updated":["path"],"files_reviewed":["path"],"blockers":["..."],"documentation_section":"<markdown: scope audited, what changed, doc debt (gaps from the coverage map)>"}
status is `updated` when you edited, `current` when nothing needed editing, `blocked` when
the audit could not finish or a needed change is a blocker. documentation_section is the
complete section itself, never a placeholder. Spell every key exactly as listed; no extra fields.
````

## Validate (parent)

1. Parse the LAST nonempty line as JSON. Missing or misspelled key, wrong type, placeholder section or no result after about 10 minutes: blocked. Never default or reconstruct a missing value.
2. Compare `git status --porcelain` with the saved state. The only new or changed paths must be exactly `files_updated`, all inside the doc roots. HEAD and the index must be unchanged. Any other write (a manifest, CHANGELOG, a source file, a commit) is an ownership violation: report it, and revert only the child's hunks with Edit after confirming the child has stopped. Never reset or clean the tree.
3. Read every edited hunk. A factual correction from the diff stays. A narrative rewrite, removal or uncertain claim is reverted with Edit and listed as a blocker.
4. Print `Documentation: updated (<paths>)` or `Documentation: current (<scope>)`. Keep `documentation_section` unchanged for the PR body's `## Documentation`.

## Blocked recovery

`blocked`, a failed check or a reverted edit: report `Documentation: blocked` with the reason and the paths. If the one repair attempt is still unused and a concrete fix exists (a missing input, a narrower brief, or a malformed result: end the retry brief with a note naming each bad key), fix it and dispatch once more. Otherwise ask:

> Shipping branch `{BRANCH}` of `{PROJECT_SLUG}`: the documentation audit is blocked: {reason, paths}.
>
> Simplify: the docs may now describe the code wrongly (a renamed command, a stale path). Readers of the PR and the next session will trust them.
>
> RECOMMENDATION: Choose A because a stale doc costs every later reader, and the fix is usually one paragraph.
>
> A) Stop the ship so the docs get fixed first
>    Completeness: 10/10, effort: human: ~5 min / CC: ~5 min, tier: task
> B) Ship with the named documentation risk; the PR body states it word for word
>    Completeness: 5/10 (shortcut), effort: human: 0 / CC: 0, tier: task

Only an actual user answer accepts B; `YTSTACK_NON_INTERACTIVE: true` takes A (there is no owner to accept the risk) and stops. Ownership violations and unexplained git changes cannot be waived.

Approved doc edits are staged by the parent in step 12 together with the rest of the change.
