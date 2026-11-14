import copy
import io
import json
import os
import sys
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ENGINE = Path(__file__).resolve().parents[2] / 'tools/pr-watch'
sys.path.insert(0, str(ENGINE))
from prwatch.evaluate import evaluate
from prwatch import github, hooks, worker
from prwatch.state import connect, register, enqueue

POLICY = {'review_policy_configured': True, 'reviewers': [{'login':'cursor', 'app':'cursor', 'check':'Cursor Bugbot'}]}


def snapshot():
    def check(id, name, app='github-actions'):
        return dict(id=id, name=name, app={'slug':app,'id':2 if app=='cursor' else 1}, head_sha='head2', status='completed', conclusion='success')
    return dict(head='head2', pr={'state':'open','mergeable':True}, checks=[check(1,'tests'),check(2,'Cursor Bugbot','cursor')],
                statuses=[], reviews=[], comments=[], inline=[], reactions=[], threads=[], required=[{'context':'tests','integration_id':1}])


class Readiness(unittest.TestCase):
    def test_positive_evidence_and_current_head(self):
        s=snapshot()
        self.assertEqual(evaluate(s,POLICY)[0],'ready')
        s['checks'][0]['head_sha']='head1'
        self.assertEqual(evaluate(s,POLICY)[0],'action_required')
        s['checks']=s['checks'][1:]
        self.assertEqual(evaluate(s,POLICY)[0],'waiting')

    def test_bot_absence_neutral_and_reactions_are_not_success(self):
        for conclusion in ('neutral','skipped','cancelled','failure','timed_out',None):
            with self.subTest(conclusion=conclusion):
                s=snapshot();s['checks'][1]['conclusion']=conclusion
                self.assertEqual(evaluate(s,POLICY)[0],'action_required')
        s=snapshot();s['checks']=s['checks'][:1]
        self.assertEqual(evaluate(s,POLICY)[0],'waiting')
        s=snapshot();s['reactions']=[{'content':'eyes','user':{'type':'Bot','login':'cursor'}}]
        self.assertEqual(evaluate(s,POLICY)[0],'waiting')
        self.assertEqual(evaluate(snapshot(),{})[0],'waiting')

    def test_old_reviews_wrong_app_and_unresolved_outdated_threads(self):
        p={'review_policy_configured':True,'reviewers':[{'login':'reviewer','completion':'review'}]}
        s=snapshot();s['reviews']=[dict(id=1,user={'login':'reviewer'},commit_id='head1',state='APPROVED',html_url='https://github.com/o/r/pull/1#review')]
        self.assertEqual(evaluate(s,p)[0],'waiting')
        s=snapshot();s['checks'][0]['app']['id']=99
        self.assertEqual(evaluate(s,POLICY)[0],'waiting')
        s=snapshot();s['threads']=[{'id':'a','isResolved':False,'isOutdated':True,'comments':{'nodes':[{'url':'url'}]}}]
        self.assertEqual(evaluate(s,POLICY)[0],'action_required')

    def test_rerun_replaces_old_failure_but_required_skip_never_passes(self):
        s=snapshot();old=copy.deepcopy(s['checks'][0]);old['id']=0;old['conclusion']='failure';s['checks'].append(old)
        self.assertEqual(evaluate(s,POLICY)[0],'ready')
        s['checks'][0]['conclusion']='skipped'
        self.assertEqual(evaluate(s,{**POLICY,'optional_skipped_checks':['tests']})[0],'action_required')


class DurableWorkflow(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.env=patch.dict(os.environ,{'PR_WATCH_HOME':self.tmp.name});self.env.start()
        Path(self.tmp.name,'policy.json').write_text(json.dumps({'defaults':POLICY}))
        self.db=connect()
        with self.db: register(self.db,'o/r',1,'session-a','/tmp')

    def tearDown(self):
        self.db.close();self.env.stop();self.tmp.cleanup()

    def watch(self):
        return self.db.execute('SELECT * FROM watches').fetchone()

    def test_push_invalidates_previous_readiness_without_comment_ack_gate(self):
        s=snapshot();s['comments']=[dict(id=12,user={'type':'Bot','login':'cursor'},body='summary',html_url='url')]
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        self.assertEqual(self.watch()['status'],'ready')
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM outbox').fetchone()[0],0)
        s['head']='head3'
        for c in s['checks']:c['head_sha']='head3'
        s['checks'][0]['status']='in_progress'
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        self.assertEqual(self.watch()['status'],'waiting')
        self.assertEqual(self.watch()['head'],'head3')

    def test_delivery_retry_persists_and_only_correct_session_is_targeted(self):
        s=snapshot();s['checks'][0]['conclusion']='failure'
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        with patch('prwatch.worker.codex.Client',side_effect=ConnectionError()):worker.deliver(self.db)
        self.assertEqual(self.db.execute('SELECT attempts FROM outbox').fetchone()[0],1)
        self.assertIsNone(self.db.execute('SELECT delivered FROM outbox').fetchone()[0])
        with self.db:self.db.execute('UPDATE outbox SET retry_at=0')
        self.db.close();self.db=connect()
        with patch('prwatch.worker.codex.Client') as factory,patch.object(github,'snapshot',return_value=s):
            client=factory.return_value.__enter__.return_value
            client.status.return_value='idle';client.start.return_value='turn-id'
            worker.deliver(self.db)
            self.assertEqual(client.start.call_args.args[0],'session-a')
            self.assertIn('CI tests: failure',client.start.call_args.args[1])
            worker.deliver(self.db);self.assertEqual(client.start.call_count,1)
        self.assertEqual(self.db.execute('SELECT turn_id FROM outbox').fetchone()[0],'turn-id')

    def test_ownership_never_stolen_and_errors_never_mark_ready(self):
        with self.assertRaises(ValueError):register(self.db,'o/r',1,'session-b','/tmp')
        with patch.object(github,'snapshot',side_effect=github.APIError('offline')):worker.monitor(self.db,self.watch())
        self.assertEqual(self.watch()['status'],'unavailable')
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM outbox').fetchone()[0],0)

    def test_creation_wrapper_persists_before_returning(self):
        repo=Path(self.tmp.name)/'repo';repo.mkdir()
        subprocess.run(['git','init','-q','-b','feat/test',str(repo)],check=True)
        subprocess.run(['git','-C',str(repo),'remote','add','origin','https://github.com/o/r.git'],check=True)
        bin_dir=Path(self.tmp.name)/'bin';bin_dir.mkdir()
        gh=bin_dir/'gh'
        gh.write_text('#!/bin/sh\nif [ "$1" = pr ]; then echo https://github.com/o/r/pull/2; else echo \'{"state":"open"}\'; fi\n')
        gh.chmod(0o755)
        cli=ENGINE/'pr-watch.py'
        result=subprocess.run([sys.executable,str(cli),'create','--repo','o/r','--session','session-a','--cwd',str(repo),'--','--title','test'],
                              capture_output=True,text=True,env={**os.environ,'PATH':str(bin_dir)+os.pathsep+os.environ['PATH']})
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.db.execute('SELECT session FROM watches WHERE number=2').fetchone()[0],'session-a')
        self.assertEqual(self.db.execute('SELECT branch FROM bindings').fetchone()[0],'feat/test')

    def test_pause_stops_notifications_and_batch_targets_one_session(self):
        s=snapshot();s['checks'][0]['conclusion']='failure'
        other={**s['checks'][0],'id':3,'name':'lint'};s['checks'].append(other)
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        with self.db:self.db.execute('UPDATE watches SET paused=1')
        with patch('prwatch.worker.codex.Client') as factory:
            worker.deliver(self.db);factory.assert_not_called()
        with self.db:self.db.execute('UPDATE watches SET paused=0')
        with patch('prwatch.worker.codex.Client') as factory,patch.object(github,'snapshot',return_value=s):
            client=factory.return_value.__enter__.return_value
            client.status.return_value='idle';client.start.return_value='turn-id'
            worker.deliver(self.db)
            self.assertEqual(client.start.call_count,1)
            self.assertIn('CI tests: failure',client.start.call_args.args[1])
            self.assertIn('CI lint: failure',client.start.call_args.args[1])

    def test_close_suppresses_queued_old_failure(self):
        with self.db:enqueue(self.db,'state:old',self.watch(),'old failing check')
        with patch.object(github,'snapshot',return_value={'head':'head2','closed':True}):
            worker.monitor(self.db,self.watch())
        self.assertIsNotNone(self.db.execute("SELECT cancelled FROM outbox WHERE event_key='state:old'").fetchone()[0])
        self.assertEqual(self.watch()['status'],'closed')

    def close(self,merged=False):
        pr={'state':'closed','merged_at':'2026-01-01T00:00:00Z' if merged else None}
        with patch.object(github,'snapshot',return_value={'head':'head2','closed':True,'pr':pr}):
            worker.monitor(self.db,self.watch())

    def test_closed_pr_is_never_snapshotted_but_comes_back_when_reopened(self):
        # Reopen detection costs one open-PR list per repository and REOPEN_CHECK, not a snapshot per closed watch.
        self.close()
        self.assertEqual(self.ticked(open_prs=[]),[])
        self.assertEqual(self.open_calls,1)
        self.assertEqual(self.watch()['status'],'closed')
        self.assertEqual(self.ticked(open_prs=[{'number':1}]),[])
        self.assertEqual(self.open_calls,0)   # within REOPEN_CHECK: no second list
        with self.db:self.db.execute("DELETE FROM meta WHERE key LIKE 'reopen_check:%'")
        self.ticked(open_prs=[{'number':1}])
        self.assertEqual(self.watch()['status'],'registered')
        self.assertEqual(self.ticked(),[1])   # read again on the next tick

    def test_merged_pr_is_never_checked_again(self):
        self.close(merged=True)
        self.assertEqual(self.ticked(open_prs=[{'number':1}]),[])
        self.assertEqual(self.open_calls,0)
        self.assertEqual(self.watch()['status'],'closed')

    def ticked(self,budget=None,open_prs=()):
        """Watch numbers one tick reads, with the quota answer `budget` (None: unknown);
        `open_prs` is what the open-PR list of a repository returns (calls in self.open_calls)."""
        seen=[]; self.open_calls=0
        def listing(repo):
            self.open_calls+=1
            return list(open_prs)
        with patch.object(worker,'discover'),patch.object(worker,'monitor',side_effect=lambda db,w:seen.append(w['number'])),\
             patch.object(worker,'deliver'),patch.object(worker,'spendable',return_value=budget),\
             patch.object(github,'open_pulls',side_effect=listing):
            worker.tick(send=False,reconcile=False)
        return seen

    def test_settled_prs_are_read_less_often(self):
        n=self.watch()['number']; now=time.time(); fresh=now-10; stale=now-worker.FAST_WINDOW-1
        for status,age,changed,expected in (('registered',10,None,[n]),('waiting',10,fresh,[n]),('waiting',10,stale,[]),
                                            ('waiting',10,None,[]),('waiting',worker.QUIET_INTERVAL+1,stale,[n]),
                                            ('ready',10,fresh,[]),('ready',worker.QUIET_INTERVAL+1,stale,[n]),
                                            ('action_required',10,fresh,[]),('unavailable',worker.QUIET_INTERVAL+1,None,[n])):
            with self.db:self.db.execute('UPDATE watches SET status=?,updated=?,changed_at=?',(status,now-age,changed))
            self.assertEqual(self.ticked(),expected,(status,age,changed))

    def test_changed_at_moves_only_on_a_change(self):
        s=snapshot()
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        first=self.watch()['changed_at']; self.assertIsNotNone(first)
        with self.db:self.db.execute('UPDATE watches SET changed_at=1')
        with patch.object(github,'snapshot',return_value=s):worker.monitor(self.db,self.watch())
        self.assertEqual(self.watch()['changed_at'],1)
        s2=snapshot();s2['head']='head3'
        for c in s2['checks']:c['head_sha']='head3'
        with patch.object(github,'snapshot',return_value=s2):worker.monitor(self.db,self.watch())
        self.assertGreater(self.watch()['changed_at'],1)

    def test_quota_reserve_stops_reading(self):
        with self.db:
            register(self.db,'o/r',2,'session-a','/tmp')
            self.db.execute("UPDATE watches SET status='waiting'")
        self.assertEqual(self.ticked(budget=0),[])
        self.assertEqual(len(self.ticked(budget=worker.SNAPSHOT_COST)),1)
        self.assertEqual(len(self.ticked(budget=2*worker.SNAPSHOT_COST)),2)
        self.assertEqual(len(self.ticked(budget=None)),2)

    def test_spendable_keeps_the_reserve_and_reports_it(self):
        rl={'resources':{'core':{'limit':5000,'remaining':1400,'reset':int(time.time())+600}}}
        with patch.object(github,'api',return_value=rl):
            self.assertEqual(worker.spendable(self.db),1400-1500)
        self.assertIn('1400/5000',self.db.execute("SELECT value FROM meta WHERE key='rate_limited'").fetchone()[0])
        rl['resources']['core']['remaining']=4000
        with patch.object(github,'api',return_value=rl):
            self.assertEqual(worker.spendable(self.db),2500)
        self.assertIsNone(self.db.execute("SELECT value FROM meta WHERE key='rate_limited'").fetchone())
        with patch.object(github,'api',side_effect=github.APIError('x')):
            self.assertIsNone(worker.spendable(self.db))

    def test_closed_long_ago_is_not_rechecked(self):
        self.close()
        old=time.time()-worker.REOPEN_WINDOW-1
        with self.db:self.db.execute('UPDATE watches SET updated=?,closed_at=?',(old,old))
        self.assertEqual(self.ticked(open_prs=[{'number':1}]),[])
        self.assertEqual(self.open_calls,0)

    def test_legacy_closed_rows_get_their_last_read_as_closing_time(self):
        # A state copied from an older install has no closed_at column; its
        # closed rows must not all come back as reopen checks.
        import sqlite3
        path=Path(self.tmp.name,'watch.sqlite3'); self.db.close(); path.unlink()
        for suffix in ('-wal','-shm'):
            Path(str(path)+suffix).unlink(missing_ok=True)
        legacy=sqlite3.connect(str(path))
        legacy.executescript("""CREATE TABLE watches (repo TEXT, number INTEGER, session TEXT, cwd TEXT, head TEXT DEFAULT '',
            status TEXT DEFAULT 'registered', detail TEXT DEFAULT '', updated REAL DEFAULT 0, paused INTEGER DEFAULT 0, PRIMARY KEY(repo, number));""")
        legacy.execute("INSERT INTO watches(repo,number,session,cwd,status,detail,updated) VALUES('o/r',1,'session-a','/tmp','closed','[]',?)",
                       (time.time()-30*86400,))
        legacy.execute("INSERT INTO watches(repo,number,session,cwd,status,updated) VALUES('o/r',2,'session-a','/tmp','waiting',0)")
        legacy.commit(); legacy.close()
        self.db=connect()
        self.assertEqual(self.db.execute("SELECT closed_at IS NOT NULL FROM watches WHERE number=1").fetchone()[0],1)
        self.assertEqual(self.ticked(open_prs=[{'number':1}]),[2])
        self.assertEqual(self.open_calls,0)

    def test_open_prs_are_paid_before_reopen_checks(self):
        self.close()
        with self.db:
            register(self.db,'o/r',2,'session-a','/tmp')
            self.db.execute("UPDATE watches SET status='waiting',updated=?,changed_at=? WHERE number=2",(time.time(),time.time()))
        self.assertEqual(self.ticked(budget=worker.SNAPSHOT_COST),[2])
        self.assertEqual(self.open_calls,0)
        self.assertEqual(self.ticked(budget=worker.SNAPSHOT_COST+1),[2])
        self.assertEqual(self.open_calls,1)

    def test_registering_again_revives_a_closed_watch(self):
        with patch.object(github,'snapshot',return_value={'head':'head2','closed':True}):
            worker.monitor(self.db,self.watch())
        w=self.watch()
        with self.db:register(self.db,w['repo'],w['number'],w['session'],w['cwd'])
        self.assertEqual(self.watch()['status'],'registered')

    def test_hook_captures_create_receipt_and_workdir_without_network(self):
        payload=dict(session_id='session-a',hook_event_name='PostToolUse',cwd='/tmp',tool_name='exec_command',
                     tool_input={'command':'gh pr create --title test','workdir':'/tmp/work'},
                     tool_response={'output':'https://github.com/o/r/pull/2'})
        with patch.object(hooks,'git_binding',return_value=('o/r','feat/test')):
            hooks.handle(payload)
        self.assertEqual(self.db.execute('SELECT number FROM candidates').fetchone()[0],2)
        self.assertEqual(self.db.execute('SELECT session FROM bindings').fetchone()[0],'session-a')
        payload['tool_input']['command']='gh pr view 2'
        payload['tool_response']['output']='https://github.com/o/r/pull/3'
        with patch.object(hooks,'git_binding',return_value=None):hooks.handle(payload)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM candidates').fetchone()[0],1)

    def test_ambiguous_sessions_do_not_claim_and_explicit_receipt_registers(self):
        with self.db:
            for session in ('a','b'):
                self.db.execute('INSERT INTO bindings VALUES(?,?,?,?,?,?)',('o/r','feat/x',session,'/tmp',time.time()-10,time.time()))
        pr=dict(head={'ref':'feat/x','repo':{'full_name':'o/r'}},number=2,created_at='2099-01-01T00:00:00Z',state='open',html_url='https://github.com/o/r/pull/2')
        with patch.object(github,'open_pulls',return_value=[pr]):worker.discover(self.db)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM watches').fetchone()[0],1)
        with self.db:self.db.execute('INSERT INTO candidates VALUES(?,?,?,?,?)',('o/r',2,'a','/tmp',0))
        with patch.object(github,'open_pulls',return_value=[]),patch.object(github,'api',return_value=pr):worker.discover(self.db)
        self.assertEqual(self.db.execute('SELECT session FROM watches WHERE number=2').fetchone()[0],'a')


class Pagination(unittest.TestCase):
    def test_snapshot_rejects_head_race(self):
        pr={'head':{'sha':'h1'},'base':{'ref':'main'},'state':'open'}
        responses=[pr,[],[],[],[],{'head':{'sha':'h2'},'state':'open'}]
        with patch.object(github,'api',side_effect=responses), patch.object(github,'run',return_value='[{"check_runs":[]}]'), patch.object(github,'review_threads',return_value=[]):
            with self.assertRaisesRegex(github.APIError,'changed while reading'):
                github.snapshot('o/r',1)

    def test_threads_all_pages_and_api_errors(self):
        def response(nodes,more,cursor):
            return {'data':{'repository':{'pullRequest':{'reviewThreads':{'nodes':nodes,'pageInfo':{'hasNextPage':more,'endCursor':cursor}}}}}}
        with patch.object(github,'api',side_effect=[response([{'id':'a'}],True,'c'),response([{'id':'b'}],False,None)]) as api:
            self.assertEqual(github.review_threads('o/r',1),[{'id':'a'},{'id':'b'}])
            self.assertEqual(api.call_args.kwargs['cursor'],'c')
        with patch.object(github,'api',return_value={'errors':[{}]}),self.assertRaises(github.APIError):github.review_threads('o/r',1)


if __name__=='__main__':unittest.main()
