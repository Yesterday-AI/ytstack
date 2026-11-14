"""Delivery must remain cancellable while the owner is busy."""
import copy
import unittest
from unittest.mock import patch, MagicMock
import test_findings
from test_findings import thread
from test_watch import snapshot
from prwatch import worker, github


class Delivery(unittest.TestCase):
    setUp = test_findings.Findings.setUp
    tearDown = test_findings.Findings.tearDown
    monitor = test_findings.Findings.monitor
    def test_busy_owner_keeps_notice_local_until_resolution(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        client=MagicMock();client.status.return_value='active'
        with patch('prwatch.worker.codex.Client') as factory, patch.object(github,'snapshot',return_value=s):
            factory.return_value.__enter__.return_value=client
            worker.deliver(self.db);client.start.assert_not_called()
            self.assertIsNone(self.db.execute('SELECT delivered FROM outbox').fetchone()[0])
            client.status.return_value='idle';s['threads']=[thread(True)]
            worker.deliver(self.db);client.start.assert_not_called()
        self.assertIsNotNone(self.db.execute('SELECT cancelled FROM outbox').fetchone()[0])

    def test_ci_rechecks_close_new_head_and_successful_rerun(self):
        for change in ('closed','head','rerun'):
            with self.subTest(change=change):
                self.db.execute('DELETE FROM outbox');self.db.commit()
                s=snapshot();s['checks'][0]['conclusion']='failure';self.monitor(s)
                live=copy.deepcopy(s)
                if change=='closed':live['closed']=True
                elif change=='head':live['head']='new'
                else:live['checks'][0]['conclusion']='success'
                client=MagicMock();client.status.return_value='idle'
                with patch('prwatch.worker.codex.Client') as factory,patch.object(github,'snapshot',return_value=live):
                    factory.return_value.__enter__.return_value=client
                    worker.deliver(self.db);client.start.assert_not_called()
                self.assertIsNotNone(self.db.execute('SELECT cancelled FROM outbox').fetchone()[0])

    def test_lost_start_receipt_is_not_blindly_retried(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        client=MagicMock();client.status.return_value='idle';client.start.side_effect=TimeoutError()
        with patch('prwatch.worker.codex.Client') as factory,patch.object(github,'snapshot',return_value=s):
            factory.return_value.__enter__.return_value=client
            worker.deliver(self.db);worker.deliver(self.db)
        self.assertEqual(client.start.call_count,1)
        row=self.db.execute('SELECT * FROM outbox').fetchone()
        self.assertIsNone(row['delivered']);self.assertTrue(row['dispatch_id'])
        self.assertIn('uncertain',row['error'])

    def test_busy_owner_does_not_block_another_session(self):
        from prwatch.state import register
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        with self.db:register(self.db,'o/r',2,'other','/tmp')
        with patch.object(github,'snapshot',return_value=s):
            worker.monitor(self.db,self.db.execute('SELECT * FROM watches WHERE number=2').fetchone())
        client=self.client
        client.status.side_effect=lambda session:'active' if session=='session' else 'idle'
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        self.assertEqual(client.start.call_count,1)
        self.assertEqual(client.start.call_args.args[0],'other')

    def test_hooks_and_discovery_errors_do_not_wake(self):
        import time
        from prwatch import hooks
        with patch.object(hooks,'git_binding',return_value=None):
            for event in ('PreToolUse','PostToolUse','Stop'):
                self.assertEqual(hooks.handle({'session_id':'session','hook_event_name':event,'cwd':'/tmp'}),{})
        with self.db:self.db.execute('INSERT INTO bindings VALUES(?,?,?,?,?,?)',('o/r','feat/x','session','/tmp',time.time(),time.time()))
        with patch.object(github,'open_pulls',side_effect=github.APIError('offline')):worker.discover(self.db)
        worker.deliver(self.db);self.client.start.assert_not_called()
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM outbox').fetchone()[0],0)
        self.assertEqual(self.db.execute("SELECT value FROM meta WHERE key='discovery:o/r:feat/x'").fetchone()[0],'APIError')

    def test_owner_becoming_busy_during_revalidation_defers(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        self.client.status.side_effect=['idle','active']
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        self.client.start.assert_not_called()
        row=self.db.execute('SELECT * FROM outbox').fetchone()
        self.assertIsNone(row['dispatch_id']);self.assertIsNone(row['delivered'])
