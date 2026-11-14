"""Setup commands: opt-in switch, background worker, migration of a local install.

Nothing here runs from a hook. Every command that writes outside the state
directory prints its plan and writes only with --yes.
"""
import os
import plistlib
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path
from .state import cli, connect, home, root

LABEL = 'com.ytstack.pr-watch'
CONFIG_KEY = 'pr_watch'
ENGINE = Path(__file__).resolve().parents[1] / 'pr-watch.py'


def config_path():
    return Path.home() / '.ytstack/config'


def set_enabled(on):
    """Set or remove pr_watch=on in ~/.ytstack/config, keeping every other line."""
    path = config_path()
    lines = path.read_text().splitlines() if path.exists() else []
    kept = [line for line in lines if line.split('=', 1)[0].strip() != CONFIG_KEY]
    if on:
        kept.append(f'{CONFIG_KEY}=on')
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(''.join(line + '\n' for line in kept))
    os.replace(tmp, path)
    if on:
        print(f'PR watch is on in {path}. New sessions in Claude Code and Codex register the PRs they create.')
        print(f'The background worker that polls GitHub is separate: {cli()} install-worker')
    else:
        print(f'PR watch is off in {path}. The hooks exit at once; state and the worker stay as they are.')
        print(f'Remove the worker with: {cli()} uninstall-worker --yes')
    return 0


# ---------- worker ----------

def launch_agents():
    return Path.home() / 'Library/LaunchAgents'


def own_plist():
    return launch_agents() / (LABEL + '.plist')


def launcher():
    return root() / 'bin/pr-watch'


def fallback_file():
    return root() / 'bin/engine-path'


LAUNCHER = r'''#!/bin/sh
# ytstack PR watch launcher, written by `ytstack-pr-watch install-worker`.
# Runs the engine of the ytstack Claude Code has installed (installPath in
# ~/.claude/plugins/installed_plugins.json, so a rolled-back version is not
# picked); without that, the newest cached version that is not marked
# .orphaned_at (Claude Code and Codex caches); last, the engine recorded at
# install.
export YTSTACK_PR_WATCH_HOME=%(home)s
active=$(%(python)s - <<'PY' 2>/dev/null
import json, os
try:
    plugins = json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json'))).get('plugins', {})
except Exception:
    plugins = {}
for name, installs in plugins.items():
    if name.split('@')[0] != 'ytstack':
        continue
    for i in installs if isinstance(installs, list) else [installs]:
        p = os.path.join(i.get('installPath', ''), 'tools/pr-watch/pr-watch.py')
        if os.path.isfile(p):
            print(p)
            raise SystemExit
PY
)
newest=$(
  for p in "$HOME"/.claude/plugins/cache/*/ytstack/*/tools/pr-watch/pr-watch.py \
           "$HOME"/.codex/plugins/cache/*/ytstack*/*/tools/pr-watch/pr-watch.py; do
    [ -f "$p" ] || continue
    d=$(dirname "$(dirname "$(dirname "$p")")")
    [ -e "$d/.orphaned_at" ] && continue
    printf '%%s\t%%s\n' "$(basename "$d")" "$p"
  done | sort -V -k1,1 | tail -1 | cut -f2-
)
engine=${active:-${newest:-$(cat "$(dirname "$0")/engine-path" 2>/dev/null)}}
[ -n "$engine" ] && [ -f "$engine" ] || { echo "ytstack pr-watch: no engine found" >&2; exit 1; }
export YTSTACK_PR_WATCH_CLI="$(dirname "$(dirname "$(dirname "$engine")")")/bin/ytstack-pr-watch"
exec %(python)s "$engine" "$@"
'''


def other_agents():
    folder = launch_agents()
    if not folder.is_dir():
        return []
    return sorted(p for p in folder.glob('*pr-watch*.plist') if p.name != own_plist().name)


BASE_PATH = ('/usr/bin', '/bin', '/usr/sbin', '/sbin')


def runs_alone(binary):
    """Whether `binary --version` works with nothing but its own directory and
    the system directories on PATH, as under launchd. A version-manager shim
    (asdf, mise, pyenv) fails here: it needs the manager itself on PATH."""
    path = ':'.join([str(Path(binary).parent), *BASE_PATH])
    try:
        return subprocess.run([binary, '--version'], capture_output=True, timeout=20,
                              env={'HOME': str(Path.home()), 'PATH': path}).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def find_gh():
    """The first `gh` on PATH that runs on its own; shims are skipped."""
    seen = set()
    for folder in os.environ.get('PATH', '').split(os.pathsep):
        candidate = Path(folder or '.') / 'gh'
        if not (candidate.is_file() and os.access(candidate, os.X_OK)):
            continue
        real = str(candidate.resolve())
        if real in seen:
            continue
        seen.add(real)
        if runs_alone(str(candidate)):
            return str(candidate)
    return None


def tool_dirs():
    gh = find_gh()
    dirs = []
    for path in (gh, sys.executable):
        if path:
            folder = str(Path(path).parent)
            if folder not in dirs:
                dirs.append(folder)
    for folder in BASE_PATH:
        if folder not in dirs:
            dirs.append(folder)
    return gh, ':'.join(dirs)


def systemd_recipe(remove=False):
    unit = Path('~/.config/systemd/user')
    if remove:
        print('No launchd on this system. To remove a systemd user timer set up from the recipe:')
        print('  systemctl --user disable --now ytstack-pr-watch.timer')
        print(f'  rm {unit}/ytstack-pr-watch.service {unit}/ytstack-pr-watch.timer')
        return 0
    print('No launchd on this system; nothing was written. A systemd user timer does the same job:')
    print(f'# {unit}/ytstack-pr-watch.service')
    print('[Unit]\nDescription=ytstack PR watch tick\n\n[Service]\nType=oneshot')
    print(f'Environment=YTSTACK_PR_WATCH_HOME={root()}')
    print(f'ExecStart={shlex.quote(sys.executable)} {shlex.quote(str(ENGINE))} tick\n')
    print(f'# {unit}/ytstack-pr-watch.timer')
    print('[Unit]\nDescription=ytstack PR watch every 60 s\n\n[Timer]\nOnBootSec=60\nOnUnitActiveSec=60\n\n'
          '[Install]\nWantedBy=timers.target\n')
    print('Then: systemctl --user daemon-reload && systemctl --user enable --now ytstack-pr-watch.timer')
    print('ExecStart points at this plugin version; after a ytstack update, point it at the new one.')
    return 0


def install_worker(yes):
    if sys.platform != 'darwin':
        return systemd_recipe()
    others = other_agents()
    if others:
        print('Another PR watch LaunchAgent is installed; two workers would poll and deliver twice:', file=sys.stderr)
        for p in others:
            print(f'  {p}', file=sys.stderr)
        print('Unload and remove it first: launchctl bootout gui/$(id -u)/<label>, then delete the plist.',
              file=sys.stderr)
        return 2
    gh, path = tool_dirs()
    if not gh:
        print('No gh (GitHub CLI) on PATH that runs on its own; the worker reads GitHub through it. '
              'A version-manager shim (asdf, mise) does not work under launchd: install gh from a '
              'package manager (for example Homebrew) or put the real binary first on PATH.', file=sys.stderr)
        return 2
    state = home()
    config = {'Label': LABEL, 'ProgramArguments': ['/bin/sh', str(launcher()), 'tick'],
              'RunAtLoad': True, 'StartInterval': 60, 'ProcessType': 'Background',
              'EnvironmentVariables': {'PATH': path},
              'StandardOutPath': str(state / 'service.log'), 'StandardErrorPath': str(state / 'service-error.log')}
    print(f'launcher     {launcher()} (runs the newest installed ytstack engine)')
    print(f'fallback     {fallback_file()} -> {ENGINE}')
    print(f'LaunchAgent  {own_plist()} (label {LABEL}, tick every 60 s, PATH {path})')
    print(f'logs         {state}/service.log, service-error.log')
    if not yes:
        print('Plan only, nothing written. Run again with --yes to install and load the worker.')
        return 0
    launcher().parent.mkdir(parents=True, exist_ok=True)
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    launcher().write_text(LAUNCHER % {'home': shlex.quote(str(root())), 'python': shlex.quote(sys.executable)})
    launcher().chmod(0o755)
    fallback_file().write_text(str(ENGINE) + '\n')
    own_plist().parent.mkdir(parents=True, exist_ok=True)
    domain = f'gui/{os.getuid()}'
    subprocess.run(['launchctl', 'bootout', f'{domain}/{LABEL}'], capture_output=True)
    own_plist().write_bytes(plistlib.dumps(config))
    result = subprocess.run(['launchctl', 'bootstrap', domain, str(own_plist())], capture_output=True, text=True)
    if result.returncode:
        print(f'launchctl bootstrap failed (exit {result.returncode}): {result.stderr.strip()}', file=sys.stderr)
        return 1
    print(f'Worker loaded as {domain}/{LABEL}. Check it with: {cli()} status (health.heartbeat)')
    return 0


def uninstall_worker(yes):
    if sys.platform != 'darwin':
        return systemd_recipe(remove=True)
    targets = [p for p in (own_plist(), launcher(), fallback_file()) if p.exists()]
    print(f'unload       gui/{os.getuid()}/{LABEL}')
    for p in targets:
        print(f'remove       {p}')
    print(f'keep         {home()} (state and policy)')
    if not yes:
        print('Plan only, nothing changed. Run again with --yes.')
        return 0
    subprocess.run(['launchctl', 'bootout', f'gui/{os.getuid()}/{LABEL}'], capture_output=True)
    for p in targets:
        p.unlink()
    print('Worker removed.')
    return 0


# ---------- migration ----------

def source_files(base):
    base = Path(base).expanduser().resolve()
    for folder in (base / 'state', base):
        if (folder / 'watch.sqlite3').is_file():
            return folder / 'watch.sqlite3', folder / 'policy.json'
    return None, None


def snapshot(db_path, scratch):
    # SQLite never opens the source: even a mode=ro connection takes part in WAL
    # housekeeping and may create or remove the source's -wal / -shm files, which
    # can split a still running writer from its WAL. The database file and its
    # -wal are copied byte-wise into a scratch dir and the copy is opened there,
    # where SQLite replays the WAL. Stop the old worker first (the printed steps);
    # integrity_check on the copy catches a torn copy.
    for suffix in ('', '-wal'):
        part = Path(str(db_path) + suffix)
        if part.is_file():
            shutil.copy2(part, scratch / (db_path.name + suffix))
    return sqlite3.connect(str(scratch / db_path.name), timeout=15)


def migrate(source, yes):
    db_path, policy_path = source_files(source)
    if not db_path:
        print(f'No watch.sqlite3 under {source} or {source}/state.', file=sys.stderr)
        return 2
    state = home()
    target = state / 'watch.sqlite3'
    if target.exists():
        print(f'{target} already exists; refusing to overwrite it. Move it away first if you mean to replace it.',
              file=sys.stderr)
        return 2
    scratch = Path(tempfile.mkdtemp(prefix='ytstack-pr-watch-migrate.'))
    try:
        return _migrate(db_path, policy_path, state, target, scratch, yes)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def _migrate(db_path, policy_path, state, target, scratch, yes):
    src = snapshot(db_path, scratch)
    try:
        counts = {t: src.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ('watches', 'outbox')}
        whole = src.execute('PRAGMA integrity_check').fetchone()[0]
    except sqlite3.DatabaseError as exc:
        src.close()
        print(f'{db_path} is not a PR watch database ({exc}).', file=sys.stderr)
        return 2
    if whole != 'ok':
        src.close()
        print(f'The copy of {db_path} is inconsistent ({whole}); stop the old worker and run migrate again.',
              file=sys.stderr)
        return 2
    copy_policy = policy_path.is_file() and not (state / 'policy.json').exists()
    print(f'copy         {db_path} -> {target} ({counts["watches"]} watches, {counts["outbox"]} outbox rows, SQLite backup)')
    if policy_path.is_file():
        print(f'copy         {policy_path} -> {state / "policy.json"}' if copy_policy
              else f'keep         {state / "policy.json"} (exists; {policy_path} not copied)')
    print('The source is only read. Anything the old worker or old hooks write after the copy stays behind,')
    print('so stop them first (steps 1 to 3 below).')
    if yes:
        state.mkdir(parents=True, exist_ok=True, mode=0o700)
        dst = sqlite3.connect(str(target))
        try:
            src.backup(dst)
        finally:
            dst.close()
            src.close()
        check = connect()
        ok = check.execute('PRAGMA integrity_check').fetchone()[0]
        check.close()
        if copy_policy:
            shutil.copy2(policy_path, state / 'policy.json')
        print(f'Copied; integrity_check: {ok}.')
    else:
        src.close()
        print('Plan only, nothing written. Run again with --yes.')
    print('Manual steps (this command changes none of them):')
    agents = other_agents() if sys.platform == 'darwin' else []
    labels = [plistlib.loads(p.read_bytes()).get('Label', p.stem) for p in agents] if agents else ['<old label>']
    for label in labels:
        print(f'  1. unload the old worker: launchctl bootout gui/$(id -u)/{label} and remove its plist')
    print('  2. remove the old `pr-watch hook --host claude` entries from ~/.claude/settings.json (back it up first)')
    print('  3. disable or remove the old Codex plugin pr-watch@local-pr-watch (Codex plugin settings)')
    print(f'  4. {cli()} enable, then {cli()} install-worker --yes')
    return 0
