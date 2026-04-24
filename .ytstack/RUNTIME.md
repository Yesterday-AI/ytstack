# Runtime

Services, APIs, env vars, and ports used by ytstack.

## Services

None yet. ytstack is a Claude Code plugin -- no external services of its own.

Runtime dependencies (at user install time):

- **Claude Code** v2.1.32+ (for Agent Teams support, see M006)
- **git** (for subtree-based vendor management)
- **bash** (for hook scripts)

## Environment variables

Variables that ytstack reads:

| Variable | Purpose | Default |
|---|---|---|
| `YTSTACK_NON_INTERACTIVE` | Skip `AskUserQuestion`, auto-pick recommended options | unset |
| `YTSTACK_HOME` | Override `~/.ytstack/` location | `$HOME/.ytstack` |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Must be `1` for Agent-Teams features (M006) | unset |
| `OPENCLAW_SESSION` | Detected to enable non-interactive mode | unset |
| `CLAUDE_AGENT_TEAM_MEMBER` | Detected to enable non-interactive mode | unset |

## Ports

None. ytstack is file-based.

## Deploy target

Distribution via Claude Code plugin marketplace (M008):

- Repo: `github.com/Yesterday-AI/ytstack` (plugin source + self-marketplace)
- Marketplace manifest: `.claude-plugin/marketplace.json` inside the plugin repo (no separate `-marketplace` repo -- see DECISIONS 2026-04-24)
- Install: `/plugin marketplace add Yesterday-AI/ytstack && /plugin install ytstack@ytstack-marketplace`

No CI runtime, no hosted service. Pure git-distributed.
