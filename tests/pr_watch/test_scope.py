"""Issue #85: the status block names only the lines that changed, a PR stuck in
action_required for a day gets one pause suggestion, and `status` shows the
current session and repository unless --all."""
import importlib.util
import io
import json
import os
import sys
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch
import test_findings
from test_watch import snapshot
from prwatch import github, hooks, worker
from prwatch.state import enqueue, register

ENGINE = Path(__file__).resolve().parents[2] / 'tools/pr-watch'
spec = importlib.util.spec_from_file_location('prwatch_cli_scope', ENGINE / 'pr-watch.py')
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)


class ChangedLines(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def observe(self, number, s):
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=?', (number,)).fetchone())

    def prompt(self):
        out = hooks.handle({'session_id': 'abc', 'hook_event_name': 'UserPromptSubmit', 'cwd': '/tmp'}, 'claude')
        return out['hookSpecificOutput']['additionalContext'] if out else None

    def test_only_changed_lines_and_a_count_of_the_rest(self):
        with self.db:
            for n in (7, 8, 9):
                register(self.db, 'o/r', n, 'claude:abc', '/tmp')
        for n in (7, 8, 9):
            self.observe(n, snapshot())
        first = self.prompt()
        self.assertIn('o/r#7', first); self.assertIn('o/r#9', first)
        self.assertNotIn('unchanged', first)
        s = snapshot(); s['pr']['mergeable'] = False
        self.observe(8, s)
        text = self.prompt()
        self.assertIn('o/r#8: action_required', text)
        self.assertNotIn('o/r#7', text); self.assertNotIn('o/r#9', text)
        self.assertIn('2 unchanged', text)
        self.assertIsNone(self.prompt())
        # A pending notice comes with the count, not with the unchanged lines.
        watch = self.db.execute('SELECT * FROM watches WHERE number=9').fetchone()
        with self.db:
            enqueue(self.db, 'k9', watch, 'notice for #9')
        text = self.prompt()
        self.assertIn('notice for #9', text)
        self.assertIn('3 unchanged', text)
        self.assertNotIn('o/r#9:', text)

    def test_stale_action_required_suggests_pause_once(self):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
        s = snapshot(); s['pr']['mergeable'] = False
        self.observe(7, s)
        self.assertNotIn('pause', self.prompt())
        with self.db:
            self.db.execute('UPDATE watches SET changed_at=? WHERE number=7', (time.time() - 25 * 3600,))
        text = self.prompt()
        self.assertIn('unchanged for 25 h', text)
        self.assertIn('pause --repo o/r --pr 7', text)
        self.assertIsNone(self.prompt())
        with self.db:
            self.db.execute('UPDATE watches SET paused=1 WHERE number=7')
        self.assertNotIn('pause --repo', self.prompt())


class StatusScope(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def status(self, *argv, session='abc', repo='o/r'):
        out = io.StringIO()
        with patch.dict(os.environ), patch.object(sys, 'argv', ['pr-watch', 'status', *argv]), \
                patch.object(cli, 'origin_repo', return_value=repo), redirect_stdout(out):
            os.environ.pop('CODEX_THREAD_ID', None)
            os.environ.pop('CLAUDE_CODE_SESSION_ID', None)
            if session:
                os.environ['CLAUDE_CODE_SESSION_ID'] = session
            self.assertEqual(cli.main(), 0)
        return json.loads(out.getvalue())

    def test_current_session_and_repository_unless_all(self):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
            register(self.db, 'o/other', 7, 'claude:abc', '/tmp')
            register(self.db, 'o/r', 8, 'claude:else', '/tmp')
        mine = self.status()
        self.assertEqual([(w['repo'], w['number']) for w in mine['watches']], [('o/r', 7)])
        self.assertEqual(mine['scope'], {'session': 'claude:abc', 'repo': 'o/r'})
        self.assertIn('health', mine)
        self.assertEqual(len(self.status('--all')['watches']), 4)   # with the fixture's o/r#1
        self.assertEqual(len(self.status('--repo', 'o/other')['watches']), 1)
        # Outside a session and a GitHub checkout nothing narrows it.
        self.assertEqual(len(self.status(session=None, repo=None)['watches']), 4)


if __name__ == '__main__':
    unittest.main()
