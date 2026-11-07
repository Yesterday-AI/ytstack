---
name: document-release
metadata:
  tier: task
  version: 0.1.0
description: "Writes the release documentation for a version bump (CHANGELOG section, release notes) through the installed gstack document-release skill, fed with the task summaries since the last tag. Use when a version is being cut, after ship or finish-branch landed the work, or when the user says write the changelog, release notes, document the release. Not for ad-hoc docs edits (quick-task) and not for the retrospective (retro)."
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# ytstack:document-release

Thin wrapper around the **installed** gstack `document-release` skill (`~/.claude/skills/gstack/document-release`, ytstack tested against v1.96.0.0). Checks the install, collects what shipped since the last tag from ytstack's summaries, and invokes the gstack skill through the Skill tool. gstack is the single source of truth for the procedure; ytstack owns the precheck and the input.

## ytstack context (resolved at render time)

```!
# ytstack resolver (M016): checkout = where this shell runs, via the shared lib.
_LIB="${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh"
if [ -f "$_LIB" ]; then
  . "$_LIB"; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null
  _PROJECT_DIR="$YT_TOPLEVEL"; _YT_DIR="$YT_DIR"; _YT_SCOPE="$YT_SCOPE"; _IS_GIT="$YT_IS_GIT"; _PROJECT_KEY="$YT_REPO_KEY"
else
  # Host did not substitute CLAUDE_SKILL_DIR (e.g. Codex adapter): project scope only.
  _IS_GIT=$([ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] && echo yes || echo no)
  _PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  _YT_DIR=""; _YT_SCOPE=none; _PROJECT_KEY=""
  [ -d "$_PROJECT_DIR/.ytstack" ] && { _YT_DIR="$_PROJECT_DIR/.ytstack"; _YT_SCOPE=project; }
fi
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$_PROJECT_DIR")
# gstack precheck (M017): installed dependency, not vendored
if command -v yt_gstack_ctx >/dev/null 2>&1; then
  yt_gstack_ctx >/dev/null
  echo "GSTACK_AVAILABLE: $YT_GSTACK_AVAILABLE"; echo "GSTACK_DIR: $YT_GSTACK_DIR"; echo "GSTACK_VERSION: ${YT_GSTACK_VERSION:-none}"
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok document-release)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
_LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo none)
_COMMITS_SINCE=0; _SUMMARIES_SINCE=""
if [ "$_LAST_TAG" != none ]; then
  _COMMITS_SINCE=$(git rev-list --count "$_LAST_TAG"..HEAD 2>/dev/null || echo 0)
  [ -n "$_YT_DIR" ] && _SUMMARIES_SINCE=$(git diff --name-only --diff-filter=A "$_LAST_TAG"..HEAD -- "$_YT_DIR" 2>/dev/null | grep -- '-SUMMARY.md$' | grep -c .)
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "IS_GIT: $_IS_GIT"
echo "LAST_TAG: $_LAST_TAG"
echo "COMMITS_SINCE_TAG: $_COMMITS_SINCE"
echo "SUMMARIES_SINCE_TAG: ${_SUMMARIES_SINCE:-0}"
echo "CHANGELOG: $([ -f CHANGELOG.md ] && echo CHANGELOG.md || echo none)"
```

## ytstack invocation notes

document-release turns what shipped since `LAST_TAG` into release documentation. The material is the task summaries added since the tag (`SUMMARIES_SINCE_TAG`, each with Outcome + Deviations) plus the commit log; the installed gstack `document-release` skill writes the changelog section and release notes; ytstack hands it the material and keeps `CHANGELOG.md` as the target when it exists.

HARD-GATE: `IS_GIT=no`: stop. `LAST_TAG=none` and `COMMITS_SINCE_TAG=0`: stop with "nothing to document". Without summaries, fall back to the commit log and say so.

Give the gstack skill the version being cut (ask once if it is not in the prompt), the summaries' Outcome paragraphs grouped by milestone, and the existing CHANGELOG format (Keep a Changelog sections when present). Do not bump manifest versions here; that is the release task's job.

## Terminal State

Report the CHANGELOG section written and the release-notes path. Suggest `ytstack:ship` when the release branch still needs a PR, or the project's tag step. Do NOT auto-invoke any downstream skill.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `document-release` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored (DECISIONS 2026-11-07 "Vendor strategy").

- If `GSTACK_AVAILABLE` is `no` (or `unknown`) or `GSTACK_SKILL_OK` is `no`: stop. Tell the user that `ytstack:document-release` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise release notes from memory.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `document-release` (the installed gstack skill, not `ytstack:document-release`), with the version, summaries and changelog format as its input. Follow it to completion.
2. Apply the ytstack notes above (CHANGELOG target, no manifest bump).
3. Report per the Terminal State. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver + gstack precheck + since-tag material
2. **HARD-GATE** -- stop with the install command when gstack is missing; stop with nothing to document
3. **Collect material** -- summaries since the tag, commit log, version
4. **Invoke installed `document-release`** via the Skill tool and follow it to completion
5. **Report + return** -- CHANGELOG section + release notes path, no auto-chaining
