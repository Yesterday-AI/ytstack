#!/usr/bin/env python3
"""ytstack PR watch: command line, worker tick and Codex/Claude Code hook entrypoint.

State lives in ${YTSTACK_PR_WATCH_HOME:-~/.ytstack/pr-watch}/state. See docs/pr-watch.md.
"""
import argparse
import json
import os
import re
import sys
import subprocess
import time
from pathlib import Path

if sys.version_info < (3, 9):
    sys.exit('ytstack pr-watch needs Python 3.9 or newer')

from prwatch import admin, claude, github
from prwatch.hooks import handle
from prwatch.state import (cli, connect, handover, known_session, qualify_known, register, policy,
                           successor)
from prwatch.worker import tick


# A label that says "do not merge": `do-not-merge`, `DO NOT MERGE`, `do_not_merge/hold`, `status: dnm`.
DO_NOT_MERGE = re.compile(r'\b(?:do not merge|dnm)\b')


def login_key(login):
    """A login as compared: case-insensitive, `dependabot` and `dependabot[bot]` alike."""
    login = login.strip().lower()
    return login[:-len('[bot]')] if login.endswith('[bot]') else login


def skip_reason(pr, authors, drafts, labelled):
    """Why `register --all-open` leaves an open PR alone, or None: another author, a draft,
    a do-not-merge label."""
    author = (pr.get('user') or {}).get('login') or ''
    if login_key(author) not in authors:
        return f'author {author or "unknown"}'
    if pr.get('draft') and not drafts:
        return 'draft'
    names = [' '.join(re.sub(r'[-_/:.]', ' ', (label.get('name') or '').lower()).split())
             for label in pr.get('labels') or []]
    if not labelled and any(DO_NOT_MERGE.search(name) for name in names):
        return 'do-not-merge'
    return None


def origin_repo(cwd):
    """OWNER/REPO of the origin remote of `cwd`, or None (no checkout, no GitHub origin)."""
    from prwatch.hooks import REPO
    p = subprocess.run(['git', '-C', cwd, 'remote', 'get-url', 'origin'], capture_output=True, text=True, timeout=3)
    match = REPO.fullmatch(p.stdout.strip()) if p.returncode == 0 else None
    return match[1] if match else None


def main():
    parser = argparse.ArgumentParser(prog='ytstack-pr-watch', description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    hook = sub.add_parser('hook', help='Hook entrypoint (stdin: hook payload); called by hooks/pr-watch')
    hook.add_argument('--host', choices=('codex', 'claude'), default='codex')
    # Codex exports CODEX_THREAD_ID; Claude Code exports CLAUDE_CODE_SESSION_ID (stored host-qualified).
    default_session = os.environ.get('CODEX_THREAD_ID') or (
        claude.qualify(os.environ['CLAUDE_CODE_SESSION_ID']) if os.environ.get('CLAUDE_CODE_SESSION_ID') else None)
    show = sub.add_parser('status', help='Watches, pending notices and worker health as JSON; by default only '
                                         'the current session and the repository of the working directory')
    show.add_argument('--all', action='store_true', help='every session and repository')
    show.add_argument('--session', default=default_session)
    show.add_argument('--repo')
    poll = sub.add_parser('tick', help='One worker pass: discover, poll GitHub, deliver')
    poll.add_argument('--no-delivery', action='store_true')
    poll.add_argument('--no-discovery', action='store_true')
    add = sub.add_parser('register', help='Watch an open PR (or every open PR of a repository) for a session')
    add.add_argument('--repo', required=True)
    which = add.add_mutually_exclusive_group(required=True)
    which.add_argument('--pr', type=int)
    which.add_argument('--all-open', action='store_true',
                       help='every open PR of --repo by you (gh login), for example the ones subagents opened; '
                            'drafts, do-not-merge labels and PRs another session owns are skipped and named')
    add.add_argument('--author', help='with --all-open: also PRs of these logins (comma-separated)')
    add.add_argument('--include-drafts', action='store_true', help='with --all-open: also draft PRs')
    add.add_argument('--include-labelled', action='store_true',
                     help='with --all-open: also PRs with a do-not-merge label')
    add.add_argument('--session', default=default_session)
    add.add_argument('--cwd', default=os.getcwd())
    create = sub.add_parser('create', help='Create a PR and persist ownership before returning')
    create.add_argument('--repo', required=True)
    create.add_argument('--session', default=default_session)
    create.add_argument('--cwd', default=os.getcwd())
    create.add_argument('gh_args', nargs=argparse.REMAINDER)
    move_to = sub.add_parser('handover', help='Hand every watch of a session to its successor (a rotating '
                                              'coordinator); later registrations for it follow')
    move_to.add_argument('--from', dest='source', required=True, metavar='SESSION')
    move_to.add_argument('--to', dest='session', default=default_session, metavar='SESSION')
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
    if args.command == 'register' and not args.all_open and (args.author or args.include_drafts or args.include_labelled):
        parser.error('--author, --include-drafts and --include-labelled apply to --all-open only')
    # The current Claude session's id given bare would be stored as a Codex thread and never delivered.
    own = os.environ.get('CLAUDE_CODE_SESSION_ID')
    if own and getattr(args, 'session', None) == own:
        args.session = claude.qualify(own)
    if own and getattr(args, 'source', None) == own:
        args.source = claude.qualify(own)
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
            if args.command == 'register' and args.session:
                # A session that was handed over registers for its successor; say so in the output.
                args.session = successor(db, args.session)
            if args.command == 'handover':
                if not args.session:
                    parser.error('--to or CODEX_THREAD_ID required')
                # A bare id is a Codex thread; a bare Claude id (copied from another session)
                # is qualified when only `claude:<id>` is known, and a Claude session's
                # successor is a Claude session too.
                args.source = qualify_known(db, args.source)
                args.session = qualify_known(db, args.session)
                if (args.source.startswith('claude:') and ':' not in args.session
                        and not known_session(db, args.session)):
                    args.session = claude.qualify(args.session)
                if args.source == args.session:
                    parser.error('--from and --to name the same session')
                moved, notices = handover(db, args.source, args.session)
                print(f'{len(moved)} watches handed over from {args.source} to {args.session}'
                      + (': ' + ' '.join(f'{repo}#{number}' for repo, number in moved) if moved else ''))
                print(f'{notices} pending notice{"" if notices == 1 else "s"} moved; '
                      f'later registrations for {args.source} go to {args.session}')
            elif args.command == 'register' and args.all_open:
                if not args.session:
                    parser.error('--session or CODEX_THREAD_ID required')
                # One paginated list call (one REST call per 100 open PRs), one for the login.
                cwd = str(Path(args.cwd).resolve())
                authors = {login_key(a) for a in (args.author or '').split(',') if a.strip()}
                try:
                    authors.add(login_key(github.login()))
                except github.APIError:
                    if not authors:
                        parser.error('could not read your GitHub login (gh api user); check `gh auth status` '
                                     'or name the authors with --author <login>[,<login>]')
                    print('ytstack-pr-watch: could not read your GitHub login (gh api user); '
                          'registering only --author PRs', file=sys.stderr)
                added, kept, foreign, filtered, paused = [], [], [], [], []
                for pr in sorted(github.open_pulls(args.repo), key=lambda p: p['number']):
                    number = pr['number']
                    reason = skip_reason(pr, authors, args.include_drafts, args.include_labelled)
                    if reason:
                        filtered.append(f'#{number} ({reason})')
                        # A watch of this session from an earlier, unfiltered run would keep reporting.
                        if db.execute("UPDATE watches SET paused=1 WHERE repo=? AND number=? AND session=? "
                                      "AND paused=0 AND status!='closed'", (args.repo, number, args.session)).rowcount:
                            paused.append(f'#{number}')
                        continue
                    known = db.execute('SELECT session FROM watches WHERE repo=? AND number=?',
                                       (args.repo, number)).fetchone()
                    try:
                        register(db, args.repo, number, args.session, cwd)
                    except ValueError:
                        # Re-read: the worker may have registered the PR after the lookup above.
                        owner = db.execute('SELECT session FROM watches WHERE repo=? AND number=?',
                                           (args.repo, number)).fetchone()
                        foreign.append(f'#{number} ({owner["session"] if owner else "unknown"})')
                        continue
                    (kept if known else added).append(f'#{number}')
                print(f'{args.repo}: {len(added)} registered to {args.session}, {len(kept)} already watched by it, '
                      f'{len(foreign)} owned by another session, {len(filtered)} skipped by filter')
                if added:
                    print('  registered: ' + ' '.join(added))
                if foreign:
                    print('  skipped (another session owns them; pause or register them there): ' + ' '.join(foreign))
                if filtered:
                    print('  skipped by filter: ' + ' '.join(filtered)
                          + ' (widen with --author, --include-drafts, --include-labelled, or register --pr N)')
                if paused:
                    print('  paused (watched by this session, now skipped by the filter): ' + ' '.join(paused)
                          + f' (undo: {cli()} resume --repo {args.repo} --pr N)')
            elif args.command == 'register':
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
                # Default scope: this session and the repository of the working directory (issue #85).
                scope = {} if args.all else {k: v for k, v in (
                    ('session', args.session), ('repo', args.repo or origin_repo(os.getcwd()))) if v}
                # GitHub owner and repository names are case-insensitive.
                where = ' AND '.join('lower(repo)=lower(?)' if k == 'repo' else f'{k}=?' for k in scope) or '1'
                print(json.dumps(dict(scope=scope or 'all',
                    watches=[dict(r) for r in db.execute(f'SELECT * FROM watches WHERE {where}', tuple(scope.values()))],
                    pending_delivery=[dict(r) for r in db.execute('SELECT event_key,session,attempts,error,retry_at,dispatch_id,turn_id FROM outbox '
                                                                  f'WHERE delivered IS NULL AND cancelled IS NULL AND {where}', tuple(scope.values()))],
                    health={r['key']:r['value'] for r in db.execute('SELECT * FROM meta')}), indent=2))
        db.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
