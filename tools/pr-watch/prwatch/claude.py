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
import subprocess
import time
import uuid
from pathlib import Path
from .state import cli, policy

PREFIX = 'claude:'
# A PR action_required without a head or status change for this long gets one pause suggestion.
STALE = 24 * 3600
# Before that: a STALL mark after this many minutes, and once more after the next window
# (policy `stall_minutes`, 0 = off; issue #91).
STALL_MINUTES = 15
FRONTIER = Path(__file__).resolve().parents[3] / 'bin/ytstack-frontier'


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


def stall_minutes(repo):
    try:
        return max(0, int(policy(repo).get('stall_minutes', STALL_MINUTES)))
    except (TypeError, ValueError):
        return STALL_MINUTES


def owner(w):
    """The lane of LANES.md in the watch's checkout that holds the PR, with its last commit or
    claim (`ytstack-frontier owner`), or ''. Only from a checkout of the PR's repository: a PR
    number means nothing in another one. Local files only, no GitHub call."""
    from .hooks import REPO
    cwd = w['cwd'] or ''
    if not cwd or not FRONTIER.is_file():
        return ''
    try:
        origin = subprocess.run(['git', '-C', cwd, 'remote', 'get-url', 'origin'],
                                capture_output=True, text=True, timeout=3).stdout.strip()
        match = REPO.fullmatch(origin)
        if not match or match[1].lower() != w['repo'].lower():
            return ''
        p = subprocess.run(['bash', str(FRONTIER), '-C', cwd, 'owner', '--pr', str(w['number'])],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return ''
    lines = p.stdout.strip().splitlines()
    return lines[0] if p.returncode == 0 and lines else ''


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
    # A focus or STALL mark joins the fingerprint only when set: older fingerprints stay equal.
    current, due, focused, stalled, limits = {}, set(), set(), {}, {}
    for w in watches:
        key = f'{w["repo"]}#{w["number"]}'
        if 'focus' in w.keys() and w['focus']:
            focused.add(key)
        mark = (('focus',),) if key in focused else ()
        detail = json.loads(w['detail'] or '[]')
        paused = ' [paused]' if w['paused'] else ''
        pushed = w['pushed_at'] if 'pushed_at' in w.keys() else None
        if pushed and pushed > (w['updated'] or 0):
            # The old head's findings would mislead: the session pushed since the last read.
            current[key] = ((w['paused'], 'moved') + mark, f'- {key}{paused}: head moved by a push '
                            f'{_age(now - pushed)} ago, not yet polled')
            continue
        observed = _age(now - w['updated']) + ' ago' if w['updated'] else 'not yet polled'
        summary = '; '.join(detail[:4]) + (f'; +{len(detail) - 4} more' if len(detail) > 4 else '')
        line = (f'- {key}{paused}: {w["status"]} (head {w["head"][:8] or "?"}, {observed})'
                + (f' -- {summary}' if summary else ''))
        # changed_at NULL (rows from before it existed) counts as long ago (state.py).
        changed = w['changed_at'] if 'changed_at' in w.keys() else None
        if w['repo'] not in limits:
            limits[w['repo']] = stall_minutes(w['repo']) * 60
        limit = limits[w['repo']]
        if (w['status'] == 'action_required' and not w['paused'] and limit and changed is not None
                and limit <= now - changed < STALE):
            # The lane (owner) is looked up only for a line that is shown.
            stall = min(2, int((now - changed) // limit))
            stalled[key] = w
            mark += (('stall', stall),)
            line += f'; STALL {stall}: no new head or status for {int((now - changed) // 60)} min'
        if w['status'] == 'action_required' and not w['paused'] and (changed is None or now - changed >= STALE):
            hints[key] = changed
            if key not in hinted or hinted[key] != changed:
                # Once per stale stretch (a new head or status starts a new one), also across SessionStart.
                due.add(key)
                age = f'{int((now - changed) // 3600)} h' if changed is not None else 'over 24 h'
                line += (f'; no new head or status for {age}: if nobody works on it, '
                         f'{cli()} pause --repo {w["repo"]} --pr {w["number"]}')
        current[key] = ((w['paused'], w['status'], w['head'], w['detail']) + mark, line)
    fingerprints = {key: json.dumps(fp) for key, (fp, _) in current.items()}
    with db:
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (surface_key(session), json.dumps(fingerprints)))
        db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (hint_key(session), json.dumps(hints)))
    shown = [key for key in current if key in due or seen.get(key) != fingerprints[key]]
    text = {key: current[key][1] + (f'; {lane}' if key in stalled and (lane := owner(stalled[key])) else '')
            for key in shown}
    focus_lines = [text[key] for key in shown if key in focused]
    changed_lines = [text[key] for key in shown if key not in focused]
    closed_lines = [f'- {w["repo"]}#{w["number"]}: closed'
                    + (' (merged)' if 'merged' in json.loads(w['detail'] or '[]') else '') for w in gone]
    if not notices and not shown and not closed_lines:
        return None
    unchanged = len(current) - len(shown)
    lines = ['PR Watch (silent background monitor; evidence from the last worker tick, re-fetch before acting):']
    if focus_lines:
        lines += ['Focus (read every tick):', *focus_lines]
        if changed_lines or closed_lines or unchanged:
            lines.append('Others:')
    lines += [*changed_lines, *closed_lines]
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
