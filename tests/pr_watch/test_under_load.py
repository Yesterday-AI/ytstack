"""PR watch under load (issue #61): skipped checks, a moved head, an unchanged
status block, and the review-lessons suggestion only where a bot found something."""
import unittest
from unittest.mock import patch
import test_findings
from test_findings import thread
from test_watch import snapshot, POLICY
from prwatch import github, hooks, worker
from prwatch.evaluate import evaluate
from prwatch.state import register


def with_job(s, name, conclusion):
    s['checks'].append(dict(id=50 + len(s['checks']), name=name, app={'slug': 'github-actions', 'id': 1},
                            head_sha=s['head'], status='completed', conclusion=conclusion))
    return s


class SkippedChecks(unittest.TestCase):
    def test_skipped_or_neutral_optional_job_is_not_a_reason(self):
        for conclusion in ('skipped', 'neutral'):
            with self.subTest(conclusion=conclusion):
                status, detail, _ = evaluate(with_job(snapshot(), 'Check documentation', conclusion), POLICY)
                self.assertEqual(status, 'ready')
                self.assertEqual(detail, [])

    def test_skipped_required_check_and_skipped_bot_review_still_block(self):
        s = snapshot(); s['checks'][0]['conclusion'] = 'skipped'
        self.assertEqual(evaluate(s, POLICY)[0], 'action_required')
        s = snapshot(); s['checks'][1]['conclusion'] = 'skipped'
        self.assertEqual(evaluate(s, POLICY)[0], 'action_required')

    def test_failed_optional_job_still_blocks(self):
        self.assertEqual(evaluate(with_job(snapshot(), 'lint', 'failure'), POLICY)[0], 'action_required')


class UnderLoad(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def watch_row(self):
        return self.db.execute('SELECT * FROM watches WHERE number=7').fetchone()

    def observe(self, s):
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.watch_row())

    def start(self):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
        s = snapshot(); s['pr']['head'] = {'ref': 'feat'}; s['pr']['mergeable'] = False
        self.observe(s)
        return s

    def prompt(self):
        return hooks.handle({'session_id': 'abc', 'hook_event_name': 'UserPromptSubmit', 'cwd': '/tmp'}, 'claude')

    def push(self, command='git push -q origin feat', remote='head3'):
        payload = {'session_id': 'abc', 'hook_event_name': 'PostToolUse', 'cwd': '/tmp', 'tool_name': 'Bash',
                   'tool_input': {'command': command}, 'tool_response': {'stdout': ''}}
        with patch.object(hooks, 'git_binding', return_value=('o/r', 'feat')), \
                patch.object(hooks, 'remote_head', return_value=remote):
            hooks.handle(payload, 'claude')

    def test_own_push_marks_the_head_moved_and_polls_at_once(self):
        self.start()
        self.assertIn('Merge conflict', self.prompt()['hookSpecificOutput']['additionalContext'])
        self.assertFalse(worker.due(self.watch_row(), self.watch_row()['updated'] + 1))
        self.push()
        row = self.watch_row()
        self.assertTrue(worker.due(row, row['updated'] + 1))
        text = self.prompt()['hookSpecificOutput']['additionalContext']
        self.assertIn('head moved', text)
        self.assertNotIn('Merge conflict', text)
        s = snapshot(); s['pr']['head'] = {'ref': 'feat'}; s['head'] = 'head3'
        for c in s['checks']:
            c['head_sha'] = 'head3'
        self.observe(s)
        text = self.prompt()['hookSpecificOutput']['additionalContext']
        self.assertNotIn('head moved', text)
        self.assertIn('head head3', text)

    def test_push_that_leaves_the_watched_branch_unchanged_marks_nothing(self):
        # `git push origin other` from a checked-out `feat`: origin/feat still has the watched head.
        self.start()
        self.push('git push origin other', remote='head2')
        self.assertIsNone(self.watch_row()['pushed_at'])
        # Text that merely mentions a push, without a tracking ref, marks nothing either.
        self.push('echo "git push later"', remote='')
        self.assertIsNone(self.watch_row()['pushed_at'])

    def test_push_of_another_bound_branch_changes_nothing(self):
        self.start()
        payload = {'session_id': 'abc', 'hook_event_name': 'PostToolUse', 'cwd': '/tmp', 'tool_name': 'Bash',
                   'tool_input': {'command': 'git push origin other'}, 'tool_response': {'stdout': ''}}
        with patch.object(hooks, 'git_binding', return_value=('o/r', 'other')), \
                patch.object(hooks, 'remote_head', return_value='head9'):
            hooks.handle(payload, 'claude')
        self.assertIsNone(self.watch_row()['pushed_at'])

    def test_unchanged_block_is_injected_once_until_something_changes(self):
        self.start()
        self.assertIn('o/r#7', self.prompt()['hookSpecificOutput']['additionalContext'])
        self.assertEqual(self.prompt(), {})
        self.assertEqual(self.prompt(), {})
        # After a compaction the context lost the block: SessionStart shows it again on the next prompt.
        hooks.handle({'session_id': 'abc', 'hook_event_name': 'SessionStart', 'cwd': '/tmp'}, 'claude')
        self.assertIn('o/r#7', self.prompt()['hookSpecificOutput']['additionalContext'])
        self.assertEqual(self.prompt(), {})
        s = snapshot(); s['pr']['head'] = {'ref': 'feat'}
        self.observe(s)
        self.assertIn('o/r#7: ready', self.prompt()['hookSpecificOutput']['additionalContext'])


class MergeSuggestion(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def merge(self, number):
        pr = {'state': 'closed', 'merged_at': '2026-11-14T10:00:00Z'}
        with patch.object(github, 'snapshot', return_value={'head': 'h', 'closed': True, 'pr': pr}):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=?', (number,)).fetchone())
        return self.db.execute('SELECT * FROM outbox WHERE event_key=?', (f'merged:o/r:{number}',)).fetchone()

    def test_merge_without_bot_findings_suggests_nothing(self):
        self.assertIsNone(self.merge(1))

    def test_finding_of_a_similarly_named_repository_does_not_count(self):
        # `_` is a LIKE wildcard: o/r_x must not see a finding of o/rXx with the same number.
        with self.db:
            register(self.db, 'o/r_x', 3, 'session', '/tmp')
            register(self.db, 'o/rXx', 3, 'session', '/tmp')
            self.db.execute("INSERT INTO outbox(event_key,repo,number,session,message,created) "
                            "VALUES('bot-thread:o/rXx:3:t','o/rXx',3,'session','m',0)")
        pr = {'state': 'closed', 'merged_at': '2026-11-14T10:00:00Z'}
        with patch.object(github, 'snapshot', return_value={'head': 'h', 'closed': True, 'pr': pr}):
            worker.monitor(self.db, self.db.execute("SELECT * FROM watches WHERE repo='o/r_x'").fetchone())
        self.assertIsNone(self.db.execute("SELECT * FROM outbox WHERE event_key='merged:o/r_x:3'").fetchone())

    def test_merge_after_a_bot_finding_suggests_review_lessons(self):
        s = snapshot(); s['threads'] = [thread()]
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=1').fetchone())
        row = self.merge(1)
        self.assertIsNotNone(row)
        self.assertIn('ytstack:review-lessons for #1', row['message'])
        self.assertIn('1 bot finding', row['message'])


if __name__ == '__main__':
    unittest.main()
