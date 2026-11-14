"""Claude Code adapter: host-qualified ownership and pull delivery on user prompts."""
import json
import unittest
from unittest.mock import patch
import test_findings
from test_findings import thread
from test_watch import snapshot
from prwatch import claude, github, hooks, worker
from prwatch.state import register


class Claude(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown

    def watch(self, s):
        with self.db:
            register(self.db, 'o/r', 7, 'claude:abc', '/tmp')
        with patch.object(github, 'snapshot', return_value=s):
            worker.monitor(self.db, self.db.execute('SELECT * FROM watches WHERE number=7').fetchone())

    def prompt(self):
        return hooks.handle({'session_id': 'abc', 'hook_event_name': 'UserPromptSubmit', 'cwd': '/tmp'}, 'claude')

    def test_hook_qualifies_claude_sessions(self):
        payload = {'session_id': 'abc', 'hook_event_name': 'PostToolUse', 'cwd': '/tmp', 'tool_name': 'Bash',
                   'tool_input': {'command': 'gh pr create --title t'},
                   'tool_response': {'stdout': 'https://github.com/o/r/pull/9\n'}}
        with patch.object(hooks, 'git_binding', return_value=None):
            hooks.handle(payload, 'claude')
        self.assertEqual(self.db.execute('SELECT session FROM candidates').fetchone()[0], 'claude:abc')
        # gh pr create on a later line of a multi-line command (heredoc body first) still registers.
        payload['tool_input'] = {'command': "cat > /tmp/b <<'X'\nbody\nX\ngh pr create --body-file /tmp/b | tail -1"}
        payload['tool_response'] = {'stdout': 'https://github.com/o/r/pull/10\n'}
        with patch.object(hooks, 'git_binding', return_value=None):
            hooks.handle(payload, 'claude')
        self.assertEqual(self.db.execute('SELECT count(*) FROM candidates WHERE number=10').fetchone()[0], 1)
        start = hooks.handle({'session_id': 'abc', 'hook_event_name': 'SessionStart', 'cwd': '/tmp'}, 'claude')
        self.assertIn('claude:abc', start['hookSpecificOutput']['additionalContext'])
        self.assertIn('never woken', start['hookSpecificOutput']['additionalContext'])

    def test_prompt_is_silent_without_watches(self):
        self.assertEqual(self.prompt(), {})

    def test_notice_is_pulled_once_and_never_pushed_to_codex(self):
        s = snapshot(); s['threads'] = [thread()]
        self.watch(s)
        with patch.object(github, 'snapshot', return_value=s):
            worker.deliver(self.db)
        # The Codex transport only ever saw the unqualified owner of PR 1, never the Claude session.
        self.assertNotIn('claude:abc', [c.args[0] for c in self.client.start.call_args_list])
        first = self.prompt()['hookSpecificOutput']['additionalContext']
        self.assertIn('o/r#7', first)
        self.assertIn('Unresolved bot finding', first)
        row = self.db.execute("SELECT * FROM outbox WHERE session='claude:abc'").fetchone()
        self.assertIsNotNone(row['delivered'])
        self.assertTrue(row['dispatch_id'].startswith('claude-prompt:'))
        second = self.prompt()['hookSpecificOutput']['additionalContext']
        self.assertIn('o/r#7: action_required', second)
        self.assertNotIn('Actionable notices', second)

    def test_ready_pr_is_summarised_and_closed_pr_drops_out(self):
        s = snapshot()
        self.watch(s)
        text = self.prompt()['hookSpecificOutput']['additionalContext']
        self.assertIn('o/r#7: ready (head head2', text)
        s['closed'] = True
        self.watch(s)
        self.assertEqual(self.prompt(), {})

    def test_qualify_is_idempotent(self):
        self.assertEqual(claude.qualify('claude:x'), 'claude:x')
        self.assertTrue(claude.is_claude(claude.qualify('x')))
        self.assertFalse(claude.is_claude('codex-thread'))


if __name__ == '__main__':
    unittest.main()
