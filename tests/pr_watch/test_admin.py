"""ytstack-specific parts: state location, opt-in switch, migration of a local install."""
import io
import os
import sqlite3
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/pr-watch'))
from prwatch import admin, state


class Admin(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        clean = {k: v for k, v in os.environ.items()
                 if k not in ('PR_WATCH_HOME', 'YTSTACK_PR_WATCH_HOME', 'YTSTACK_PR_WATCH_CLI')}
        self.env = patch.dict(os.environ, {**clean, 'HOME': self.tmp.name}, clear=True)
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def quiet(self, fn, *args):
        with redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()):
            code = fn(*args)
        return code, out.getvalue()

    def test_state_root_and_overrides(self):
        self.assertEqual(state.home(), self.home / '.ytstack/pr-watch/state')
        os.environ['YTSTACK_PR_WATCH_HOME'] = str(self.home / 'custom')
        self.assertEqual(state.home(), self.home / 'custom/state')
        os.environ['PR_WATCH_HOME'] = str(self.home / 'direct')
        self.assertEqual(state.home(), self.home / 'direct')
        self.assertEqual(state.cli(), 'bin/ytstack-pr-watch')

    def test_enable_keeps_other_keys_and_disable_removes_only_the_switch(self):
        config = self.home / '.ytstack/config'
        config.parent.mkdir()
        config.write_text('other=1\npr_watch=off\n')
        self.assertEqual(self.quiet(admin.set_enabled, True)[0], 0)
        self.assertEqual(config.read_text(), 'other=1\npr_watch=on\n')
        self.quiet(admin.set_enabled, True)
        self.assertEqual(config.read_text().count('pr_watch'), 1)
        self.quiet(admin.set_enabled, False)
        self.assertEqual(config.read_text(), 'other=1\n')

    def test_migrate_copies_once_and_leaves_the_source_alone(self):
        source = self.home / 'old/state'
        source.mkdir(parents=True)
        os.environ['PR_WATCH_HOME'] = str(source)
        db = state.connect()
        with db:
            state.register(db, 'o/r', 4, 'claude:abc', '/tmp')
        # An open WAL connection, like a running old worker.
        (source / 'policy.json').write_text('{"defaults": {}}')

        def files():
            # Name and content of every source file, -wal and -shm included.
            return {p.name: p.read_bytes() for p in sorted(source.iterdir())}

        before = files()
        os.environ['PR_WATCH_HOME'] = str(self.home / 'new/state')
        code, out = self.quiet(admin.migrate, str(self.home / 'old'), False)
        self.assertEqual(code, 0)
        self.assertIn('Plan only', out)
        self.assertFalse((self.home / 'new').exists())
        code, out = self.quiet(admin.migrate, str(self.home / 'old'), True)
        self.assertEqual(code, 0, out)
        # Compared while the "old worker" connection is still open: what that
        # connection does to its own files on close is not migrate's doing.
        self.assertEqual(files(), before)
        db.close()
        copied = sqlite3.connect(str(self.home / 'new/state/watch.sqlite3'))
        self.assertEqual(copied.execute('SELECT session FROM watches').fetchone()[0], 'claude:abc')
        copied.close()
        self.assertTrue((self.home / 'new/state/policy.json').exists())
        self.assertEqual(self.quiet(admin.migrate, str(self.home / 'old'), True)[0], 2)


if __name__ == '__main__':
    unittest.main()
