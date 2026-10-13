"""Codex packaging and shared-skill integration, without an LLM or user config."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodexPluginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package_temp = tempfile.TemporaryDirectory(prefix="ytstack package ")
        cls.package = Path(cls.package_temp.name).resolve() / "installed plugin"
        cls.package.mkdir()
        for name in (".codex-plugin", ".agents", "bin", "hooks", "skills", "codex"):
            shutil.copytree(ROOT / name, cls.package / name)
        # Copy exactly the vendor files that the shared wrappers import.
        for skill in (ROOT / "skills").glob("*/SKILL.md"):
            for relative in re.findall(r"vendor/[\w/-]+/SKILL\.md", skill.read_text()):
                target = cls.package / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)

    @classmethod
    def tearDownClass(cls):
        cls.package_temp.cleanup()

    def setUp(self):
        self.sandbox = tempfile.TemporaryDirectory(prefix="ytstack project ")
        self.addCleanup(self.sandbox.cleanup)
        self.project = Path(self.sandbox.name).resolve() / "project with spaces"
        self.project.mkdir()
        self.user_dir = Path(self.sandbox.name) / "test user"
        self.user_dir.mkdir()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("CLAUDE_", "YTSTACK_", "PLUGIN_"))}
        # Isolate the hooks' supported user-scope lookup from the real account.
        self.env["HOME"] = str(self.user_dir)
        self.env["PLUGIN_ROOT"] = str(self.package)
        self.helper = self.package / "bin/ytstack-codex"

    def run_skill(self, name, script, cwd=None, **kwargs):
        return subprocess.run(
            ["bash", str(self.helper), "skill", name], input=script,
            cwd=cwd or self.project, env=self.env, text=True, capture_output=True,
            **kwargs,
        )

    def fire_hook(self, event, cwd=None):
        cwd = cwd or self.project
        config = json.loads((self.package / "codex/hooks.json").read_text())
        handlers = config["hooks"][event][0]["hooks"]
        self.assertEqual(len(handlers), 1)
        payload = {
            "session_id": 'codex-session-"quoted"',
            "cwd": str(cwd), "hook_event_name": event,
            "source": "startup", "reason": "other",
        }
        result = subprocess.run(
            ["bash", "-c", handlers[0]["command"]],
            input=json.dumps(payload), cwd=cwd, env=self.env,
            text=True, capture_output=True, timeout=handlers[0]["timeout"],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def write_state(self, user_scope=False):
        if user_scope:
            directory = self.user_dir / ".ytstack/projects" / self.project.name
        else:
            directory = self.project / ".ytstack"
        directory.mkdir(parents=True)
        (directory / "STATE.md").write_text(
            "---\nproject: sample\ncurrent_milestone: M123\n"
            "active_slice: S02\nactive_task: T03\n---\n\n"
            "## Next action\nVerify the import.\n"
        )
        return directory

    def test_manifests_resolve_same_package_and_skills(self):
        manifest = json.loads((self.package / ".codex-plugin/plugin.json").read_text())
        claude = json.loads((ROOT / ".claude-plugin/plugin.json").read_text())
        for field in ("name", "version", "author", "repository", "license"):
            self.assertEqual(manifest[field], claude[field], field)
        marketplace = json.loads((self.package / ".agents/plugins/marketplace.json").read_text())
        entry = marketplace["plugins"][0]
        self.assertEqual(entry["name"], manifest["name"])
        self.assertEqual((self.package / entry["source"]["path"]).resolve(), self.package)
        skill_paths = sorted((self.package / manifest["skills"]).glob("*/SKILL.md"))
        self.assertEqual([p.parent.name for p in skill_paths],
                         sorted(p.parent.name for p in (ROOT / "skills").glob("*/SKILL.md")))
        self.assertEqual((self.package / manifest["skills"]).resolve(), self.package / "skills")
        hooks = json.loads((self.package / manifest["hooks"]).read_text())["hooks"]
        self.assertEqual(set(hooks), {"SessionStart", "PreCompact", "SessionEnd"})
        self.assertLessEqual(hooks["SessionEnd"][0]["hooks"][0]["timeout"], 3)

    def test_helper_uses_installed_skill_and_target_project(self):
        self.env.update(CLAUDE_PLUGIN_ROOT="/wrong-plugin", CLAUDE_PROJECT_DIR="/wrong-project",
                        CLAUDE_SKILL_DIR="/wrong-skill")
        result = self.run_skill("plan-task", 'printf "%s\\n" "$CLAUDE_PLUGIN_ROOT" "$CLAUDE_SKILL_DIR" "$CLAUDE_PROJECT_DIR"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            str(self.package), str(self.package / "skills/plan-task"),
            str(self.project),
        ])

    def test_wrapper_preambles_and_vendor_imports(self):
        self.write_state()
        imported = []
        for skill in (self.package / "skills").glob("*/SKILL.md"):
            blocks = re.findall(r"^```!\n(.*?)^```", skill.read_text(), re.M | re.S)
            if not blocks:
                continue
            with self.subTest(skill=skill.parent.name):
                context = self.run_skill(skill.parent.name, blocks[0])
                self.assertEqual(context.returncode, 0, context.stderr)
                self.assertIn("HAS_YTSTACK: yes", context.stdout)
                vendor = re.search(r"vendor/[\w/-]+/SKILL\.md", blocks[-1]).group()
                result = self.run_skill(skill.parent.name, blocks[-1])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, (ROOT / vendor).read_text())
                imported.append(skill.parent.name)
        self.assertEqual(len(imported), 6)

    def test_helper_rejects_missing_skill_and_path_traversal(self):
        for name in ("missing-skill", "../using-ytstack", "/tmp/skill"):
            with self.subTest(name=name):
                result = self.run_skill(name, "echo should-not-run")
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("should-not-run", result.stdout)

    def test_helper_propagates_failure(self):
        self.assertEqual(self.run_skill("plan-task", "exit 7").returncode, 7)

    def test_startup_greenfield_and_missing_state(self):
        output = json.loads(self.fire_hook("SessionStart"))["hookSpecificOutput"]
        self.assertEqual(output["hookEventName"], "SessionStart")
        self.assertIn("scope: greenfield", output["additionalContext"])
        self.assertIn(str(self.package), output["additionalContext"])
        self.assertIn((self.package / "codex/adapter.md").read_text(), output["additionalContext"])
        self.assertFalse((self.project / ".ytstack").exists())
        (self.project / ".ytstack").mkdir()
        output = json.loads(self.fire_hook("SessionStart"))["hookSpecificOutput"]
        self.assertIn("STATE.md is missing", output["additionalContext"])

    def test_lifecycle_preserves_state_and_records_session(self):
        for user_scope in (False, True):
            with self.subTest(user_scope=user_scope):
                directory = self.write_state(user_scope=user_scope)
                state = (directory / "STATE.md").read_bytes()
                output = json.loads(self.fire_hook("SessionStart"))["hookSpecificOutput"]
                self.assertIn("scope: user" if user_scope else "scope: project", output["additionalContext"])
                self.assertIn("M123 / S02 / T03", output["additionalContext"])
                self.assertIn("Verify the import.", output["additionalContext"])
                self.assertEqual(self.fire_hook("PreCompact"), "")
                handoff = (directory / "HANDOFF.md").read_text()
                self.assertIn("current_milestone: M123", handoff)
                self.assertNotIn("Claude Code was about", handoff)
                self.assertEqual(self.fire_hook("SessionEnd"), "")
                entry = json.loads((directory / "journal/sessions.jsonl").read_text())
                self.assertEqual(entry["session_id"], 'codex-session-"quoted"')
                self.assertEqual(entry["task"], "T03")
                self.assertEqual((directory / "STATE.md").read_bytes(), state)
                shutil.rmtree(directory)

    def test_side_effect_hooks_noop_without_state(self):
        self.assertEqual(self.fire_hook("PreCompact"), "")
        self.assertEqual(self.fire_hook("SessionEnd"), "")
        self.assertFalse((self.project / ".ytstack").exists())

    def test_lifecycle_from_repository_subdirectory(self):
        subprocess.run(["git", "init", "-q", str(self.project)], check=True, env=self.env)
        nested = self.project / "src/nested directory"
        nested.mkdir(parents=True)
        for user_scope in (False, True):
            with self.subTest(user_scope=user_scope):
                directory = self.write_state(user_scope=user_scope)
                state = (directory / "STATE.md").read_bytes()
                context = json.loads(self.fire_hook("SessionStart", cwd=nested))["hookSpecificOutput"]["additionalContext"]
                self.assertIn("scope: user" if user_scope else "scope: project", context)
                self.assertIn("M123 / S02 / T03", context)
                self.fire_hook("PreCompact", cwd=nested)
                self.assertIn("current_milestone: M123", (directory / "HANDOFF.md").read_text())
                self.fire_hook("SessionEnd", cwd=nested)
                entry = json.loads((directory / "journal/sessions.jsonl").read_text())
                self.assertEqual(entry["task"], "T03")
                self.assertEqual((directory / "STATE.md").read_bytes(), state)
                self.assertFalse((nested / ".ytstack").exists())
                shutil.rmtree(directory)

    def test_claude_startup_still_works(self):
        self.write_state()
        self.env.update(CLAUDE_PLUGIN_ROOT=str(self.package), CLAUDE_PROJECT_DIR=str(self.project))
        result = subprocess.run(
            ["bash", str(self.package / "hooks/session-start")],
            cwd=self.project, env=self.env, text=True, capture_output=True, check=True,
        )
        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("M123 / S02 / T03", context)
        self.assertIn("via the `Skill` tool", context)
        self.assertNotIn("Codex", context)

    def test_package_has_one_skill_and_hook_source(self):
        self.assertFalse((self.package / "codex/skills").exists())
        self.assertFalse((self.package / "codex/hooks").exists())
        self.assertFalse((self.package / "bin/build-codex").exists())
        for skill in (self.package / "skills").glob("*/SKILL.md"):
            self.assertNotIn("Codex", skill.read_text())

    def test_claude_wrapper_preambles_and_vendor_imports(self):
        self.write_state()
        for skill in (self.package / "skills").glob("*/SKILL.md"):
            self.assertNotIn("Codex", skill.read_text())
            blocks = re.findall(r"^```!\n(.*?)^```", skill.read_text(), re.M | re.S)
            if not blocks:
                continue
            with self.subTest(skill=skill.parent.name):
                env = dict(self.env, CLAUDE_PLUGIN_ROOT=str(self.package),
                           CLAUDE_SKILL_DIR=str(skill.parent), CLAUDE_PROJECT_DIR=str(self.project))
                context = subprocess.run(["bash"], input=blocks[0], cwd=self.project,
                                         env=env, text=True, capture_output=True, check=True)
                self.assertIn("HAS_YTSTACK: yes", context.stdout)
                result = subprocess.run(["bash"], input=blocks[-1], cwd=self.project,
                                        env=env, text=True, capture_output=True, check=True)
                vendor = re.search(r"vendor/[\w/-]+/SKILL\.md", blocks[-1]).group()
                self.assertEqual(result.stdout, (ROOT / vendor).read_text())

    def test_helper_uses_repository_root_for_relative_skill_writes(self):
        subprocess.run(["git", "init", "-q", str(self.project)], check=True, env=self.env)
        nested = self.project / "src/nested directory"
        nested.mkdir(parents=True)
        result = self.run_skill("plan-task", 'printf "%s\\n" "$CLAUDE_PROJECT_DIR" "$PWD"; echo ok > proof.txt', cwd=nested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.project), str(self.project)])
        self.assertEqual((self.project / "proof.txt").read_text(), "ok\n")
        self.assertFalse((nested / "proof.txt").exists())


if __name__ == "__main__":
    unittest.main()
