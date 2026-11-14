"""A Claude Code session id passed without its `claude:` prefix is stored as a
Codex thread, and its notices are never delivered (issue #54, field run).
The CLI qualifies the current Claude session's bare id, and `register` heals
watches an earlier run stored under the bare id."""
import importlib.util
import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ENGINE = Path(__file__).resolve().parents[2] / 'tools/pr-watch'
sys.path.insert(0, str(ENGINE))
from prwatch import github
from prwatch.state import connect, enqueue, register

spec = importlib.util.spec_from_file_location('prwatch_cli_spelling', ENGINE / 'pr-watch.py')
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)

SID = 'a14a2aad-faae-41d3-8126-9dc9928a466b'


class SessionSpelling(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'PR_WATCH_HOME': self.tmp.name, 'CLAUDE_CODE_SESSION_ID': SID},
                              clear=False)
        self.env.start()
        os.environ.pop('CODEX_THREAD_ID', None)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def run_cli(self, *argv):
        out = io.StringIO()
        with patch.object(sys, 'argv', ['pr-watch', *argv]), redirect_stdout(out):
            code = cli.main()
        return code, out.getvalue()

    def rows(self, sql):
        db = connect()
        rows = [tuple(r) for r in db.execute(sql)]
        db.close()
        return rows

    def test_bare_id_of_the_current_claude_session_is_qualified(self):
        with patch.object(github, 'open_pulls', return_value=[{'number': 5}]):
            code, out = self.run_cli('register', '--repo', 'o/r', '--all-open', '--session', SID,
                                     '--cwd', self.tmp.name)
        self.assertEqual(code, 0)
        self.assertEqual(self.rows('SELECT number, session FROM watches'), [(5, 'claude:' + SID)])
        self.assertIn('registered to claude:' + SID, out)

    def test_bare_id_of_another_session_stays_as_given(self):
        # A Codex thread id is bare by design.
        with patch.object(github, 'open_pulls', return_value=[{'number': 5}]):
            self.run_cli('register', '--repo', 'o/r', '--all-open', '--session', 'codex-thread-1',
                         '--cwd', self.tmp.name)
        self.assertEqual(self.rows('SELECT session FROM watches'), [('codex-thread-1',)])

    def test_register_heals_watches_stored_under_the_bare_claude_id(self):
        db = connect()
        with db:
            register(db, 'o/r', 7, SID, '/tmp')
            enqueue(db, 'ci:o/r#7:abc', {'repo': 'o/r', 'number': 7, 'session': SID}, 'CI failed')
            db.execute("UPDATE outbox SET error='RPCError', attempts=3")
        db.close()
        with patch.object(github, 'open_pulls', return_value=[{'number': 7}]):
            code, out = self.run_cli('register', '--repo', 'o/r', '--all-open', '--cwd', self.tmp.name)
        self.assertEqual(code, 0)
        self.assertEqual(self.rows('SELECT session FROM watches'), [('claude:' + SID,)])
        self.assertEqual(self.rows('SELECT session, error FROM outbox'), [('claude:' + SID, '')])
        self.assertIn('1 already watched by it, 0 owned by another session', out)


if __name__ == '__main__':
    unittest.main()
