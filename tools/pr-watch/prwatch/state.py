"""Durable ownership and outbox. GitHub content is never stored as executable input."""
import json
import os
import sqlite3
import time
from pathlib import Path


def root():
    """User-level PR watch directory, stable across plugin versions and hosts."""
    return Path(os.environ.get('YTSTACK_PR_WATCH_HOME') or str(Path.home() / '.ytstack/pr-watch'))


def home():
    # PR_WATCH_HOME overrides the state directory itself (tests).
    override = os.environ.get('PR_WATCH_HOME')
    return Path(override) if override else root() / 'state'


def cli():
    """How hook and CLI text names the command; the launchers export the absolute path."""
    return os.environ.get('YTSTACK_PR_WATCH_CLI') or 'bin/ytstack-pr-watch'


def connect():
    root = home()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    db = sqlite3.connect(root / 'watch.sqlite3', timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA journal_mode=WAL')
    db.executescript('''
      CREATE TABLE IF NOT EXISTS bindings (
        repo TEXT, branch TEXT, session TEXT, cwd TEXT, since REAL, touched REAL,
        PRIMARY KEY(repo, branch, session));
      CREATE TABLE IF NOT EXISTS watches (
        repo TEXT, number INTEGER, session TEXT, cwd TEXT, head TEXT DEFAULT '',
        status TEXT DEFAULT 'registered', detail TEXT DEFAULT '', updated REAL DEFAULT 0,
        paused INTEGER DEFAULT 0, PRIMARY KEY(repo, number));
      CREATE TABLE IF NOT EXISTS candidates (
        repo TEXT, number INTEGER, session TEXT, cwd TEXT, since REAL,
        PRIMARY KEY(repo, number, session));
      CREATE TABLE IF NOT EXISTS outbox (
        event_key TEXT PRIMARY KEY, repo TEXT, number INTEGER, session TEXT,
        message TEXT, created REAL, delivered REAL, acked REAL, attempts INTEGER DEFAULT 0,
        retry_at REAL DEFAULT 0, error TEXT DEFAULT '');
      CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
    ''')
    with db:
        db.execute('BEGIN IMMEDIATE')
        columns = {r['name'] for r in db.execute('PRAGMA table_info(outbox)')}
        for name, kind in [('cancelled', 'REAL'), ('dispatch_id', 'TEXT'), ('turn_id', 'TEXT')]:
            if name not in columns:
                db.execute(f'ALTER TABLE outbox ADD COLUMN {name} {kind}')
        watch_columns = {r['name'] for r in db.execute('PRAGMA table_info(watches)')}
        if 'changed_at' not in watch_columns:
            # When head or status last changed; NULL (older rows) counts as long ago.
            db.execute('ALTER TABLE watches ADD COLUMN changed_at REAL')
        if 'closed_at' not in watch_columns:
            # Closing time for the reopen window. Rows closed before this column
            # existed get the time they were last read, which is when the worker
            # saw them closed (an older install: weeks back, so never rechecked).
            db.execute('ALTER TABLE watches ADD COLUMN closed_at REAL')
            db.execute("UPDATE watches SET closed_at=updated WHERE status='closed'")
    return db


def enqueue(db, key, watch, message):
    db.execute('INSERT OR IGNORE INTO outbox(event_key,repo,number,session,message,created) VALUES(?,?,?,?,?,?)',
               (key, watch['repo'], watch['number'], watch['session'], message, time.time()))


def register(db, repo, number, session, cwd):
    existing = db.execute('SELECT session FROM watches WHERE repo=? AND number=?', (repo, number)).fetchone()
    if existing and existing['session'] != session:
        raise ValueError('PR already belongs to another session; explicit reassignment required')
    db.execute('DELETE FROM meta WHERE key IN (?,?)', (f'ownership:{repo}:{number}', f'registration:{repo}:{number}'))
    db.execute('INSERT OR IGNORE INTO watches(repo,number,session,cwd) VALUES(?,?,?,?)',
               (repo, number, session, cwd))
    # Registering again revives a watch that was closed (for example a PR that was reopened).
    db.execute("UPDATE watches SET status='registered', updated=0, closed_at=NULL WHERE repo=? AND number=? AND status='closed'",
               (repo, number))


def policy(repo):
    p = home() / 'policy.json'
    config = json.loads(p.read_text()) if p.exists() else {}
    return {**config.get('defaults', {}), **config.get('repositories', {}).get(repo, {})}
