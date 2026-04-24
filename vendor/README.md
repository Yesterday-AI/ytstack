# Vendor

This directory holds git-subtree mirrors of upstream skill frameworks we cherry-pick from. **Never modify contents of any subtree.** Wrap with a ytstack-namespaced skill instead (see `skills/plan-ceo-review/`, `skills/office-hours/`, `skills/test-driven-development/`, etc.).

## Current subtrees

- **`vendor/superpowers/`** — Jesse Vincent's methodology skills. Source: `https://github.com/obra/superpowers`. License: MIT (`vendor/superpowers/LICENSE`). Wrapped by: `skills/test-driven-development/`, `skills/systematic-debugging/`, `skills/verification-before-completion/`.
- **`vendor/gstack/`** — Garry Tan's builder toolkit. Source: `https://github.com/garrytan/gstack`. License: MIT (`vendor/gstack/LICENSE`). Wrapped by: `skills/plan-ceo-review/`, `skills/office-hours/`, `skills/plan-eng-review/`.

## Updating a subtree

```bash
git subtree pull --prefix=vendor/superpowers https://github.com/obra/superpowers.git main --squash
git subtree pull --prefix=vendor/gstack https://github.com/garrytan/gstack.git main --squash
```

Run `./scripts/sync-upstream.sh` (ships M008) to automate both.

## Adding a new subtree

1. Verify the license is compatible (MIT / Apache-2.0 / similar permissive).
2. Add via:
   ```bash
   git subtree add --prefix=vendor/<name> <url> <branch> --squash
   ```
3. Update this README with the new subtree entry.
4. Add attribution to `NOTICE` at repo root.
5. Write wrapper skill(s) at `skills/<name>/` that delegate to `vendor/<name>/...`.

## Rules

1. **Read-only.** Do not edit any file in `vendor/**`. Changes drift on next pull. Also: upstream maintainers may explicitly reject forks (see `vendor/superpowers/CLAUDE.md`). Wrap, don't edit.
2. **Licensing.** Each subtree's LICENSE applies. `NOTICE` at repo root lists per-subtree attribution.
3. **Commit squash.** Use `--squash` to keep our git log clean. If we ever need to push back upstream (contributing a fix), we'd use a separate worktree without squash.
