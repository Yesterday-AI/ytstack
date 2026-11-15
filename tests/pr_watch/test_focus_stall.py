"""Issue #91: a focus PR is read every tick and listed first in the status block; an
action_required PR without a new head or status for `stall_minutes` (default 15) gets a
STALL mark, once per window and two windows, with the lane of LANES.md that holds it
(`ytstack-frontier owner`)."""
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from unittest.mock import patch
import test_findings
from test_scope import cli
from test_watch import snapshot, POLICY
from prwatch import github, hooks, worker
from prwatch.state import register


class Focus(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def observe(self, number, s):
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=?', (number,)).fetchone())

    def prompt(self):
        out = hooks.handle({'session_id': 'abc', 'hook_event_name': 'UserPromptSubmit', 'cwd': '/tmp'}, 'claude')
        return out['hookSpecificOutput']['additionalContext'] if out else None

    def register_cli(self, *argv):
        with patch.object(sys, 'argv', ['pr-watch', 'register', '--repo', 'o/r', '--session', 'claude:abc', *argv]), \
                patch.object(github, 'api', return_value={'state': 'open', 'html_url': 'https://github.com/o/r/pull/7'}), \
                redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()):
            code = cli.main()
        return code, out.getvalue()

    def focus(self, number):
        return self.db.execute('SELECT focus FROM watches WHERE number=?', (number,)).fetchone()['focus']

    def test_register_sets_and_clears_focus(self):
        code, out = self.register_cli('--pr', '7', '--focus')
        self.assertEqual((code, self.focus(7)), (0, 1))
        self.assertIn('(focus)', out)
        self.register_cli('--pr', '7')
        self.assertEqual(self.focus(7), 1, 'register without the flag keeps it')
        self.register_cli('--pr', '7', '--no-focus')
        self.assertEqual(self.focus(7), 0)
        with self.assertRaises(SystemExit):
            self.register_cli('--all-open', '--focus')

    def test_a_focus_pr_is_read_every_tick(self):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
        self.observe(7, snapshot())
        now = time.time()
        with self.db:
            self.db.execute('UPDATE watches SET updated=?, changed_at=? WHERE number=7', (now - 60, now - 7200))
        row = lambda: self.db.execute('SELECT * FROM watches WHERE number=7').fetchone()
        self.assertFalse(worker.due(row(), now), 'a settled PR waits for the quiet interval')
        with self.db:
            self.db.execute('UPDATE watches SET focus=1 WHERE number=7')
        self.assertTrue(worker.due(row(), now))
        with self.db:
            self.db.execute("UPDATE watches SET status='closed' WHERE number=7")
        self.assertFalse(worker.due(row(), now), 'never a closed one')

    def test_focus_lines_come_first_and_separately(self):
        with self.db:
            for n in (7, 8, 9):
                register(self.db, 'o/r', n, 'claude:abc', '/tmp')
            self.db.execute('UPDATE watches SET focus=1 WHERE number=9')
        for n in (7, 8, 9):
            self.observe(n, snapshot())
        text = self.prompt()
        self.assertLess(text.index('Focus (read every tick):'), text.index('o/r#9'))
        self.assertLess(text.index('o/r#9'), text.index('Others:'))
        self.assertLess(text.index('Others:'), text.index('o/r#7'))
        s = snapshot(); s['pr']['mergeable'] = False
        self.observe(8, s)
        text = self.prompt()
        self.assertNotIn('Focus', text, 'no heading without a focus line')
        self.assertIn('o/r#8', text)


class Stall(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown
    observe = Focus.observe
    prompt = Focus.prompt

    def checkout(self, origin='https://github.com/o/r.git'):
        """A checkout of o/r whose LANES.md says lane M001-S01 (branch work/s01) holds PR 7."""
        d = Path(self.tmp.name) / 'checkout'
        (d / '.ytstack').mkdir(parents=True)
        git = lambda *a: subprocess.run(['git', '-C', str(d), *a], check=True, capture_output=True)
        git('init', '-q', '-b', 'main')
        git('remote', 'add', 'origin', origin)
        claimed = time.strftime('%Y-%m-%dT%H:%MZ', time.gmtime(time.time() - 3 * 3600))
        (d / '.ytstack/LANES.md').write_text(
            '---\nupdated: 2026-11-15T10:00:00Z\n---\n\n# Lanes\n\n'
            '| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |\n'
            '|---|---|---|---|---|---|---|---|---|---|\n'
            f'| M001-S01 | implement | running | w1 {claimed} | - | - | 7 | - | 1 | fix the review |\n')
        return str(d)

    def stalled(self, number, minutes, cwd='/tmp'):
        with self.db:
            register(self.db, 'o/r', number, 'claude:abc', cwd)
        s = snapshot(); s['pr']['mergeable'] = False
        self.observe(number, s)
        self.prompt()
        self.age(number, minutes)

    def age(self, number, minutes):
        with self.db:
            self.db.execute('UPDATE watches SET changed_at=? WHERE number=?', (time.time() - minutes * 60 - 5, number))

    def test_two_windows_with_the_lane_that_holds_the_pr(self):
        self.stalled(7, 14, self.checkout())
        self.assertIsNone(self.prompt(), 'not before the window ends')
        self.age(7, 16)
        text = self.prompt()
        self.assertRegex(text, r'o/r#7: action_required .*; STALL 1: no new head or status for 16 min; '
                               r'lane M001-S01 held by w1 \(running\), claimed 1[78]\d min ago, no branch in its row')
        self.assertIsNone(self.prompt(), 'once per window')
        self.age(7, 31)
        self.assertIn('STALL 2: no new head or status for 31 min; lane M001-S01', self.prompt())
        self.age(7, 50)
        self.assertIsNone(self.prompt(), 'two windows only')

    def test_without_a_lane_paused_or_switched_off(self):
        self.stalled(8, 16)
        text = self.prompt()
        self.assertIn('STALL 1: no new head or status for 16 min', text)
        self.assertNotIn('lane ', text, '/tmp has no LANES.md')
        with self.db:
            self.db.execute('UPDATE watches SET paused=1 WHERE number=8')
        self.age(8, 31)
        self.assertNotIn('STALL', self.prompt() or '')
        Path(self.tmp.name, 'policy.json').write_text(json.dumps({'defaults': {**POLICY, 'stall_minutes': 0}}))
        self.stalled(9, 40)
        self.assertNotIn('STALL', self.prompt() or '')

    def test_a_checkout_of_another_repository_names_no_lane(self):
        self.stalled(7, 16, self.checkout('https://github.com/o/other.git'))
        text = self.prompt()
        self.assertIn('STALL 1', text)
        self.assertNotIn('lane M001-S01', text)


if __name__ == '__main__':
    unittest.main()
