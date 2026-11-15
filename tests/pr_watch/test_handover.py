"""`handover`: a coordinator that rotates to a fresh session takes its PR watches
along, also for PRs its still-running subagents open later (issue #61)."""
import importlib.util
import io
import os
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ENGINE = Path(__file__).resolve().parents[2] / 'tools/pr-watch'
sys.path.insert(0, str(ENGINE))
from prwatch import claude, github, hooks, worker
from prwatch.state import connect, enqueue, register

spec = importlib.util.spec_from_file_location('prwatch_cli', ENGINE / 'pr-watch.py')
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)

OLD, NEW = 'claude:old-coordinator', 'claude:new-coordinator'


class Handover(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'PR_WATCH_HOME': self.tmp.name}, clear=False)
        self.env.start()
        os.environ.pop('CLAUDE_CODE_SESSION_ID', None)
        os.environ.pop('CODEX_THREAD_ID', None)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def run_cli(self, *argv):
        out = io.StringIO()
        with patch.object(sys, 'argv', ['pr-watch', *argv]), redirect_stdout(out):
            code = cli.main()
        return code, out.getvalue()

    def rows(self, sql, *args):
        db = connect()
        result = [dict(r) for r in db.execute(sql, args)]
        db.close()
        return result

    def seed(self):
        db = connect()
        with db:
            register(db, 'o/r', 1, OLD, '/tmp')
            register(db, 'o/r', 2, OLD, '/tmp')
            register(db, 'o/r', 3, 'claude:someone-else', '/tmp')
            w1 = db.execute("SELECT * FROM watches WHERE number=1").fetchone()
            enqueue(db, 'ci:o/r:1:abc', w1, 'red check')
            enqueue(db, 'ci:o/r:1:old', w1, 'delivered long ago')
            db.execute("UPDATE outbox SET delivered=1 WHERE event_key='ci:o/r:1:old'")
            db.execute("INSERT INTO bindings VALUES('o/r','lane-a',?,'/wt/a',1,1)", (OLD,))
            db.execute("INSERT INTO candidates VALUES('o/r',9,?,'/wt/a',1)", (OLD,))
            db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', (claude.surface_key(NEW), 'stale'))
        db.close()

    def test_moves_watches_notices_bindings_and_candidates(self):
        self.seed()
        code, out = self.run_cli('handover', '--from', OLD, '--to', NEW)
        self.assertEqual(code, 0)
        owners = {r['number']: r['session'] for r in self.rows('SELECT number, session FROM watches')}
        self.assertEqual(owners, {1: NEW, 2: NEW, 3: 'claude:someone-else'})
        notices = {r['event_key']: r['session'] for r in self.rows('SELECT event_key, session FROM outbox')}
        self.assertEqual(notices['ci:o/r:1:abc'], NEW)
        # A delivered notice is history and stays where it was shown.
        self.assertEqual(notices['ci:o/r:1:old'], OLD)
        self.assertEqual([r['session'] for r in self.rows('SELECT session FROM bindings')], [NEW])
        self.assertEqual([r['session'] for r in self.rows('SELECT session FROM candidates')], [NEW])
        # The successor's next prompt shows the block again.
        self.assertEqual(self.rows('SELECT * FROM meta WHERE key=?', claude.surface_key(NEW)), [])
        self.assertIn(f'2 watches handed over from {OLD} to {NEW}: o/r#1 o/r#2', out)
        self.assertIn('1 pending notice', out)

    def test_later_registrations_for_the_old_session_go_to_the_successor(self):
        self.run_cli('handover', '--from', OLD, '--to', NEW)
        db = connect()
        with db:
            # The worker adopts a PR a subagent of the old session opened after the handover.
            register(db, 'o/r', 5, OLD, '/wt/b')
        db.close()
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=5'), [{'session': NEW}])

    def test_a_chain_of_handovers_is_followed_and_handing_back_works(self):
        self.run_cli('handover', '--from', OLD, '--to', NEW)
        self.run_cli('handover', '--from', NEW, '--to', 'claude:third')
        db = connect()
        with db:
            register(db, 'o/r', 6, OLD, '/tmp')
        db.close()
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=6'), [{'session': 'claude:third'}])
        # Back to the first session: it is live again, nothing loops.
        self.run_cli('handover', '--from', 'claude:third', '--to', OLD)
        db = connect()
        with db:
            register(db, 'o/r', 7, NEW, '/tmp')
            register(db, 'o/r', 8, OLD, '/tmp')
        db.close()
        owners = {r['number']: r['session'] for r in self.rows('SELECT number, session FROM watches')}
        self.assertEqual(owners, {6: OLD, 7: OLD, 8: OLD})

    def test_a_codex_notice_in_flight_stays(self):
        db = connect()
        with db:
            register(db, 'o/r', 1, 'thread-old', '/tmp')
            w = db.execute("SELECT * FROM watches WHERE number=1").fetchone()
            enqueue(db, 'ci:o/r:1:x', w, 'red check')
            db.execute("UPDATE outbox SET dispatch_id='d1' WHERE event_key='ci:o/r:1:x'")
        db.close()
        self.run_cli('handover', '--from', 'thread-old', '--to', 'thread-new')
        self.assertEqual(self.rows('SELECT session FROM outbox'), [{'session': 'thread-old'}])

    def test_to_defaults_to_the_current_claude_session(self):
        self.seed()
        with patch.dict(os.environ, {'CLAUDE_CODE_SESSION_ID': 'new-coordinator'}):
            code, out = self.run_cli('handover', '--from', OLD)
        self.assertEqual(code, 0)
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=1'), [{'session': NEW}])

    def test_nothing_to_move_still_forwards(self):
        code, out = self.run_cli('handover', '--from', OLD, '--to', NEW)
        self.assertEqual(code, 0)
        self.assertIn(f'0 watches handed over from {OLD} to {NEW}', out)
        self.assertIn(f'later registrations for {OLD} go to {NEW}', out)

    def test_a_subagent_of_the_old_session_on_a_handed_over_branch_is_adopted(self):
        # PR #66 review: after the handover a still-running subagent of the old session
        # touches the branch again; the worker must adopt its PR for the successor instead
        # of reporting two sessions on the branch.
        self.seed()
        self.run_cli('handover', '--from', OLD, '--to', NEW)
        payload = dict(session_id='old-coordinator', hook_event_name='PreToolUse', cwd='/wt/a',
                       tool_name='Bash', tool_input={'command': 'git status'})
        with patch.object(hooks, 'git_binding', return_value=('o/r', 'lane-a')):
            hooks.handle(payload, 'claude')
        db = connect()
        with db:
            db.execute('UPDATE bindings SET since=?, touched=?', (time.time() - 10, time.time()))
        pr = dict(head={'ref': 'lane-a', 'repo': {'full_name': 'o/r'}}, number=12,
                  created_at='2099-01-01T00:00:00Z', state='open')
        with patch.object(github, 'open_pulls', return_value=[pr]), patch.object(github, 'api', return_value=pr):
            worker.discover(db)
        db.close()
        self.assertEqual(self.rows("SELECT * FROM meta WHERE key LIKE 'ownership:%'"), [])
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=12'), [{'session': NEW}])

    def test_a_bare_claude_id_is_qualified(self):
        # PR #66 review: `--from <bare claude id>` matched nothing.
        self.seed()
        code, out = self.run_cli('handover', '--from', 'old-coordinator', '--to', 'new-coordinator')
        self.assertEqual(code, 0)
        self.assertIn(f'2 watches handed over from {OLD} to {NEW}', out)
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=1'), [{'session': NEW}])

    def test_a_bare_codex_thread_stays_bare(self):
        db = connect()
        with db:
            register(db, 'o/r', 1, 'thread-old', '/tmp')
        db.close()
        code, out = self.run_cli('handover', '--from', 'thread-old', '--to', 'thread-new')
        self.assertEqual(self.rows('SELECT session FROM watches WHERE number=1'), [{'session': 'thread-new'}])

    def test_refuses_the_same_session_and_a_missing_target(self):
        for argv in (('handover', '--from', OLD, '--to', OLD), ('handover', '--from', OLD)):
            with self.assertRaises(SystemExit), patch('sys.stderr', io.StringIO()):
                self.run_cli(*argv)


if __name__ == '__main__':
    unittest.main()
