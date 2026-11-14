"""Read-only GitHub adapter with exhaustive pagination and head consistency checks."""
import json
import os
import subprocess
from urllib.parse import quote


class APIError(RuntimeError):
    pass


def run(argv, cwd=None, timeout=40):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, 'GH_PROMPT_DISABLED': '1', 'GIT_TERMINAL_PROMPT': '0'})
    if result.returncode:
        # Never echo arbitrary command output: gh errors can contain credentials/URLs.
        raise APIError(f'{argv[0]} {argv[1]} failed (exit {result.returncode})')
    return result.stdout


def api(path, pages=False, **fields):
    args = ['gh', 'api', path]
    if pages:
        args += ['--paginate', '--slurp']
    for key, value in fields.items():
        args += ['-F', f'{key}={value}']
    value = json.loads(run(args))
    if pages:
        return [item for page in value for item in page]
    return value


def open_pulls(repo):
    return api(f'repos/{repo}/pulls?state=open&per_page=100', True)


def review_threads(repo, number):
    owner, name = repo.split('/')
    query = '''query($owner:String!,$name:String!,$number:Int!,$cursor:String){
      repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100,after:$cursor){
        nodes{id isResolved isOutdated comments(first:1){nodes{url author{login __typename}}}}
        pageInfo{hasNextPage endCursor}
      }}}
    }'''
    cursor = None
    result = []
    while True:
        fields = dict(query=query, owner=owner, name=name, number=number)
        if cursor:
            fields['cursor'] = cursor
        response = api('graphql', **fields)
        if response.get('errors'):
            raise APIError('GitHub review-thread query failed')
        connection = response['data']['repository']['pullRequest']['reviewThreads']
        result.extend(connection['nodes'])
        if not connection['pageInfo']['hasNextPage']:
            return result
        cursor = connection['pageInfo']['endCursor']


def base_identity(pr):
    base = pr.get('base', {})
    return (base.get('ref'), base.get('sha'), (base.get('repo') or {}).get('full_name'))


def snapshot(repo, number, notifications_only=False):
    prefix = f'repos/{repo}'
    pr = api(f'{prefix}/pulls/{number}')
    head = pr['head']['sha']
    if pr['state'] != 'open':
        return dict(pr=pr, head=head, closed=True)
    # A commit SHA, never a branch name, selects all check evidence.
    checks_pages = json.loads(run(['gh', 'api', f'{prefix}/commits/{head}/check-runs?per_page=100', '--paginate', '--slurp']))
    checks = [c for page in checks_pages for c in page['check_runs']]
    statuses = api(f'{prefix}/commits/{head}/statuses?per_page=100', True)
    threads = review_threads(repo, number)
    reviews, reactions, required = [], [], []
    if not notifications_only:
        reviews = api(f'{prefix}/pulls/{number}/reviews?per_page=100', True)
        reactions = api(f'{prefix}/issues/{number}/reactions?per_page=100', True)
        rules = api(f'{prefix}/rules/branches/{quote(pr["base"]["ref"], safe="")}', True)
        required = [c for rule in rules if rule['type'] == 'required_status_checks'
                    for c in rule['parameters']['required_status_checks']]
    current = api(f'{prefix}/pulls/{number}')
    if (current['head']['sha'] != head or current['state'] != 'open'
            or base_identity(current) != base_identity(pr)):
        raise APIError('PR changed while reading; retry required')
    return dict(pr=current, head=head, checks=checks, statuses=statuses, reviews=reviews,
                reactions=reactions, threads=threads, required=required)
