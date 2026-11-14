# ship: PR title, body and publication

Read this from Procedure step 15, after the push succeeded.

## 1. Look up the PR

```bash
gh pr list --head "<branch>" --state open --json number,title,url,isDraft
```

GitLab: `glab mr list --source-branch "<branch>"`. An empty list means a new PR. Exactly one match is the existing PR. A failed lookup or more than one match: STOP and report; never treat it as "no PR".

## 2. Title

- New PR with a version bump: `v<NEW_VERSION> <type>: <summary>`; `<summary>` says in everyday words what changed for someone using the project and names what the user gets, not the mechanism. No tracker code and none of the repository's coined terms before the trailing group; an issue or slice code goes last, in parentheses.
- Existing PR: keep its wording, replace or add the `v<version> ` prefix.
- No version bump (no version source or version kept): `<type>: <summary>` without prefix.
- `<type>` follows the repo's convention (`feat`, `fix`, `chore`, `docs`, `refactor`). In a ytstack project a slice PR may lead with the slice: `v0.5.1 feat: <summary> (M004-S02)`.

Check the title starts with `v<NEW_VERSION> ` whenever a version was bumped.

## 3. Body

Write the body with the Write tool into a file outside the repo (`mktemp "${TMPDIR:-/tmp}/ship-pr-body.XXXXXX"`); never pass body text inline in a shell command. Compose fresh every run; never reuse an earlier body. The front is for people, the end is for machines: the body opens with one or two plain sentences, no heading above them, saying what changed for someone using the project and which goal from the project's README it serves (with no stated goals, the user-visible benefit). Tracker codes and other machine-read lines never go above them. Sections in this order, omitting a section only where it says so:

```
<One or two plain sentences: what changed for a user, and the README goal it serves.>

## Summary
<Open with the problem in the user's words (what they hit, saw or asked), then the fix and
what they get now. Themes from `git log origin/<base>..HEAD --oneline`, minus VERSION /
CHANGELOG bookkeeping. Never an inventory or a commit list.
BAD: "Adds lint step, wires steps 13 and 19, refreshes goldens."
GOOD: "Nobody re-reads a CHANGELOG entry, so filler words shipped every release. Ship now
lints the entry before the commit and names each line to rewrite.">

## Slice  (only when HAS_YTSTACK is yes and a slice plan exists)
<Slice goal from M###-S##-PLAN.md `**Goal:**`, then one bullet per task:
"T01 -- <Outcome paragraph from M###-S##-T01-SUMMARY.md, condensed to one or two lines>".
Name the .ytstack files this PR carries (summaries, STATE.md, DECISIONS.md entries).>

## Blast radius
<One or two sentences: what else the change touches (callers, consumers, generated files,
hosts) and the one fact that makes that safe, with how you know it (file:line read, failure
path walked, script ran, repro).>

## Test Coverage
<Step 5's diagram, or "All new code paths have test coverage.">
<Tests: {before} -> {after} (+{delta} new)>
<Coverage: {X}% value-weighted ({Y}% any test); coverage gate result and any accepted risk>
<Weak paths and remaining gaps as proposed tests with value cards; each regression proof line>
<One line per suite run: "Tests ran: <label> N" or "Tests ran: <label> count unavailable">

## Pre-Landing Review
<Step 7's summary line and findings, or "No issues found.">
<Gate edits: line verbatim; each kept gate finding's path and reason; each open one's path>
<Adversarial review: verdict, or unavailable with reason (never "passed")>
<Skipped and deferred findings, each with file:line and one line>

## Scope Drift  (omit when the scope check did not run)
<Scope Check line and its lists>

## Plan Completion
<Step 6's checklist summary, or the "not run" line verbatim; deferred and dropped items;
each [ACCEPTANCE_EDITED] item with original and new wording; manual confirmations with the
user's evidence>

## Verification Results  (omit when there were no plan checks)
<Plan and task verification commands: N PASS, M FAIL, K BLOCKED, J NOT RUN, with the
observed lines. Unavailable is never PASS.>

## Follow-ups  (omit when none)
<TODOS.md items added or completed in step 10, or the follow-ups list when there is no
TODOS.md; known pre-existing failures>

## Documentation
<Step 11's documentation_section unchanged, plus the status line (updated / current /
blocked with the user's accepted risk, word for word). Never omitted.>

## Test plan
- [x] `<each suite command run in step 13>`: <observed passing summary>
- [x] `<each task verification command>`: <observed result>
```

End with the host's pull-request attribution line when the session defines one.

A body section for a step that did not run says so ("Coverage audit: skipped (test-only diff)"); it never implies a pass.

## 4. Secret check on the body

```bash
grep -nE 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[abpors]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}' "<body-file>" && echo "SECRET_HIT" || echo "SECRET_CLEAN"
```

`SECRET_HIT`: STOP publication. A PR body on a public repo is world-readable. Redact at the source (and rotate the credential if it was ever pushed), write a fresh body file, check again.

## 5. Publish

**Existing open PR:**

```bash
gh pr edit <number> --title "<title>" --body-file "<body-file>"
```

Then read it back (`gh pr view <number> --json title,url`) and confirm the title. A draft PR stays a draft while a gate finding is open or an UNVERIFIABLE plan item is unconfirmed; otherwise, if this run opened it as a draft only for those reasons and they are resolved, `gh pr ready <number>`.

**No open PR:**

```bash
gh pr create --base "<base>" --head "<branch>" --title "<title>" --body-file "<body-file>"
```

Add `--draft` when a gate finding is `open`, an UNVERIFIABLE plan item is unconfirmed, or the user asked for a draft. GitLab: `glab mr create --source-branch "<branch>" --target-branch "<base>" --title "<title>" --description "$(cat "<body-file>")"`.

**Failure:** `gh` / `glab` missing, unauthenticated or erroring: print the error, the branch, the remote URL and the exact command to run by hand. The code is pushed, so do not undo anything, but never report a PR that was not created.

Remove the body file after a successful post. Print the PR URL.

Never merge. Never enable auto-merge. A merge needs the user's explicit instruction; `ytstack:finish-branch` is the local-merge path.
