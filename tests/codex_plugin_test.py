"""Codex packaging and shared-skill integration, without an LLM or user config.

Contract under test (since 0.2.0, DECISIONS 2026-11-07 "Hooks never write
relative to CLAUDE_PROJECT_DIR"): hooks resolve the checkout from the payload
`cwd`, user scope is keyed by the repository key (not the basename), the
automatic handoff and the session journal live out of tree under
`${PLUGIN_DATA:-$HOME/.local/state/ytstack}/repos/<key>/worktrees/<key>/sessions/<id>/`,
and PreCompact prints compaction guidance on stdout.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def without_comments(text):
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))


class CodexPluginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package_temp = tempfile.TemporaryDirectory(prefix="ytstack package ")
        cls.package = Path(cls.package_temp.name).resolve() / "installed plugin"
        cls.package.mkdir()
        for name in (".codex-plugin", ".agents", "bin", "hooks", "skills", "codex", "tools"):
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
                    if not key.startswith(("CLAUDE_", "YTSTACK_", "PLUGIN_", "XDG_"))}
        # Isolate the hooks' user-scope lookup and out-of-tree state from the real account.
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
            "source": "startup", "reason": "other", "trigger": "auto",
        }
        result = subprocess.run(
            ["bash", "-c", handlers[0]["command"]],
            input=json.dumps(payload), cwd=cwd, env=self.env,
            text=True, capture_output=True, timeout=handlers[0]["timeout"],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("integer expression", result.stderr)
        return result.stdout

    def repo_key(self, cwd=None):
        """The repository key the shared lib derives for a checkout (user scope + state dirs)."""
        result = subprocess.run(
            ["bash", "-c", f'. "{self.package}/hooks/lib/git-ctx.sh"; yt_git_ctx "$PWD"; printf %s "$YT_REPO_KEY"'],
            cwd=cwd or self.project, env=self.env, text=True, capture_output=True, check=True,
        )
        self.assertRegex(result.stdout, r"^[0-9a-f]{16}$")
        return result.stdout

    def write_state(self, user_scope=False):
        if user_scope:
            directory = self.user_dir / ".ytstack/projects" / self.repo_key()
        else:
            directory = self.project / ".ytstack"
        directory.mkdir(parents=True)
        (directory / "STATE.md").write_text(
            "---\nproject: sample\nlast_updated: 2026-11-07T12:00:00Z\ncurrent_milestone: M123\n"
            "active_slice: S02\nactive_task: T03\n---\n\n"
            "## Next action\nVerify the import.\n"
        )
        return directory

    def state_files(self, name):
        """Out-of-tree per-session files written by the hooks (never inside the checkout)."""
        return sorted((self.user_dir / ".local/state/ytstack").rglob(name))

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
        self.assertEqual(set(hooks), {"SessionStart", "PreCompact", "SessionEnd", "PreToolUse", "PostToolUse", "Stop"})
        self.assertLessEqual(hooks["SessionEnd"][0]["hooks"][0]["timeout"], 3)

    def pr_watch_handlers(self):
        """(event, matcher, handler) of every opt-in PR watch entry in codex/hooks.json."""
        config = json.loads((self.package / "codex/hooks.json").read_text())["hooks"]
        return [(event, entry.get("matcher"), handler)
                for event, entries in config.items() for entry in entries
                for handler in entry["hooks"] if handler["command"].endswith(" hook pr-watch")]

    def fire_pr_watch(self, handler, payload):
        return subprocess.run(
            ["bash", "-c", handler["command"]], input=payload, cwd=self.project, env=self.env,
            text=True, capture_output=True, timeout=handler["timeout"],
        )

    def test_pr_watch_entries_and_their_matchers(self):
        found = {event: matcher for event, matcher, _ in self.pr_watch_handlers()}
        self.assertEqual(found, {"SessionStart": None, "PreToolUse": "Bash|.*create_pull_request.*",
                                 "PostToolUse": "Bash|.*create_pull_request.*", "Stop": None})

    def test_pr_watch_is_silent_when_off(self):
        """Without pr_watch=on every entry exits 0 with no output, also with a broken payload."""
        for event, _, handler in self.pr_watch_handlers():
            for payload in (json.dumps({"session_id": "t1", "cwd": str(self.project), "hook_event_name": event}), "not json"):
                with self.subTest(event=event, payload=payload[:8]):
                    result = self.fire_pr_watch(handler, payload)
                    self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        self.assertFalse((self.user_dir / ".ytstack/pr-watch").exists())

    def test_pr_watch_runs_the_engine_when_on(self):
        (self.user_dir / ".ytstack").mkdir()
        (self.user_dir / ".ytstack/config").write_text("pr_watch=on\n")
        handlers = {event: handler for event, _, handler in self.pr_watch_handlers()}
        start = self.fire_pr_watch(handlers["SessionStart"], json.dumps(
            {"session_id": "t1", "cwd": str(self.project), "hook_event_name": "SessionStart"}))
        self.assertEqual(start.returncode, 0, start.stderr)
        context = json.loads(start.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("This session is t1.", context)
        self.assertIn(str(self.package / "bin/ytstack-pr-watch") + " create", context)
        self.assertNotIn("never woken", context)
        self.assertTrue((self.user_dir / ".ytstack/pr-watch/state/watch.sqlite3").exists())
        stop = self.fire_pr_watch(handlers["Stop"], json.dumps({"session_id": "t1", "hook_event_name": "Stop"}))
        self.assertEqual((stop.returncode, stop.stdout), (0, ""))
        broken = self.fire_pr_watch(handlers["PreToolUse"], "not json")
        self.assertEqual((broken.returncode, broken.stdout), (0, ""))
        self.assertIn("ytstack pr-watch: hook failed", broken.stderr)

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
        """Every skill with shell blocks runs its preamble through the helper; the six
        superpowers wrappers end in a vendor `cat` that renders the upstream file verbatim.
        The six skills adapted from gstack carry their procedure inline and have no
        vendor block (DECISIONS 2026-11-14)."""
        self.write_state()
        imported = []
        for skill in sorted((self.package / "skills").glob("*/SKILL.md")):
            blocks = re.findall(r"^```!\n(.*?)^```", skill.read_text(), re.M | re.S)
            if not blocks:
                continue
            with self.subTest(skill=skill.parent.name):
                context = self.run_skill(skill.parent.name, blocks[0])
                self.assertEqual(context.returncode, 0, context.stderr)
                self.assertIn("HAS_YTSTACK: yes", context.stdout)
                vendor = re.search(r"vendor/[\w/-]+/SKILL\.md", blocks[-1])
                if vendor is None:
                    continue
                result = self.run_skill(skill.parent.name, blocks[-1])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, (ROOT / vendor.group()).read_text())
                imported.append(skill.parent.name)
        self.assertEqual(sorted(imported), [
            "code-review", "finish-branch", "grill", "systematic-debugging",
            "test-driven-development", "verification-before-completion",
        ])

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

    def assert_lifecycle(self, directory, cwd=None):
        state = (directory / "STATE.md").read_bytes()
        context = json.loads(self.fire_hook("SessionStart", cwd=cwd))["hookSpecificOutput"]["additionalContext"]
        self.assertIn("M123 / S02 / T03", context)
        self.assertIn("Verify the import.", context)
        guidance = self.fire_hook("PreCompact", cwd=cwd)
        self.assertIn("compaction guidance", guidance)
        self.assertIn("M123 / S02 / T03", guidance)
        handoffs = self.state_files("HANDOFF.auto.md")
        self.assertEqual(len(handoffs), 1, handoffs)
        handoff = handoffs[0].read_text()
        self.assertIn("current_milestone: M123", handoff)
        self.assertNotIn("Claude Code was about", handoff)
        self.assertFalse((directory / "HANDOFF.md").exists(), "hooks never write the user-owned HANDOFF.md")
        self.assertEqual(self.fire_hook("SessionEnd", cwd=cwd), "")
        journals = self.state_files("session.jsonl")
        self.assertEqual(len(journals), 1, journals)
        entry = json.loads(journals[0].read_text())
        self.assertEqual(entry["session_id"], 'codex-session-"quoted"')
        self.assertEqual(entry["task"], "T03")
        self.assertFalse((directory / "journal").exists(), "no in-tree journal")
        self.assertEqual((directory / "STATE.md").read_bytes(), state)
        for path in handoffs + journals:
            path.unlink()

    def test_lifecycle_preserves_state_and_records_session(self):
        for user_scope in (False, True):
            with self.subTest(user_scope=user_scope):
                directory = self.write_state(user_scope=user_scope)
                context = json.loads(self.fire_hook("SessionStart"))["hookSpecificOutput"]["additionalContext"]
                self.assertIn("scope: user" if user_scope else "scope: project", context)
                self.assert_lifecycle(directory)
                shutil.rmtree(directory)

    def test_side_effect_hooks_noop_without_state(self):
        self.assertEqual(self.fire_hook("PreCompact"), "")
        self.assertEqual(self.fire_hook("SessionEnd"), "")
        self.assertFalse((self.project / ".ytstack").exists())
        self.assertEqual(self.state_files("HANDOFF.auto.md"), [])
        self.assertEqual(self.state_files("session.jsonl"), [])

    def test_lifecycle_from_repository_subdirectory(self):
        subprocess.run(["git", "init", "-q", str(self.project)], check=True, env=self.env)
        nested = self.project / "src/nested directory"
        nested.mkdir(parents=True)
        for user_scope in (False, True):
            with self.subTest(user_scope=user_scope):
                directory = self.write_state(user_scope=user_scope)
                context = json.loads(self.fire_hook("SessionStart", cwd=nested))["hookSpecificOutput"]["additionalContext"]
                self.assertIn("scope: user" if user_scope else "scope: project", context)
                self.assert_lifecycle(directory, cwd=nested)
                self.assertFalse((nested / ".ytstack").exists())
                shutil.rmtree(directory)

    def test_claude_startup_still_works(self):
        self.write_state()
        self.env.update(CLAUDE_PLUGIN_ROOT=str(self.package), CLAUDE_PROJECT_DIR=str(self.project))
        payload = json.dumps({"session_id": "claude-session", "cwd": str(self.project), "source": "startup"})
        result = subprocess.run(
            ["bash", str(self.package / "hooks/session-start")], input=payload,
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
            # Shell comments may name other hosts; instructions must not.
            self.assertNotIn("Codex", without_comments(skill.read_text()), skill)

    def test_claude_wrapper_preambles_and_vendor_imports(self):
        self.write_state()
        for skill in (self.package / "skills").glob("*/SKILL.md"):
            self.assertNotIn("Codex", without_comments(skill.read_text()), skill)
            blocks = re.findall(r"^```!\n(.*?)^```", skill.read_text(), re.M | re.S)
            if not blocks:
                continue
            with self.subTest(skill=skill.parent.name):
                env = dict(self.env, CLAUDE_PLUGIN_ROOT=str(self.package),
                           CLAUDE_SKILL_DIR=str(skill.parent), CLAUDE_PROJECT_DIR=str(self.project))
                context = subprocess.run(["bash"], input=blocks[0], cwd=self.project,
                                         env=env, text=True, capture_output=True, check=True)
                self.assertIn("HAS_YTSTACK: yes", context.stdout)
                vendor = re.search(r"vendor/[\w/-]+/SKILL\.md", blocks[-1])
                if vendor is None:
                    continue
                result = subprocess.run(["bash"], input=blocks[-1], cwd=self.project,
                                        env=env, text=True, capture_output=True, check=True)
                self.assertEqual(result.stdout, (ROOT / vendor.group()).read_text())

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
