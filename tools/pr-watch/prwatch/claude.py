"""Claude Code adapter: pull delivery through the UserPromptSubmit hook.

Claude sessions are stored host-qualified (`claude:<session_id>`). The worker
never pushes to them; instead every user prompt surfaces the session's pending
actionable notices (CI failure, unresolved bot thread, merge conflict, an
observed merge) and the
one-line readiness summaries that changed since the last injection, plus a count
of the unchanged ones, read from the last worker tick.
Hooks make no GitHub calls, so the evidence is at most one tick old and the
agent re-fetches before acting.
"""
import json
import time
import uuid
from .state import cli

PREFIX = 'claude:'
# A PR action_required without a head or status change for this long gets one pause suggestion.
STALE = 24 * 3600


def qualify(session):
    return session if session.startswith(PREFIX) else PREFIX + session


def surface_key(session):
    return f'surface:{session}'


def hint_key(session):
    """The pause hints already shown to `session`: PR key -> changed_at of that stretch.
    SessionStart does not reset it, so a compaction does not repeat a hint."""
    return f'pause-hint:{session}'


def _meta_dict(db, key):
    """A JSON object stored in meta, {} when missing or of another shape (the whole-block
    fingerprint of older versions reads as {}: every line is shown once)."""
    row = db.execute('SELECT value FROM meta WHERE key=?', (key,)).fetchone()
    try:
        value = json.loads(row['value']) if row else {}
    except ValueError:
        return {}
    return value if isinstance(value, dict) else {}


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
    seen = _meta_dict(db, surface_key(session))
    # A watch shown last time that closed since gets one last line: a merge without a bot
    # finding queues no notice, so this line is its only report (PR #89 review).
    gone = [w for w in db.execute("SELECT * FROM watches WHERE session=? AND status='closed' ORDER BY repo, number",
                                  (session,)) if f'{w["repo"]}#{w["number"]}' in seen]
    if not watches and not notices and not gone:
        return None
    hinted, hints = _meta_dict(db, hint_key(session)), {}
    # Each line with its fingerprint (ages excluded); only changed lines are injected (issues #61, #85).
    current, due = {}, set()
    for w in watches:
        key = f'{w["repo"]}#{w["number"]}'
        detail = json.loads(w['detail'] or '[]')
        paused = ' [paused]' if w['paused'] else ''
        pushed = w['pushed_at'] if 'pushed_at' in w.keys() else None
        if pushed and pushed > (w['updated'] or 0):
            # The old head's findings would mislead: the session pushed since the last read.
            current[key] = ((w['paused'], 'moved'), f'- {key}{paused}: head moved by a push '
                            f'{_age(now - pushed)} ago, not yet polled')
            continue
        observed = _age(now - w['updated']) + ' ago' if w['updated'] else 'not yet polled'
        summary = '; '.join(detail[:4]) + (f'; +{len(detail) - 4} more' if len(detail) > 4 else '')
        line = (f'- {key}{paused}: {w["status"]} (head {w["head"][:8] or "?"}, {observed})'
                + (f' -- {summary}' if summary else ''))
        # changed_at NULL (rows from before it existed) counts as long ago (state.py).
        changed = w['changed_at'] if 'changed_at' in w.keys() else None
        if w['status'] == 'action_required' and not w['paused'] and (changed is None or now - changed >= STALE):
            hints[key] = changed
            if key not in hinted or hinted[key] != changed:
                # Once per stale stretch (a new head or status starts a new one), also across SessionStart.
                due.add(key)
                age = f'{int((now - changed) // 3600)} h' if changed is not None else 'over 24 h'
                line += (f'; no new head or status for {age}: if nobody works on it, '
                         f'{cli()} pause --repo {w["repo"]} --pr {w["number"]}')
        current[key] = ((w['paused'], w['status'], w['head'], w['detail']), line)
    fingerprints = {key: json.dumps(fp) for key, (fp, _) in current.items()}
    with db:
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (surface_key(session), json.dumps(fingerprints)))
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (hint_key(session), json.dumps(hints)))
    changed_lines = [line for key, (_, line) in current.items() if key in due or seen.get(key) != fingerprints[key]]
    closed_lines = [f'- {w["repo"]}#{w["number"]}: closed'
                    + (' (merged)' if 'merged' in json.loads(w['detail'] or '[]') else '') for w in gone]
    if not notices and not changed_lines and not closed_lines:
        return None
    unchanged = len(current) - len(changed_lines)
    lines = ['PR Watch (silent background monitor; evidence from the last worker tick, re-fetch before acting):',
             *changed_lines, *closed_lines]
    if unchanged:
        lines.append(f'- {unchanged} unchanged')
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
