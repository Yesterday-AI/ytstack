# Vendor

This directory holds git-subtree mirrors of upstream skill frameworks we cherry-pick from. **Never modify contents of any subtree.** Wrap with a ytstack-namespaced skill instead (see `skills/plan-ceo-review/`, `skills/office-hours/`, etc.).

## Current subtrees

(None yet. Deferred to M008 pre-release.)

Planned:
- `vendor/gstack/` — Garry Tan's ytstack planning framework. Source: determine final URL before M008.
- `vendor/superpowers/` — Jesse Vincent's methodology skills. Source: `https://github.com/obra/superpowers.git`

## Adding a subtree

Requires ytstack to be a git repo. Steps (run from repo root):

```bash
# Add superpowers
git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers.git main --squash

# Add gstack (URL TBD)
git subtree add --prefix=vendor/gstack <gstack-git-url> main --squash
```

## Updating a subtree

```bash
git subtree pull --prefix=vendor/superpowers https://github.com/obra/superpowers.git main --squash
git subtree pull --prefix=vendor/gstack <gstack-git-url> main --squash
```

Run `./scripts/sync-upstream.sh` (ships M008) to automate both.

## Rules

1. **Read-only.** Do not edit any file in `vendor/**`. Changes will drift on next pull. Also: upstream maintainers may explicitly reject forks (see superpowers' CLAUDE.md). Wrap, don't edit.
2. **Licensing.** Each subtree's LICENSE applies. Our NOTICE file (M008) lists per-subtree attribution.
3. **Commit squash.** Use `--squash` to keep our git log clean. If we ever need to push back upstream (contributing a fix), we'd use a separate worktree without squash.
