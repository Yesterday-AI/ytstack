"""Pure current-head readiness policy; missing evidence is never a pass."""
import hashlib
import json
import re


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:20]


def bot(user, policy):
    names = {b['login'].removesuffix('[bot]') for b in policy.get('reviewers', [])}
    return user.get('type', user.get('__typename')) == 'Bot' or user.get('login', '').endswith('[bot]') or user.get('login', '') in names


def evaluate(s, policy):
    if s.get('closed'):
        return 'closed', [], []
    issues, pending, events = [], [], []
    if s['pr'].get('mergeable') is False:
        issues.append('Merge conflict with base branch')
    elif s['pr'].get('mergeable') is not True:
        pending.append('Mergeability not yet known')
    latest = {}
    for c in s['checks']:
        key = (c['name'], c['app']['id'])
        if key not in latest or c['id'] > latest[key]['id']:
            latest[key] = c
    statuses = {}
    for c in s['statuses']:
        if c['context'] not in statuses or c['id'] > statuses[c['context']]['id']:
            statuses[c['context']] = c
    required_names = {c['context'] for c in s['required']}
    for need in s['required']:
        matches = [c for (name, app), c in latest.items()
                   if name == need['context'] and (not need.get('integration_id') or app == need['integration_id'])]
        status = statuses.get(need['context']) if not need.get('integration_id') else None
        if not matches and status is None:
            pending.append('Required check missing: ' + need['context'])
    optional_skips = set(policy.get('optional_skipped_checks', []))
    labels = {label['name'] for label in s['pr'].get('labels', [])}
    for condition in policy.get('label_required_checks', []):
        if condition['label'] in labels:
            name = condition['name']
            optional_skips.discard(name)
            required_names.add(name)
            if not any(c['name'] == name for c in latest.values()) and name not in statuses:
                pending.append('Label-required check missing: ' + name)
    for c in latest.values():
        name = c['name']
        if c['head_sha'] != s['head']:
            issues.append('Check SHA mismatch: ' + name)
        elif c['status'] != 'completed':
            pending.append('Check running: ' + name)
        elif c['conclusion'] == 'success':
            pass
        elif c['conclusion'] == 'skipped' and name in optional_skips and name not in required_names:
            pass
        else:
            issues.append(f'Check {name}: {c["conclusion"]}')
    for name, c in statuses.items():
        if c['state'] == 'pending':
            pending.append('Status pending: ' + name)
        elif c['state'] != 'success':
            issues.append(f'Status {name}: {c["state"]}')
    if not latest and not statuses:
        pending.append('No CI evidence for current head')
    if not policy.get('review_policy_configured'):
        pending.append('Expected review bots not configured for this repository')
    for reviewer in policy.get('reviewers', []):
        login = reviewer['login'].removesuffix('[bot]')
        completed = any(c['name'] == reviewer.get('check') and c['app']['slug'] == reviewer.get('app')
                        and c['status'] == 'completed' and c['conclusion'] == 'success' for c in latest.values())
        # Reviews are positive completion evidence only when explicitly opted in.
        if reviewer.get('completion') == 'review':
            current_reviews = [r for r in s['reviews']
                               if r['user']['login'].removesuffix('[bot]') == login and r['commit_id'] == s['head']
                               and r['state'] in ('APPROVED', 'COMMENTED', 'CHANGES_REQUESTED')]
            latest_review = max(current_reviews, key=lambda r: r['id'], default=None)
            unavailable = latest_review and re.search(
                r"usage limit|rate limit|quota|couldn.t run|no reviewable files|review.{0,20}(?:skipped|failed)",
                latest_review.get('body', ''), re.IGNORECASE)
            completed = latest_review is not None and not unavailable
            if unavailable:
                issues.append('Bot review unavailable: ' + login)
        if not completed:
            pending.append(f'Review completion missing: {login}')
    if any(r['content'] == 'eyes' and bot(r['user'], policy) for r in s['reactions']):
        pending.append('Bot eyes reaction still present')
    for thread in s['threads']:
        if not thread['isResolved']:
            nodes = thread['comments']['nodes']
            issues.append('Unresolved review thread: ' + (nodes[0]['url'] if nodes else thread['id']))
    for r in s['reviews']:
        if r['commit_id'] == s['head'] and r['state'] == 'CHANGES_REQUESTED':
            issues.append('Changes requested: ' + r['user']['login'])
    events = unresolved_findings(s['threads'], policy)
    return ('action_required' if issues else 'waiting' if pending else 'ready'), issues + pending, events


def unresolved_findings(threads, policy):
    events = []
    for thread in threads:
        nodes = thread['comments']['nodes']
        author = nodes[0].get('author') if nodes else None
        if not thread['isResolved'] and author and bot(author, policy):
            events.append((thread['id'], f'Unresolved bot finding ({author["login"]}): {nodes[0]["url"]}'))
    return events


def failed_ci(s, policy):
    reviewers = {name for r in policy.get('reviewers', []) for name in (r.get('app'), r['login'].removesuffix('[bot]'))}
    latest = {}
    for c in s.get('checks', []):
        key = (c['name'], c['app']['id'])
        if key not in latest or c['id'] > latest[key]['id']:
            latest[key] = c
    failures = []
    for c in latest.values():
        if (c['app']['slug'] not in reviewers and c['head_sha'] == s['head'] and c['status'] == 'completed'
                and c['conclusion'] in ('failure', 'timed_out', 'cancelled', 'action_required', 'startup_failure', 'stale')):
            failures.append((f'check:{c["id"]}', f'CI {c["name"]}: {c["conclusion"]}'))
    statuses = {}
    for c in s.get('statuses', []):
        if c['context'] not in statuses or c['id'] > statuses[c['context']]['id']:
            statuses[c['context']] = c
    for c in statuses.values():
        if c['state'] in ('error', 'failure') and c.get('creator', {}).get('login', '').removesuffix('[bot]') not in reviewers:
            failures.append((f'status:{c["id"]}', f'CI {c["context"]}: {c["state"]}'))
    return failures


def notification_events(s, policy, repo, number):
    if s.get('closed'):
        return {}
    events = {f'bot-thread:{repo}:{number}:{key}': summary
              for key, summary in unresolved_findings(s['threads'], policy)}
    events.update({f'ci:{repo}:{number}:{s["head"]}:{key}': summary
                   for key, summary in failed_ci(s, policy)})
    if s['pr'].get('mergeable') is False:
        events[f'conflict:{repo}:{number}:{s["head"]}'] = 'Merge conflict with base branch; the PR cannot be merged cleanly.'
    return events


def conflict_unknown(s, key, repo, number):
    return (not s.get('closed') and s['pr'].get('mergeable') is None
            and key == f'conflict:{repo}:{number}:{s["head"]}')
