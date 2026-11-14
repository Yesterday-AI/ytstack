"""An observed merge queues one notice to run ytstack:review-lessons (M030)."""
import unittest
from unittest.mock import patch
import test_findings
from prwatch import github, hooks, worker
from prwatch.state import register


def closed(merged):
    pr = {'state': 'closed', 'merged_at': '2026-11-14T10:00:00Z' if merged else None}
    return {'head': 'head2', 'closed': True, 'pr': pr}


class MergeNotice(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def observe(self, s, number=1):
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=?', (number,)).fetchone())

    def notices(self):
        return self.db.execute("SELECT * FROM outbox WHERE event_key LIKE 'merged:%'").fetchall()

    def test_merge_queues_one_notice_delivered_once_without_a_github_call(self):
        self.observe(closed(True))
        self.observe(closed(True))
        rows = self.notices()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['event_key'], 'merged:o/r:1')
        self.assertIn('run ytstack:review-lessons for #1', rows[0]['message'])
        self.assertIn('if this project declares own reviewers', rows[0]['message'])
        with patch.object(github, 'snapshot', side_effect=AssertionError('no GitHub call for a merge notice')):
            worker.deliver(self.db)
            worker.deliver(self.db)
        self.assertEqual(self.client.start.call_count, 1)
        self.assertEqual(self.client.start.call_args.args[0], 'session')
        self.assertIn('was merged', self.client.start.call_args.args[1])
        row = self.notices()[0]
        self.assertIsNotNone(row['delivered'])
        self.assertIsNone(row['cancelled'])

    def test_closed_without_merge_queues_nothing(self):
        self.observe(closed(False))
        self.assertEqual(self.notices(), [])
        self.assertEqual(self.db.execute('SELECT status FROM watches').fetchone()[0], 'closed')
        worker.deliver(self.db)
        self.client.start.assert_not_called()

    def test_reopened_and_merged_later_still_notifies_once(self):
        self.observe(closed(False))
        with self.db:
            register(self.db, 'o/r', 1, 'session', '/tmp')
        self.observe(closed(True))
        self.assertEqual(len(self.notices()), 1)

    def test_claude_session_pulls_the_notice_on_the_next_prompt(self):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
        self.observe(closed(True), number=7)
        worker.deliver(self.db)
        self.assertNotIn('claude:abc', [c.args[0] for c in self.client.start.call_args_list])
        prompt = {'session_id': 'abc', 'hook_event_name': 'UserPromptSubmit', 'cwd': '/tmp'}
        text = hooks.handle(prompt, 'claude')['hookSpecificOutput']['additionalContext']
        self.assertIn('run ytstack:review-lessons for #7', text)
        self.assertEqual(hooks.handle(prompt, 'claude'), {})


if __name__ == '__main__':
    unittest.main()
