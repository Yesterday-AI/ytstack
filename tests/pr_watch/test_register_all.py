"""`register --all-open`: a coordinator takes over every open PR of a repository,
including the ones subagents or earlier sessions opened (issue #54)."""
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
from prwatch.state import connect, register

spec = importlib.util.spec_from_file_location('prwatch_cli', ENGINE / 'pr-watch.py')
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)


class RegisterAllOpen(unittest.TestCase):
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

    def watches(self):
        db = connect()
        rows = {r['number']: r['session'] for r in db.execute('SELECT number, session FROM watches')}
        db.close()
        return rows

    def test_registers_every_open_pr_and_skips_foreign_ones(self):
        db = connect()
        with db:
            register(db, 'o/r', 2, 'claude:coordinator', '/tmp')   # already ours
            register(db, 'o/r', 3, 'claude:other', '/tmp')         # another session's
        db.close()
        prs = [{'number': n} for n in (4, 1, 3, 2)]
        with patch.object(github, 'open_pulls', return_value=prs) as listing:
            code, out = self.run_cli('register', '--repo', 'o/r', '--all-open',
                                     '--session', 'claude:coordinator', '--cwd', self.tmp.name)
        self.assertEqual(code, 0)
        listing.assert_called_once_with('o/r')
        self.assertEqual(self.watches(), {1: 'claude:coordinator', 2: 'claude:coordinator',
                                          3: 'claude:other', 4: 'claude:coordinator'})
        self.assertIn('2 registered to claude:coordinator, 1 already watched by it, 1 owned by another session', out)
        self.assertIn('registered: #1 #4', out)
        self.assertIn('#3 (claude:other)', out)

    def test_pr_registered_by_another_process_after_the_lookup_is_skipped(self):
        real_register = cli.register

        def racing_register(db, repo, number, session, cwd):
            # The worker registers the PR between the CLI's lookup and its register call.
            db.execute('INSERT OR IGNORE INTO watches(repo,number,session,cwd) VALUES(?,?,?,?)',
                       (repo, number, 'claude:worker-found', cwd))
            return real_register(db, repo, number, session, cwd)

        with patch.object(github, 'open_pulls', return_value=[{'number': 7}]), \
                patch.object(cli, 'register', side_effect=racing_register):
            code, out = self.run_cli('register', '--repo', 'o/r', '--all-open',
                                     '--session', 'claude:coordinator', '--cwd', self.tmp.name)
        self.assertEqual(code, 0)
        self.assertIn('#7 (claude:worker-found)', out)

    def test_needs_a_session(self):
        with patch.object(github, 'open_pulls', return_value=[]), self.assertRaises(SystemExit):
            with redirect_stdout(io.StringIO()), patch('sys.stderr', io.StringIO()):
                self.run_cli('register', '--repo', 'o/r', '--all-open')

    def test_pr_and_all_open_are_exclusive(self):
        with self.assertRaises(SystemExit), patch('sys.stderr', io.StringIO()):
            self.run_cli('register', '--repo', 'o/r', '--all-open', '--pr', '5', '--session', 's')


if __name__ == '__main__':
    unittest.main()
