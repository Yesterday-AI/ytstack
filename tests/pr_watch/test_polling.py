import copy
import time
import unittest
from unittest.mock import patch
import test_findings
from prwatch import github, worker, hooks

class Polling(unittest.TestCase):
    setUp=test_findings.Findings.setUp
    tearDown=test_findings.Findings.tearDown

    def test_discovery_fetches_once_per_repo_and_excludes_forks(self):
        with self.db:
            for branch in ('feat/a','feat/b'):
                self.db.execute('INSERT INTO bindings VALUES(?,?,?,?,?,?)',('o/r',branch,'session','/tmp',time.time()-10,time.time()))
        def pr(n,branch,repo):
            return dict(number=n,head={'ref':branch,'repo':{'full_name':repo}},state='open',created_at='2099-01-01T00:00:00Z')
        prs=[pr(2,'feat/a','fork/r'),pr(3,'feat/b','o/r')]
        with patch.object(github,'open_pulls',return_value=prs) as listing,patch.object(github,'api',return_value=prs[1]) as detail:
            worker.discover(self.db)
        listing.assert_called_once_with('o/r');detail.assert_called_once()
        self.assertEqual([r['number'] for r in self.db.execute('SELECT number FROM watches ORDER BY number')],[1,3])

    def test_stop_does_no_git_or_database_work(self):
        with patch.object(hooks,'git_binding') as git,patch.object(hooks,'connect') as db:
            self.assertEqual(hooks.handle({'session_id':'s','hook_event_name':'Stop','cwd':'/tmp'}),{})
            git.assert_not_called();db.assert_not_called()

    def test_snapshot_request_budget_and_base_race(self):
        pr={'state':'open','head':{'sha':'head'},'base':{'ref':'main','sha':'base'},'mergeable':True}
        for lean,expected in ((False,8),(True,5)):
            with self.subTest(lean=lean):
                paths=[]
                def api(path,*args,**kwargs):
                    paths.append(path)
                    return pr if path.endswith('/pulls/1') else []
                with patch.object(github,'api',side_effect=api),patch.object(github,'run',return_value='[{"check_runs":[]}]'),patch.object(github,'review_threads',return_value=[]):
                    github.snapshot('o/r',1,notifications_only=lean)
                self.assertEqual(len(paths)+2,expected) # one check-runs and one review-thread request
                self.assertFalse(any('/comments' in path for path in paths))
        changed=copy.deepcopy(pr);changed['base']['sha']='base2'
        with patch.object(github,'api',side_effect=[pr,[],changed]),patch.object(github,'run',return_value='[{"check_runs":[]}]'),patch.object(github,'review_threads',return_value=[]):
            with self.assertRaises(github.APIError):github.snapshot('o/r',1,notifications_only=True)
