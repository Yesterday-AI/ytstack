import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/pr-watch'))
from prwatch import github,worker
from prwatch.evaluate import evaluate
from prwatch.state import connect,register
from test_watch import snapshot,POLICY


def thread(resolved=False, actor='Bot', login='review-bot'):
    return {'id':'thread1','isResolved':resolved,'isOutdated':False,
            'comments':{'nodes':[{'url':'https://github.com/o/r/pull/1#discussion_r1',
                                 'author':{'login':login,'__typename':actor}}]}}


class Findings(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.env=patch.dict(os.environ,{'PR_WATCH_HOME':self.tmp.name});self.env.start()
        Path(self.tmp.name,'policy.json').write_text(json.dumps({'defaults':POLICY}))
        self.transport=patch('prwatch.worker.codex.Client');self.factory=self.transport.start()
        self.client=self.factory.return_value.__enter__.return_value
        self.client.status.return_value='idle';self.client.start.return_value='turn1'
        self.db=connect()
        with self.db:register(self.db,'o/r',1,'session','/tmp')

    def tearDown(self):
        self.db.close();self.transport.stop();self.env.stop();self.tmp.cleanup()

    def monitor(self,s):
        with patch.object(github,'snapshot',return_value=s):
            worker.monitor(self.db,self.db.execute('SELECT * FROM watches').fetchone())

    def test_only_unresolved_bot_threads_produce_events(self):
        s=snapshot();s['comments']=[{'id':1,'user':{'type':'Bot','login':'cursor'},'body':'summary','html_url':'url'}]
        s['threads']=[thread(True),{**thread(False,'User','human'),'id':'human'}]
        self.assertEqual(evaluate(s,POLICY)[2],[])
        s['threads'].append({**thread(),'isOutdated':True})
        self.assertEqual(len(evaluate(s,POLICY)[2]),1)

    def test_resolved_before_delivery_never_wakes_agent(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        with patch.object(github,'snapshot',return_value={**s,'threads':[thread(True)]}),patch.object(self.client,'start') as send:
            worker.deliver(self.db);send.assert_not_called()

    def test_bot_summary_and_quota_and_ready_are_silent(self):
        s=snapshot();s['comments']=[{'id':1,'user':{'type':'Bot','login':'cursor'},'body':'usage limit reached','html_url':'url'}]
        self.monitor(s)
        s['checks'][1]['conclusion']='neutral';self.monitor(s)
        with patch.object(self.client,'start') as send:
            worker.deliver(self.db);send.assert_not_called()

    def test_resolution_cancels_retry_and_reopening_notifies_once(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        with patch.object(github,'snapshot',return_value=s),patch.object(self.client,'start',return_value='ok') as send:
            worker.deliver(self.db);self.assertEqual(send.call_count,1)
            self.monitor(s);worker.deliver(self.db);self.assertEqual(send.call_count,1)
        s['threads']=[thread(True)];self.monitor(s)
        s['threads']=[thread()];self.monitor(s)
        with patch.object(github,'snapshot',return_value=s),patch.object(self.client,'start',return_value='ok') as send:
            worker.deliver(self.db);self.assertEqual(send.call_count,1)

    def test_failed_revalidation_keeps_notice_pending_without_sending(self):
        s=snapshot();s['threads']=[thread()];self.monitor(s)
        with patch.object(github,'snapshot',side_effect=github.APIError('offline')),patch.object(self.client,'start') as send:
            worker.deliver(self.db);send.assert_not_called()
        row=self.db.execute('SELECT * FROM outbox').fetchone()
        self.assertIsNone(row['cancelled']);self.assertIsNone(row['delivered'])
        self.assertEqual(row['error'],'APIError')

    def test_legacy_generic_bot_messages_are_cancelled(self):
        from prwatch.state import enqueue
        with self.db:
            watch=self.db.execute('SELECT * FROM watches').fetchone()
            enqueue(self.db,'bot:o/r:1:comments:old',watch,'old summary')
            enqueue(self.db,'state:o/r:1:ready',watch,'old ready message')
        with patch.object(self.client,'start') as send:
            worker.deliver(self.db);send.assert_not_called()
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM outbox WHERE cancelled IS NOT NULL').fetchone()[0],2)

    def test_ci_failure_still_notifies_without_bot_chatter(self):
        s=snapshot();s['checks'][0]['conclusion']='failure';self.monitor(s)
        with patch.object(github,'snapshot',return_value=s),patch.object(self.client,'start',return_value='ok') as send:
            worker.deliver(self.db)
            self.assertEqual(send.call_count,1)
            message=send.call_args.args[1]
            self.assertIn('tests',message)
            self.assertNotIn('Review completion',message)


if __name__=='__main__':unittest.main()
