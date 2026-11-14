"""Kimi native packaging and self-contained skill discovery, without an LLM."""

import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ADAPTED_SKILLS = (
    "office-hours",
    "plan-ceo-review",
    "plan-eng-review",
    "retro",
    "ship",
    "document-release",
)


class KimiPluginTests(unittest.TestCase):
    def setUp(self):
        self.sandbox = tempfile.TemporaryDirectory(prefix="ytstack kimi package ")
        self.addCleanup(self.sandbox.cleanup)
        base = Path(self.sandbox.name).resolve()
        self.package = base / "installed plugin with spaces"
        self.package.mkdir()
        shutil.copytree(ROOT / "skills", self.package / "skills")
        shutil.copytree(ROOT / "hooks", self.package / "hooks")
        for name in (".kimi-plugin", "kimi"):
            shutil.copytree(ROOT / name, self.package / name)

    def manifest(self):
        path = self.package / ".kimi-plugin/plugin.json"
        self.assertTrue(path.is_file(), "native Kimi manifest is missing")
        return json.loads(path.read_text())

    def test_native_manifest_uses_shared_skill_tree(self):
        manifest = self.manifest()
        claude = json.loads((ROOT / ".claude-plugin/plugin.json").read_text())
        for field in ("name", "version", "description", "author", "homepage", "repository", "license"):
            self.assertEqual(manifest[field], claude[field], field)

        self.assertIn("skills", manifest)
        skills = (self.package / manifest["skills"]).resolve()
        self.assertEqual(skills, self.package / "skills")
        exposed = sorted(path.parent.name for path in skills.glob("*/SKILL.md"))
        expected = sorted(path.parent.name for path in (ROOT / "skills").glob("*/SKILL.md"))
        self.assertEqual(exposed, expected)
        self.assertNotIn("extra_skill_dirs", manifest)
        self.assertFalse((self.package / "kimi/skills").exists())
        self.assertFalse((self.package / ".kimi-plugin/skills").exists())
        self.assertFalse((self.package / "gstack").exists())

        adapter = (self.package / manifest["systemPromptPath"]).resolve()
        self.assertTrue(adapter.is_file(), "the configured Kimi adapter is missing")
        startup = manifest["sessionStart"]["skill"]
        self.assertEqual(startup, "using-ytstack")
        self.assertTrue((skills / startup / "SKILL.md").is_file())

    def test_adapted_gstack_skills_need_no_external_install(self):
        manifest = self.manifest()
        adapter = (self.package / manifest["systemPromptPath"]).read_text()
        self.assertNotIn("extra_skill_dirs", adapter)
        self.assertNotIn("GSTACK_HOME", adapter)
        for name in ADAPTED_SKILLS:
            with self.subTest(skill=name):
                skill = self.package / "skills" / name / "SKILL.md"
                self.assertTrue(skill.is_file())
                text = skill.read_text()
                self.assertIn("upstream:", text)
                self.assertNotIn("GSTACK_HOME", text)


if __name__ == "__main__":
    unittest.main()
