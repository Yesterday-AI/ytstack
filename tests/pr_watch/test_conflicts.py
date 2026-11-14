import unittest
from unittest.mock import patch
import test_findings
from test_watch import snapshot, POLICY
from prwatch import github, worker
from prwatch.evaluate import evaluate

class Conflicts(unittest.TestCase):
    setUp=test_findings.Findings.setUp
    tearDown=test_findings.Findings.tearDown
    monitor=test_findings.Findings.monitor

    def conflict(self):
        s=snapshot();s['pr']['mergeable']=False
        s['pr']['base']={'ref':'main','sha':'base1'}
        return s

    def test_conflict_delivers_once_then_rearms_after_resolution(self):
        s=self.conflict();self.monitor(s)
        self.assertEqual(evaluate(s,POLICY)[0],'action_required')
        with patch.object(github,'snapshot',return_value=s):
            worker.deliver(self.db);self.monitor(s);worker.deliver(self.db)
        self.assertEqual(self.client.start.call_count,1)
        self.assertIn('Merge conflict',self.client.start.call_args.args[1])
        s['pr']['mergeable']=True;self.monitor(s)
        s['pr']['mergeable']=False;self.monitor(s)
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        self.assertEqual(self.client.start.call_count,2)

    def test_resolved_closed_or_changed_head_cancels_before_send(self):
        for change in ('resolved','closed','head'):
            with self.subTest(change=change):
                self.db.execute('DELETE FROM outbox');self.db.commit()
                s=self.conflict();self.monitor(s)
                if change=='resolved':s['pr']['mergeable']=True
                elif change=='closed':s['closed']=True
                else:s['head']='new-head'
                with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
                self.client.start.assert_not_called()
                self.assertIsNotNone(self.db.execute('SELECT cancelled FROM outbox').fetchone()[0])

    def test_unknown_never_sends_or_rearms_an_existing_conflict(self):
        s=self.conflict();self.monitor(s)
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        s['pr']['mergeable']=None;self.monitor(s)
        self.assertEqual(evaluate(s,POLICY)[0],'waiting')
        self.assertIsNone(self.db.execute('SELECT cancelled FROM outbox').fetchone()[0])
        s['pr']['mergeable']=False;self.monitor(s)
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        self.assertEqual(self.client.start.call_count,1)

    def test_unknown_during_delivery_defers(self):
        s=self.conflict();self.monitor(s);s['pr']['mergeable']=None
        with patch.object(github,'snapshot',return_value=s):worker.deliver(self.db)
        self.client.start.assert_not_called()
        row=self.db.execute('SELECT * FROM outbox').fetchone()
        self.assertIsNone(row['cancelled']);self.assertIsNone(row['delivered'])
