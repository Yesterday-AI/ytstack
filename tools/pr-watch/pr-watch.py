#!/usr/bin/env python3
"""ytstack PR watch: command line, worker tick and Codex/Claude Code hook entrypoint.

State lives in ${YTSTACK_PR_WATCH_HOME:-~/.ytstack/pr-watch}/state. See docs/pr-watch.md.
"""
import argparse
import json
import os
import sys
import subprocess
import time
from pathlib import Path

if sys.version_info < (3, 9):
    sys.exit('ytstack pr-watch needs Python 3.9 or newer')

from prwatch import admin, claude, github
from prwatch.hooks import handle
from prwatch.state import cli, connect, register, policy
from prwatch.worker import tick


def main():
    parser = argparse.ArgumentParser(prog='ytstack-pr-watch', description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    hook = sub.add_parser('hook', help='Hook entrypoint (stdin: hook payload); called by hooks/pr-watch')
    hook.add_argument('--host', choices=('codex', 'claude'), default='codex')
    sub.add_parser('status', help='Watches, pending notices and worker health as JSON')
    poll = sub.add_parser('tick', help='One worker pass: discover, poll GitHub, deliver')
    poll.add_argument('--no-delivery', action='store_true')
    poll.add_argument('--no-discovery', action='store_true')
    # Codex exports CODEX_THREAD_ID; Claude Code exports CLAUDE_CODE_SESSION_ID (stored host-qualified).
    default_session = os.environ.get('CODEX_THREAD_ID') or (
        claude.qualify(os.environ['CLAUDE_CODE_SESSION_ID']) if os.environ.get('CLAUDE_CODE_SESSION_ID') else None)
    add = sub.add_parser('register', help='Watch an open PR for a session')
    add.add_argument('--repo', required=True)
    add.add_argument('--pr', required=True, type=int)
    add.add_argument('--session', default=default_session)
    add.add_argument('--cwd', default=os.getcwd())
    create = sub.add_parser('create', help='Create a PR and persist ownership before returning')
    create.add_argument('--repo', required=True)
    create.add_argument('--session', default=default_session)
    create.add_argument('--cwd', default=os.getcwd())
    create.add_argument('gh_args', nargs=argparse.REMAINDER)
    for command in ('pause', 'resume'):
        p = sub.add_parser(command, help=f'{command.capitalize()} notices for a watched PR')
        p.add_argument('--repo', required=True)
        p.add_argument('--pr', type=int, required=True)
    inspect = sub.add_parser('inspect', help='Read-only readiness of a PR; no registration, no delivery')
    inspect.add_argument('--repo', required=True)
    inspect.add_argument('--pr', required=True, type=int)
    sub.add_parser('enable', help='Set pr_watch=on in ~/.ytstack/config (the hooks run)')
    sub.add_parser('disable', help='Remove pr_watch=on from ~/.ytstack/config (the hooks exit at once)')
    for command, text in (('install-worker', 'Install the 60-second background worker (macOS launchd)'),
                          ('uninstall-worker', 'Remove the background worker; state stays')):
        p = sub.add_parser(command, help=text + '; prints the plan without --yes')
        p.add_argument('--yes', action='store_true')
    move = sub.add_parser('migrate', help='Copy state and policy of an existing local install; prints the plan without --yes')
    move.add_argument('--from', dest='source', required=True, metavar='DIR')
    move.add_argument('--yes', action='store_true')
    args = parser.parse_args()
    if args.command == 'hook':
        try:
            result = handle(json.load(sys.stdin), args.host)
            # Nothing to say: no output at all, so a quiet hook costs the host nothing.
            if result:
                print(json.dumps(result))
        except Exception as exc:
            # Hook failures stay visible without exposing captured tool arguments.
            # Nothing on stdout: the hook wrapper fails open.
            print(f'PR watch hook failed: {type(exc).__name__}. Run {cli()} status.', file=sys.stderr)
            return 1
    elif args.command in ('enable', 'disable'):
        return admin.set_enabled(args.command == 'enable')
    elif args.command == 'install-worker':
        return admin.install_worker(args.yes)
    elif args.command == 'uninstall-worker':
        return admin.uninstall_worker(args.yes)
    elif args.command == 'migrate':
        return admin.migrate(args.source, args.yes)
    elif args.command == 'tick':
        tick(not args.no_delivery, not args.no_discovery)
    elif args.command == 'create':
        from prwatch.hooks import git_binding, PR
        if not args.session:
            parser.error('--session or CODEX_THREAD_ID required')
        binding = git_binding(args.cwd)
        if not binding or binding[0] != args.repo:
            parser.error('Use a dedicated branch/worktree with origin matching --repo')
        db = connect()
        with db:
            db.execute('INSERT OR IGNORE INTO bindings VALUES(?,?,?,?,?,?)',
                       (*binding, args.session, args.cwd, time.time(), time.time()))
        db.close()
        forwarded = args.gh_args[1:] if args.gh_args[:1] == ['--'] else args.gh_args
        if any(a in ('-R','--repo','-H','--head') or a.startswith(('--repo=','--head=')) for a in forwarded):
            parser.error('Use --repo before the separator and create from the current worktree branch')
        result = subprocess.run(['gh','pr','create','--repo',args.repo,*forwarded], cwd=args.cwd, text=True, capture_output=True)
        if result.returncode:
            print(f'gh pr create failed; inspect GitHub and {cli()} status before retrying.', file=sys.stderr)
            return result.returncode
        urls = [(repo,int(number)) for repo,number in PR.findall(result.stdout) if repo == args.repo]
        if len(urls) != 1:
            raise RuntimeError('PR creation returned no unique URL; reconciliation will retry discovery')
        repo, number = urls[0]
        github.api(f'repos/{repo}/pulls/{number}')
        db = connect()
        with db:
            register(db, repo, number, args.session, args.cwd)
        db.close()
        print(f'https://github.com/{repo}/pull/{number} (monitor registered)')
    elif args.command == 'inspect':
        from prwatch.evaluate import evaluate
        status, detail, events = evaluate(github.snapshot(args.repo, args.pr), policy(args.repo))
        print(json.dumps(dict(status=status, detail=detail, bot_events=len(events)), indent=2))
    else:
        db = connect()
        with db:
            if args.command == 'register':
                if not args.session:
                    parser.error('--session or CODEX_THREAD_ID required')
                pr = github.api(f'repos/{args.repo}/pulls/{args.pr}')
                if pr['state'] != 'open':
                    parser.error('Only open PRs can be registered')
                register(db, args.repo, args.pr, args.session, str(Path(args.cwd).resolve()))
                print('Registered', pr['html_url'], 'to', args.session)
            elif args.command in ('pause', 'resume'):
                cursor = db.execute('UPDATE watches SET paused=? WHERE repo=? AND number=?',
                                    (int(args.command == 'pause'), args.repo, args.pr))
                if not cursor.rowcount:
                    parser.error('Unknown PR')
            elif args.command == 'status':
                print(json.dumps(dict(watches=[dict(r) for r in db.execute('SELECT * FROM watches')],
                    pending_delivery=[dict(r) for r in db.execute('SELECT event_key,session,attempts,error,retry_at,dispatch_id,turn_id FROM outbox WHERE delivered IS NULL AND cancelled IS NULL')],
                    health={r['key']:r['value'] for r in db.execute('SELECT * FROM meta')}), indent=2))
        db.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
