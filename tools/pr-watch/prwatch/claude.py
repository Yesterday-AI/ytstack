"""Claude Code adapter: pull delivery through the UserPromptSubmit hook.

Claude sessions are stored host-qualified (`claude:<session_id>`). The worker
never pushes to them; instead every user prompt surfaces the session's pending
actionable notices (CI failure, unresolved bot thread, merge conflict, an
observed merge) and a
one-line readiness summary per watched PR, read from the last worker tick.
Hooks make no GitHub calls, so the evidence is at most one tick old and the
agent re-fetches before acting.
"""
import json
import time
import uuid

PREFIX = 'claude:'


def qualify(session):
    return session if session.startswith(PREFIX) else PREFIX + session


def surface_key(session):
    return f'surface:{session}'


def is_claude(session):
    return bool(session) and session.startswith(PREFIX)


def _age(seconds):
    seconds = int(max(0, seconds))
    return f'{seconds}s' if seconds < 120 else f'{seconds // 60}min'


def surface(db, session, now=None):
    """Return the additionalContext text for this session, or None when it owns no open watch."""
    now = now or time.time()
    watches = db.execute("SELECT * FROM watches WHERE session=? AND status!='closed' ORDER BY repo, number",
                         (session,)).fetchall()
    notices = db.execute('''SELECT o.* FROM outbox o JOIN watches w
        ON w.repo=o.repo AND w.number=o.number AND w.session=o.session
        WHERE o.session=? AND o.delivered IS NULL AND o.cancelled IS NULL AND w.paused=0
        ORDER BY o.created''', (session,)).fetchall()
    if not watches and not notices:
        return None
    lines = ['PR Watch (silent background monitor; evidence from the last worker tick, re-fetch before acting):']
    state = []
    for w in watches:
        detail = json.loads(w['detail'] or '[]')
        paused = ' [paused]' if w['paused'] else ''
        pushed = w['pushed_at'] if 'pushed_at' in w.keys() else None
        if pushed and pushed > (w['updated'] or 0):
            # The old head's findings would mislead: the session pushed since the last read.
            state.append((w['repo'], w['number'], w['paused'], 'moved'))
            lines.append(f'- {w["repo"]}#{w["number"]}{paused}: head moved by a push {_age(now - pushed)} ago, '
                         'not yet polled')
            continue
        state.append((w['repo'], w['number'], w['paused'], w['status'], w['head'], w['detail']))
        observed = _age(now - w['updated']) + ' ago' if w['updated'] else 'not yet polled'
        summary = '; '.join(detail[:4]) + (f'; +{len(detail) - 4} more' if len(detail) > 4 else '')
        lines.append(f'- {w["repo"]}#{w["number"]}{paused}: {w["status"]} (head {w["head"][:8] or "?"}, {observed})'
                     + (f' -- {summary}' if summary else ''))
    # Inject the block only when a line changed since the last injection (ages excluded).
    fingerprint = json.dumps(state)
    last = db.execute('SELECT value FROM meta WHERE key=?', (surface_key(session),)).fetchone()
    with db:
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (surface_key(session), fingerprint))
    if not notices and last and last['value'] == fingerprint:
        return None
    if notices:
        lines.append('Actionable notices (delivered once):')
        lines.extend(n['message'] for n in notices)
        dispatch = 'claude-prompt:' + str(uuid.uuid4())
        with db:
            for n in notices:
                db.execute('UPDATE outbox SET delivered=?,dispatch_id=?,error=? WHERE event_key=?',
                           (now, dispatch, '', n['event_key']))
    lines.append('Report results to the user only (ready, red with cause, finding); never narrate waiting states.')
    return '\n'.join(lines)
