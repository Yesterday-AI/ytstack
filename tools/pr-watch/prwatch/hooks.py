"""Capture session/worktree provenance locally, without GitHub calls in tool hooks."""
import json
import re
import shlex
import subprocess
import time
from pathlib import Path
from . import claude
from .state import cli, connect

REPO = re.compile(r'^(?:https://github\.com/|git@github\.com:)([\w.-]+/[\w.-]+?)(?:\.git)?/?$')
PR = re.compile(r'https://github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)\b')


def locations(payload):
    args = payload.get('tool_input') or {}
    if not isinstance(args, dict):
        args = {}
    cwd = args.get('workdir') or args.get('cwd') or payload.get('cwd')
    if not cwd:
        return []
    paths = {str(Path(cwd).resolve())}
    # Resolve common shell directory selectors. Do not evaluate shell text.
    try:
        words = shlex.split(args.get('command', args.get('cmd', '')))
    except ValueError:
        words = []
    for i, word in enumerate(words[:-1]):
        if word == 'cd' or (word == '-C' and i > 0 and words[i-1] == 'git'):
            path = Path(words[i+1]).expanduser()
            paths.add(str((path if path.is_absolute() else Path(cwd) / path).resolve()))
    return sorted(paths)


def git_binding(cwd):
    def git(*args):
        p = subprocess.run(['git', '-C', cwd, *args], capture_output=True, text=True, timeout=3)
        return p.stdout.strip() if p.returncode == 0 else ''
    remote, branch = git('remote', 'get-url', 'origin'), git('branch', '--show-current')
    match = REPO.fullmatch(remote)
    # Shared base branches cannot identify an agent's PR ownership.
    if not match or not branch or branch in ('main', 'master', 'develop'):
        return None
    return match[1], branch


def handle(payload, host='codex'):
    session = payload.get('session_id')
    if not session:
        raise ValueError('Hook lacks session_id')
    if host == 'claude':
        session = claude.qualify(session)
    event = payload.get('hook_event_name')
    if event == 'Stop':
        return {}
    if event == 'UserPromptSubmit':
        # Pull delivery for Claude: local state only, never GitHub.
        db = connect()
        try:
            text = claude.surface(db, session)
        finally:
            db.close()
        return {'hookSpecificOutput': {'hookEventName': event, 'additionalContext': text}} if text else {}
    bindings = [(cwd, git_binding(cwd)) for cwd in locations(payload)]
    db = connect()
    now = time.time()
    with db:
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', ('last_hook', str(now)))
        for cwd, binding in bindings:
            if binding:
                db.execute('''INSERT INTO bindings VALUES(?,?,?,?,?,?) ON CONFLICT(repo,branch,session)
                              DO UPDATE SET touched=excluded.touched,cwd=excluded.cwd''',
                           (*binding, session, cwd, now, now))
        args = payload.get('tool_input') or {}
        # Match the raw strings: in json.dumps a command on a new line reads "\\ngh pr create",
        # where \b never matches between the escaped "n" and "gh".
        text = '\n'.join(str(v) for v in args.values()) if isinstance(args, dict) else json.dumps(args)
        tool = payload.get('tool_name', '')
        # Explicit create output gives provenance even for -R/--head and MCP paths.
        create = bool(re.search(r'\bgh\s+(?:[^;&|]*\s)?pr\s+create\b', text)) or 'create_pull_request' in tool
        if event == 'PostToolUse' and create:
            for repo, number in PR.findall(json.dumps(payload.get('tool_response', ''))):
                db.execute('INSERT OR IGNORE INTO candidates VALUES(?,?,?,?,?)',
                           (repo, int(number), session, payload.get('cwd', ''), now - 300))
    db.close()
    if event == 'SessionStart':
        command = cli()
        return {'hookSpecificOutput': {'hookEventName': event, 'additionalContext':
            f'PR Watch monitors registered GitHub PRs independently. This session is {session}. Use dedicated worktrees. '
            f'Prefer {command} create --repo OWNER/REPO --session SESSION_ID --cwd WORKTREE -- <gh pr create options>; '
            'it persists ownership before returning. '
            'For PR creation outside shell/MCP hooks, register explicitly with '
            f'{command} register --repo OWNER/REPO --pr NUMBER --session SESSION_ID --cwd WORKTREE. '
            f'Run {command} status to see ownership, delivery failures and missing review evidence. '
            'Monitoring does not authorize merging or bypass repository approval rules.'
            + (' Claude sessions are never woken: PR status and actionable notices (red CI, unresolved bot thread, '
               'merge conflict) arrive with the next user prompt, so no own watcher, Monitor or background poll is '
               'needed for a registered PR.' if claude.is_claude(session) else '')}}
    return {}
