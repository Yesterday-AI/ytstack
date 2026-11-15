# External plans

A project that ran for a while before ytstack, or beside it, often keeps its plan in `plans/*.md`: tables of work packages, checklists, a board with a "Done" column. `bin/ytstack-frontier` reads only milestones and slices inside `.ytstack/`, so it lists nothing for that work and the lanes get tracked by hand. This document fixes how ytstack finds such a plan, when it offers to map it, and how the mapping is written. `reconcile` and `adopt-brownfield` use it; `bin/ytstack-plans` does the detection.

The external plan is the user's. ytstack reads it and links to it. It never edits, moves, renames or deletes a file in it, and it never ticks a row there.

## What counts

`bin/ytstack-plans scan` looks at these directories, relative to the repository root, and at their `*.md` files up to three levels deep:

`plans/`, `plan/`, `planning/`, `roadmap/`, `docs/plans/`, `docs/plan/`, `docs/planning/`, `docs/roadmap/`

A **work row** is:

- a task-list item: `- [ ] ...`, `- [x] ...` (also `*` and `+`, `[X]`);
- a data row of a Markdown table whose header names a status column (`Status`, `State`, `Done`, `Progress`, `Stand`, `Erledigt`), or whose first data row has a checkbox cell (`[ ]`, `[x]`).

A table without such a column (a comparison, a cost table) is not a plan. Anything inside a fenced code block is skipped.

A row is `done` when its checkbox is ticked or its status cell starts with done, merged, complete(d), shipped, closed, finished, landed, released, erledigt, fertig or a check mark; `dropped` when it starts with dropped, cancel..., superseded, obsolete, wontfix, won't, skipped, abandoned, verworfen, a cross mark or strikethrough; `open` otherwise.

## Thresholds

| Threshold | Value | Why |
|---|---|---|
| Plan file | at least 3 work rows | a README with one checkbox is not a plan |
| Large directory | at least 10 open rows in its plan files (`YTSTACK_PLAN_MIN_OPEN`) | below that, two milestones' worth of slices at most: retyping them through `plan-milestone` costs less than a mapping |

Only a large directory without a recorded answer is offered. `scan` prints one line per directory with plan files and exits 0 only in that case:

```
dir=plans files=23 open=1467 done=462 verdict=large answer=none
```

## The answer is recorded

The question is asked once per directory. The answer goes into `.ytstack/PREFERENCES.md`, one line per directory:

```
external_plans: plans mapped 2026-11-15
external_plans: docs/roadmap declined 2026-11-15
```

`scan` reads these lines and reports `answer=mapped` or `answer=declined`. To be asked again, delete the line. Rows added to the plan after a mapping are not mapped by themselves: delete the line and run `reconcile` again, or plan them with `plan-milestone`.

## The question

One `AskUserQuestion` in the format of `askuserquestion-format.md`, tier `core`. The two skills carry the body; its options are always:

- **A) Map all** -- every plan file with open rows becomes milestones and slices.
- **B) Map the files I name** -- the user names the files; the others are not mapped. The answer is recorded as `mapped` all the same.
- **C) Leave it** -- recorded as `declined`; nothing else is written.

The recommendation is A when at most five plan files hold open rows, B otherwise (name the files with the most open rows: an old plan directory usually holds finished plans whose checklists nobody ticked).

Without a person (`YTSTACK_NON_INTERACTIVE`), the recommendation is taken; for B the agent takes the file with the most open rows and says so.

## The mapping

The agent maps; no script writes the milestones. Which rows form a milestone, a slice or a task depends on how the plan is built, and the rows alone do not say it. `bin/ytstack-plans rows --open <file>` gives every open row with its exact pointer; read the file around those lines before writing.

1. **Milestones.** One milestone per plan file with open rows. A file that would give more than 12 slices becomes one milestone per section (`##` heading) instead. Numbers continue after the highest `M###-*` file in `.ytstack/` (the rule of `plan-milestone`), in the order of the files.
2. **Slices.** When the file has a board (a table whose rows carry an id), each open board row is one slice and the board is the authority: a checklist under a package whose board row is done is not mapped, even with unticked boxes. Without a board, each section with open rows is one slice. A slice holds at most 7 tasks; a section with more open rows is split in order.
3. **Tasks.** The open checklist items of the package or section, one task each, in order. A board row without a checklist gets one task with the row's title.
4. **Done and dropped rows** are not mapped. The milestone's `CONTEXT` counts them and links the file.
5. **Dependencies.** `**Blocked by:**` names a slice only when the row states the dependency (a "Depends on", "Blocked by", "Can start" or "after" cell, or the text) and the row it names is mapped to an open slice of the same milestone. A dependency on a done row is satisfied and left out. A dependency on anything else (another milestone, a gate, a person) goes under the slice's `## Notes`, never into `**Blocked by:**`: the frontier would keep the slice blocked for good.
6. **Status.** Every file is written with `status: planned`. `STATE.md` is not changed: the user decides which milestone is current.

### The pointer back

Every artifact links the row it came from, so the plan stays the source of detail:

- `M###-CONTEXT.md`: under `## Goal` the plan's H1 and first sentence in one line, then `## Source` with the file, the date of the mapping, and the counts: `Mapped from \`plans/2026-10-29-v2-packages.md\` on 2026-11-15: 8 open rows mapped, 2 done and 1 dropped not mapped. The file stays the source of detail; it is not kept in sync.`
- `M###-ROADMAP.md`: one line per slice, `- [ ] S01 -- AV-03 Package 3`.
- `M###-S##-PLAN.md`: directly under the goal, `**Source:** \`plans/2026-10-29-v2-packages.md:9\` (row \`AV-03\`, read 2026-11-15)`; each task line ends with its pointer: `- [ ] T01 -- Write the pass/fail matrix (plans/2026-10-29-v2-packages.md:407)`.

Line numbers move when the plan is edited; the row id and the date keep the pointer findable.

### The templates

The frontmatter and sections are those of `plan-milestone` (CONTEXT, ROADMAP) and `slice-milestone` (slice plan), with these values: `size` from the slice count (1: S, 2-3: M, more: L), `created` the time of the mapping, exit criteria "All mapped slices done; the source rows they point at are done in `<file>`", the slice goal the row's title in one sentence.

### Afterwards

1. A global `ROADMAP.md` with a milestone table gets one row per new milestone with status `planned`.
2. Record the answer in `PREFERENCES.md` (above).
3. Run `bin/ytstack-frontier list --milestone M###` for each new milestone. Every mapped slice is listed, and the ready ones are the open rows that nothing open blocks. A slice that is listed `blocked` names what blocks it; check that it is a mapped row.
4. Say in the report which hand-kept lane list the mapping replaces, if the project has one; it is not edited either.
