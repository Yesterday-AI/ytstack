"""Shared lifecycle output and native helper contracts for Kimi."""

from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class KimiLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = tempfile.TemporaryDirectory(prefix="ytstack kimi lifecycle ")
        self.addCleanup(self.sandbox.cleanup)
        base = Path(self.sandbox.name).resolve()
        self.package = base / "installed plugin with spaces"
        self.package.mkdir()
        shutil.copytree(ROOT / "hooks", self.package / "hooks")
        shutil.copytree(ROOT / "skills", self.package / "skills")
        for name in ("bin", ".kimi-plugin", "kimi"):
            if (ROOT / name).exists():
                shutil.copytree(ROOT / name, self.package / name)
        self.helper = self.package / "bin/ytstack-kimi"

        self.project = base / "target project with spaces"
        self.yt_dir = self.project / ".ytstack"
        self.yt_dir.mkdir(parents=True)
        (self.yt_dir / "STATE.md").write_text(
            "---\nproject: lifecycle-fixture\nlast_updated: 2026-11-14T10:00:00Z\n"
            "current_milestone: M020\nactive_slice: S02\nactive_task: T02\n---\n\n"
            "## Next action\nInject plain lifecycle context.\n"
        )
        self.home = base / "isolated home"
        self.home.mkdir()
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("CLAUDE_", "YTSTACK_", "PLUGIN_", "KIMI_"))
        }
        self.env.update(
            HOME=str(self.home), CLAUDE_PLUGIN_ROOT=str(self.package),
            KIMI_PLUGIN_ROOT=str(self.package),
            KIMI_CODE_HOME=str(self.home / "kimi home"),
        )

    def payload(self, event):
        event_name = {
            "session-start": "SessionStart",
            "pre-compact": "PreCompact",
            "post-compact": "PostCompact",
            "user-prompt-submit": "UserPromptSubmit",
            "session-end": "SessionEnd",
        }.get(event, event)
        payload = {
            "hook_event_name": event_name,
            "session_id": 'kimi-session-"quoted"',
            "client_type": "kimi_code_cli",
            "cwd": str(self.project),
        }
        if event_name == "SessionStart":
            payload["source"] = "startup"
        if event_name in ("PreCompact", "PostCompact"):
            payload["trigger"] = "auto"
        if event_name == "SessionEnd":
            payload["reason"] = "archive"
        if event_name == "UserPromptSubmit":
            payload["prompt"] = [{"type": "text", "text": "continue"}]
        return payload

    def run_hook(self, event, plain=True):
        env = dict(self.env)
        if plain:
            env["YTSTACK_HOOK_FORMAT"] = "plain"
        result = subprocess.run(
            ["bash", str(self.package / "hooks/session-start")],
            input=json.dumps(self.payload(event)), cwd=self.project, env=env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def run_helper(self, event):
        result = subprocess.run(
            ["bash", str(self.helper), "hook", event],
            input=json.dumps(self.payload(event)), cwd=self.package, env=self.env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def pending_files(self):
        root = self.home / ".local/state/ytstack"
        return sorted(root.rglob("pending-context.md")) if root.exists() else []

    def state_files(self, name):
        root = self.home / ".local/state/ytstack"
        return sorted(root.rglob(name)) if root.exists() else []

    def assert_plain_project_context(self, output):
        self.assertIn("[ytstack plugin root:", output)
        self.assertIn("# Running ytstack skills in Kimi Code", output)
        self.assertNotIn('"hookSpecificOutput"', output)
        self.assertIn("Project: lifecycle-fixture", output)
        self.assertIn("Current: M020 / S02 / T02", output)
        self.assertIn("Inject plain lifecycle context.", output)
        self.assertFalse((self.yt_dir / ".local").exists())

    def test_plain_session_start_context(self):
        self.assertTrue(self.run_hook("SessionStart").startswith("<EXTREMELY_IMPORTANT>"))
        self.assertIn("Project: lifecycle-fixture", self.run_hook("SessionStart"))

    def test_plain_user_prompt_submit_with_content_array(self):
        output = self.run_hook("UserPromptSubmit")
        self.assertTrue(output.startswith("<EXTREMELY_IMPORTANT>"))
        self.assertIn("Project: lifecycle-fixture", output)
        self.assertNotIn('"hookSpecificOutput"', output)
        self.assertFalse((self.yt_dir / ".local").exists())

    def test_helper_skill_uses_installed_root_and_target_project(self):
        env = dict(self.env, CLAUDE_PLUGIN_ROOT="/wrong", KIMI_PLUGIN_ROOT="/wrong")
        result = subprocess.run(
            ["bash", str(self.helper), "skill", "plan-task"],
            input='printf "%s\\n" "$CLAUDE_PLUGIN_ROOT" "$CLAUDE_SKILL_DIR" "$CLAUDE_PROJECT_DIR" "$PWD"\n',
            cwd=self.project, env=env, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            str(self.package), str(self.package / "skills/plan-task"),
            str(self.project), str(self.project),
        ])

    def test_pending_context_prepare_and_consume_once(self):
        self.assertEqual(self.run_helper("session-start"), "")
        pending = self.pending_files()
        self.assertEqual(len(pending), 1, pending)
        self.assertIn("Project: lifecycle-fixture", pending[0].read_text())
        first = self.run_helper("user-prompt-submit")
        self.assert_plain_project_context(first)
        self.assertEqual(self.pending_files(), [])
        self.assertEqual(self.run_helper("user-prompt-submit"), "")

    def test_no_pending_prompt_is_silent(self):
        self.assertEqual(self.run_helper("user-prompt-submit"), "")
        self.assertFalse((self.yt_dir / ".local").exists())

    def test_post_compact_rearms_pending_context(self):
        self.run_helper("session-start")
        self.run_helper("user-prompt-submit")
        self.assertEqual(self.run_helper("post-compact"), "")
        self.assertEqual(len(self.pending_files()), 1)
        self.assert_plain_project_context(self.run_helper("user-prompt-submit"))

    def test_parallel_prompts_consume_pending_once(self):
        self.run_helper("session-start")
        with ThreadPoolExecutor(max_workers=2) as pool:
            outputs = list(pool.map(lambda _: self.run_helper("user-prompt-submit"), range(2)))
        self.assertEqual(sum(bool(output) for output in outputs), 1, outputs)
        self.assertIn("Project: lifecycle-fixture", next(output for output in outputs if output))
        self.assertEqual(self.pending_files(), [])

    def test_precompact_handoff_and_sessionend_journal(self):
        self.assertEqual(self.run_helper("pre-compact"), "")
        handoffs = self.state_files("HANDOFF.auto.md")
        self.assertEqual(len(handoffs), 1, handoffs)
        self.assertIn("trigger: auto", handoffs[0].read_text())
        self.assertIn("active_task: T02", handoffs[0].read_text())

        self.assertEqual(self.run_helper("session-end"), "")
        journals = self.state_files("session.jsonl")
        self.assertEqual(len(journals), 1, journals)
        entry = json.loads(journals[0].read_text())
        self.assertEqual(entry["session_id"], 'kimi-session-"quoted"')
        self.assertEqual(entry["reason"], "archive")
        self.assertEqual(entry["task"], "T02")
        self.assertFalse((self.yt_dir / "journal").exists())

    def test_manifest_registers_five_native_lifecycle_hooks(self):
        manifest_path = self.package / ".kimi-plugin/plugin.json"
        self.assertTrue(manifest_path.is_file())
        manifest = json.loads(manifest_path.read_text())
        self.assertIn("hooks", manifest)
        hooks = manifest["hooks"]
        self.assertEqual(
            {rule["event"] for rule in hooks},
            {"SessionStart", "PreCompact", "PostCompact", "UserPromptSubmit", "SessionEnd"},
        )
        for rule in hooks:
            with self.subTest(event=rule["event"]):
                self.assertIn('"${KIMI_PLUGIN_ROOT}/bin/ytstack-kimi"', rule["command"])
                self.assertIn("hook ", rule["command"])
                self.assertGreaterEqual(rule["timeout"], 1)
                self.assertLessEqual(rule["timeout"], 10)


if __name__ == "__main__":
    unittest.main()
