---
milestone: M031
slice: S02
task: T03
project: ytstack
closed: 2026-11-15T00:25:00Z
verification: passed
---

# M031-S02-T03 -- Summary

## Commits

- The commit that carries this file (`M031-S02-T03: post the review records on the pull request in finish-lane and code-review`).

## Outcome

`finish-lane` (0.4.0) wrote the round line first and put it last into the body of the review it posts on `{SHA}`; the plan got the same line only where the session may write, never through a commit on the lane's branch. Step 8 posted the lens lines as one more review whose first line is the verdict the gate of Step 10 matches, Step 9 ran `route --pr {N}` (without `--pr` on another host) and the report names the `round:` source. `code-review` (0.5.0) posted its round and lens lines on the branch's open pull request when its head is the reviewed commit, and gained `Write` for the body file.

The spec areas `checks-and-evals` (`verified_at: aa66c09`) and `skills` named `--pr` and the posted records; `docs/concept.md` named the host record. DECISIONS gained "2026-11-15: The risk route reads the review round from the review on the host first; the plan is the fallback", referenced from both area files.

## Deviations from plan

- The lens review carries a `Verdict:` first line. Found while editing: `gates --verdict-pattern '^Verdict: approved'` matches the newest review on the head, and a lens review posted after the round review would otherwise fail that gate.
- `code-review` gained `Write` in `allowed-tools`: it now writes a review body file.
- A DECISIONS entry was added (trust rule: only reviews by owners, members and collaborators count).

## Follow-ups

- QUICKSTART "Who merges: the risk route" does not mention `--pr` yet: S04 writes the factory-tools setup and should name it.
- S01 (`coordinate`, risk route before every merge) should call `ytstack-risk route --pr <n>` (or `finish-lane route --pr`).

## Spec

- checks-and-evals: Behavior updated, `verified_at` set to aa66c09
- skills: Behavior and decisions updated

## Verification

`bin/ytstack-check` -- exit 2, no `[fail]`, `OK (with 9 warning[s])`. `bash bin/ytstack-spec lint` -- `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`. `bash bin/ytstack-spec drift` -- `spec drift: no area to look at`. `bash tests/run-all.sh` -- exit 0, `ALL SUITES PASSED` (ytstack-risk 197, ytstack-finish-lane 183). Local checkout, macOS, bash 3.2.57.
