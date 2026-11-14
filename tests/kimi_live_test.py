"""Native Kimi installation and skill activation using only local fixtures."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
ADAPTED_SKILLS = (
    "office-hours",
    "plan-ceo-review",
    "plan-eng-review",
    "retro",
    "ship",
    "document-release",
)


class FakeModelHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        self.server.requests.append({"path": self.path, "body": raw.decode(errors="replace")})
        chunks = (
            {"id": "fake", "object": "chat.completion.chunk", "created": 0, "model": "fake",
             "choices": [{"index": 0, "delta": {"role": "assistant", "content": "OK"}, "finish_reason": None}]},
            {"id": "fake", "object": "chat.completion.chunk", "created": 0, "model": "fake",
             "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]},
        )
        body = "".join(f"data: {json.dumps(chunk)}\n\n" for chunk in chunks) + "data: [DONE]\n\n"
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, *args):
        pass


class KimiLiveTests(unittest.TestCase):
    def setUp(self):
        binary = os.environ.get("KIMI_BIN")
        if binary:
            if not os.access(binary, os.X_OK):
                self.skipTest(f"KIMI_BIN is not executable: {binary}")
            self.kimi_bin = str(Path(binary).resolve())
        else:
            binary = shutil.which("kimi")
            if binary is None:
                self.skipTest("Kimi CLI is not installed")
            self.kimi_bin = binary
        self.sandbox = tempfile.TemporaryDirectory(prefix="ytstack kimi live ")
        self.addCleanup(self.sandbox.cleanup)
        base = Path(self.sandbox.name).resolve()
        self.package = base / "source plugin with spaces"
        self.package.mkdir()
        for name in (".kimi-plugin", "kimi", "skills", "hooks", "bin"):
            shutil.copytree(ROOT / name, self.package / name)

        self.project = base / "target project with spaces"
        self.home = base / "isolated home"
        self.kimi_home = base / "fresh kimi home"
        self.project.mkdir()
        self.home.mkdir()
        self.kimi_home.mkdir()
        self.process = None

        self.model_server = ThreadingHTTPServer(("127.0.0.1", 0), FakeModelHandler)
        self.model_server.daemon_threads = True
        self.model_server.requests = []
        threading.Thread(target=self.model_server.serve_forever, daemon=True).start()
        self.addCleanup(self._stop_model)

    def _stop_model(self):
        self.model_server.shutdown()
        self.model_server.server_close()

    def _stop_kimi(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.communicate()

    def _request(self, method, path, body=None):
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            self.base + path, data=data, method=method,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            self.fail(f"{method} {path}: HTTP {error.code}: {error.read().decode()}")

    def start_kimi(self):
        model_port = self.model_server.server_address[1]
        (self.kimi_home / "config.toml").write_text(f'''default_model = "test/fake"
telemetry = false

[providers.test]
type = "openai"
base_url = "http://127.0.0.1:{model_port}/v1"
api_key = "test-only-no-secret"

[models."test/fake"]
provider = "test"
model = "fake"
max_context_size = 262144
capabilities = ["tool_use"]

[loop_control]
max_attempts_per_step = 1
''')
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        self.base = f"http://127.0.0.1:{port}"
        env = {
            key: value for key, value in os.environ.items()
            if not any(part in key.upper() for part in ("KEY", "TOKEN", "SECRET", "PASSWORD", "CREDENTIAL"))
            and not key.startswith(("CLAUDE_", "YTSTACK_", "PLUGIN_", "KIMI_"))
        }
        env.update(HOME=str(self.home), KIMI_CODE_HOME=str(self.kimi_home))
        self.env = env
        self.process = subprocess.Popen(
            [self.kimi_bin, "web", "--no-open", "--port", str(port),
             "--dangerous-bypass-auth", "--log-level", "silent"],
            cwd=self.project, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
        )
        self.addCleanup(self._stop_kimi)
        for _ in range(200):
            if self.process.poll() is not None:
                stdout, stderr = self.process.communicate()
                self.fail(f"Kimi server exited early: {stdout}\n{stderr}")
            try:
                self._request("GET", "/api/v1/meta")
                break
            except (OSError, urllib.error.URLError):
                time.sleep(0.1)
        else:
            self._stop_kimi()
            stdout, stderr = self.process.communicate()
            logs = {
                str(path): path.read_text(errors="replace")[-4000:]
                for path in self.kimi_home.rglob("*.log")
            }
            self.fail(json.dumps({
                "error": "Kimi server did not become ready",
                "stdout": stdout, "stderr": stderr, "logs": logs,
            })[:16000])

        installed = self._request("POST", "/api/v1/plugins", {"source": str(self.package)})
        self.assertEqual(installed["code"], 0, installed)
        self.installed = installed["data"]
        session = self._request("POST", "/api/v1/sessions", {
            "title": "ytstack native integration test",
            "metadata": {"cwd": str(self.project)},
            "agent_config": {"model": "test/fake", "permission_mode": "auto"},
        })
        self.assertEqual(session["code"], 0, session)
        self.session_id = session["data"]["id"]
        profile = self._request("POST", f"/api/v1/sessions/{self.session_id}/profile", {
            "agent_config": {"model": "test/fake", "permission_mode": "auto"},
        })
        self.assertEqual(profile["code"], 0, profile)

    def skills(self):
        result = self._request("GET", f"/api/v1/sessions/{self.session_id}/skills")
        self.assertEqual(result["code"], 0, result)
        return result["data"]["skills"]

    def activate(self, name):
        route = f"/api/v1/sessions/{self.session_id}/skills/{urllib.parse.quote(name, safe='')}:activate"
        result = self._request("POST", route, {"args": ""})
        self.assertEqual(result["code"], 0, result)
        self.assertEqual(result["data"], {"activated": True, "skill_name": name})
        self.wait_idle(f"Skill activation did not finish: {name}")

    def wait_idle(self, message):
        for _ in range(100):
            state = self._request("GET", f"/api/v1/sessions/{self.session_id}")["data"]
            if not state.get("busy") and not state.get("main_turn_active"):
                return
            time.sleep(0.1)
        self.fail(message)

    def submit_prompt(self, text):
        result = self._request("POST", f"/api/v1/sessions/{self.session_id}/prompts", {
            "content": [{"type": "text", "text": text}],
        })
        self.assertEqual(result["code"], 0, result)
        self.wait_idle("Prompt did not finish")

    def state_files(self, name):
        root = self.home / ".local/state/ytstack"
        return sorted(root.rglob(name)) if root.exists() else []

    def wait_pending(self):
        for _ in range(100):
            pending = self.state_files("pending-context.md")
            if pending:
                return pending
            time.sleep(0.1)
        self.fail("Kimi did not prepare pending context")

    def model_received_since(self, marker, start):
        return any(marker in request["body"] for request in self.model_server.requests[start:])

    def interactive_exit(self):
        master, slave = pty.openpty()
        env = dict(self.env, TERM="xterm-256color")
        process = subprocess.Popen(
            [self.kimi_bin, "--session", self.session_id],
            stdin=slave, stdout=slave, stderr=slave, cwd=self.project,
            env=env, close_fds=True,
        )
        os.close(slave)
        output = bytearray()
        sent = 0
        trusted = False
        send_at = time.monotonic() + 2
        second_at = None
        deadline = time.monotonic() + 30
        try:
            while process.poll() is None and time.monotonic() < deadline:
                if not trusted and b"Trust and continue" in output:
                    os.write(master, b"\r")
                    trusted = True
                    output.clear()
                    send_at = time.monotonic() + 1
                elif sent == 0 and trusted and time.monotonic() >= send_at and "❯".encode() in output:
                    os.write(master, b"\x03")
                    sent = 1
                    second_at = time.monotonic() + 0.2
                elif sent == 1 and time.monotonic() >= second_at:
                    os.write(master, b"\x03")
                    sent = 2
                readable, _, _ = select.select([master], [], [], 0.1)
                if not readable:
                    continue
                try:
                    chunk = os.read(master, 8192)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            if process.poll() is None:
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    process.wait(timeout=5)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            os.close(master)
        self.assertGreater(sent, 0, output.decode(errors="replace")[-6000:])
        self.assertEqual(process.returncode, 0, output.decode(errors="replace")[-6000:])
        return output.decode(errors="replace")

    def activations(self):
        result = self._request("GET", f"/api/v1/sessions/{self.session_id}/messages")
        self.assertEqual(result["code"], 0, result)
        activated = []
        for message in result["data"]["items"]:
            for content in message.get("content", []):
                if content.get("type") != "text":
                    continue
                text = content["text"]
                match = re.search(r'<skill-loaded name="([^"]+)"[^>]*dir="([^"]+)"', text)
                if match:
                    activated.append((match.group(1), Path(match.group(2)).resolve(), text))
        return activated

    def test_native_install_exposes_all_skills_with_namespace(self):
        self.start_kimi()
        expected = sorted(path.parent.name for path in (ROOT / "skills").glob("*/SKILL.md"))
        self.assertEqual(self.installed["state"], "ok")
        self.assertFalse(self.installed["hasErrors"])
        self.assertEqual(self.installed["skillCount"], len(expected))
        managed = Path(self.installed["root"]).resolve()
        self.assertTrue(managed.is_relative_to(self.kimi_home))

        catalog = self.skills()
        by_name = {skill["name"]: skill for skill in catalog}
        self.assertNotIn("plan-task", by_name)
        for name in expected:
            with self.subTest(skill=name):
                qualified = f"ytstack:{name}"
                self.assertIn(qualified, by_name)
                path = Path(by_name[qualified]["path"]).resolve()
                self.assertEqual(path, managed / "skills" / name / "SKILL.md")
                self.assertTrue(path.is_file())

    def test_adapted_gstack_skills_activate_from_native_plugin(self):
        self.start_kimi()
        managed = Path(self.installed["root"]).resolve()
        by_name = {skill["name"]: skill for skill in self.skills()}
        for name in ADAPTED_SKILLS:
            qualified = f"ytstack:{name}"
            self.assertIn(qualified, by_name)
            self.assertNotIn(name, by_name)
            self.assertEqual(
                Path(by_name[qualified]["path"]).resolve(),
                managed / "skills" / name / "SKILL.md",
            )
            self.activate(qualified)

        activated = self.activations()
        for name in ADAPTED_SKILLS:
            with self.subTest(skill=name):
                qualified = f"ytstack:{name}"
                matches = [item for item in activated if item[0] == qualified]
                self.assertEqual(len(matches), 1)
                self.assertEqual(matches[0][1], managed / "skills" / name)
                self.assertNotIn("GSTACK_HOME", matches[0][2])

    def test_project_override_does_not_replace_namespaced_plugin_skill(self):
        subprocess.run(["git", "init", "-q", str(self.project)], check=True)
        override = self.project / ".kimi-code/skills/ship"
        override.mkdir(parents=True)
        (override / "SKILL.md").write_text(
            "---\nname: ship\ndescription: Project override fixture\n---\n\nPROJECT_OVERRIDE_ship\n"
        )
        self.start_kimi()
        by_name = {skill["name"]: skill for skill in self.skills()}
        self.assertEqual(Path(by_name["ship"]["path"]).resolve(), override / "SKILL.md")
        managed = Path(self.installed["root"]).resolve()
        self.assertEqual(
            Path(by_name["ytstack:ship"]["path"]).resolve(),
            managed / "skills/ship/SKILL.md",
        )

        self.activate("ytstack:ship")
        self.activate("ship")
        activated = self.activations()
        plugin = [item for item in activated if item[0] == "ytstack:ship"]
        project = [item for item in activated if item[0] == "ship"]
        self.assertEqual(len(plugin), 1)
        self.assertEqual(plugin[0][1], managed / "skills/ship")
        self.assertNotIn("PROJECT_OVERRIDE_ship", plugin[0][2])
        self.assertEqual(len(project), 1)
        self.assertEqual(project[0][1], override.resolve())
        self.assertIn("PROJECT_OVERRIDE_ship", project[0][2])

    def test_native_lifecycle_context_compaction_resume_and_close(self):
        yt_dir = self.project / ".ytstack"
        yt_dir.mkdir()
        (yt_dir / "STATE.md").write_text(
            "---\nproject: native-lifecycle\nlast_updated: 2026-11-14T11:00:00Z\n"
            "current_milestone: M020\nactive_slice: S02\nactive_task: T03\n---\n\n"
            "## Next action\nNATIVE_PENDING_MARKER\n"
        )
        self.start_kimi()
        self.assertEqual(self.installed["state"], "ok")
        self.assertFalse(self.installed["hasErrors"])
        self.assertEqual(self.installed["hookCount"], 5)

        pending = self.wait_pending()
        self.assertIn("NATIVE_PENDING_MARKER", pending[0].read_text())
        self.submit_prompt("first native prompt")
        if not self.model_received_since("NATIVE_PENDING_MARKER", 0):
            messages = self._request("GET", f"/api/v1/sessions/{self.session_id}/messages")
            diagnostics = {
                "requests": self.model_server.requests,
                "pending": [str(path) for path in self.state_files("pending-context.md")],
                "messages_tail": json.dumps(messages)[-8000:],
            }
            self.fail(json.dumps(diagnostics)[:20000])
        self.assertEqual(self.state_files("pending-context.md"), [])

        before = len(self.model_server.requests)
        self.submit_prompt("second native prompt")
        latest = json.loads(self.model_server.requests[-1]["body"])
        users = [message for message in latest.get("messages", []) if message.get("role") == "user"]
        self.assertTrue(users)
        self.assertNotIn("NATIVE_PENDING_MARKER", json.dumps(users[-1].get("content")))

        compacted = self._request("POST", f"/api/v1/sessions/{self.session_id}:compact", {})
        self.assertEqual(compacted["code"], 0, compacted)
        self.wait_idle("Compaction did not finish")
        handoffs = self.state_files("HANDOFF.auto.md")
        self.assertEqual(len(handoffs), 1, handoffs)
        self.assertIn("trigger: manual", handoffs[0].read_text())
        self.assertIn("active_task: T03", handoffs[0].read_text())
        self.wait_pending()

        before = len(self.model_server.requests)
        self.submit_prompt("after compaction")
        self.assertTrue(self.model_received_since("NATIVE_PENDING_MARKER", before))
        self.assertEqual(self.state_files("pending-context.md"), [])

        self._stop_kimi()
        before = len(self.model_server.requests)
        resumed = subprocess.run(
            [self.kimi_bin, "--session", self.session_id, "-p", "resume native lifecycle"],
            cwd=self.project, env=self.env, text=True, capture_output=True, timeout=30,
        )
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertTrue(self.model_received_since("NATIVE_PENDING_MARKER", before))
        pending_after = self.state_files("pending-context.md")
        if pending_after:
            sources = {
                str(path): path.read_text(errors="replace")[-6000:]
                for pattern in ("*.log", "wire.jsonl")
                for path in self.kimi_home.rglob(pattern)
            }
            self.fail(json.dumps({
                "pending": [str(path) for path in pending_after],
                "stdout": resumed.stdout, "stderr": resumed.stderr,
                "new_requests": self.model_server.requests[before:],
                "sources": sources,
            })[:24000])

        self.interactive_exit()

        entries = [
            json.loads(line)
            for journal in self.state_files("session.jsonl")
            for line in journal.read_text().splitlines()
        ]
        self.assertTrue(any(
            entry["session_id"] == self.session_id
            and entry["reason"] == "exit" and entry["task"] == "T03"
            for entry in entries
        ), entries)
        self.assertFalse((yt_dir / "journal").exists())

    def test_verification_preamble_survives_kimi_placeholders(self):
        self.start_kimi()
        self.activate("ytstack:verification-before-completion")
        matches = [
            item for item in self.activations()
            if item[0] == "ytstack:verification-before-completion"
        ]
        self.assertEqual(len(matches), 1)
        skill_dir = matches[0][1]
        blocks = re.findall(r"^```!\n(.*?)^```", matches[0][2], re.M | re.S)
        self.assertTrue(blocks)

        yt_dir = self.project / ".ytstack"
        yt_dir.mkdir()
        (yt_dir / "STATE.md").write_text(
            "---\nproject: fixture\nlast_updated: 2026-11-14T10:00:00Z\n"
            "current_milestone: M020\nactive_slice: S01\nactive_task: T02\n---\n"
        )
        (yt_dir / "M020-S01-T02-PLAN.md").write_text(
            "## Verification\n\n```bash\nprintf 'verification-ok\\n'\n```\n"
        )
        env = dict(
            self.env,
            CLAUDE_PLUGIN_ROOT=str(Path(self.installed["root"]).resolve()),
            CLAUDE_SKILL_DIR=str(skill_dir),
            CLAUDE_PROJECT_DIR=str(self.project),
        )
        result = subprocess.run(
            ["bash"], input=blocks[0], cwd=self.project, env=env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("VERIFICATION_CMD_FOUND: yes", result.stdout, result.stdout + result.stderr)
        self.assertIn("printf 'verification-ok\\n'", result.stdout)
        self.assertEqual(result.stderr, "")

    def test_reconcile_count_survives_kimi_placeholders(self):
        self.start_kimi()
        self.activate("ytstack:reconcile")
        match = [item for item in self.activations() if item[0] == "ytstack:reconcile"]
        self.assertEqual(len(match), 1)
        function = re.search(r"^_count\(\).*$", match[0][2], re.M)
        self.assertIsNotNone(function)
        result = subprocess.run(
            ["bash"], input=function.group() + "\n_count $'alpha\\nbeta'\n",
            cwd=self.project, env=self.env, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "2")
        self.assertEqual(result.stderr, "")

    def test_spawn_overlap_survives_kimi_placeholders(self):
        self.start_kimi()
        self.activate("ytstack:spawn-milestone-team")
        match = [item for item in self.activations() if item[0] == "ytstack:spawn-milestone-team"]
        self.assertEqual(len(match), 1)
        assignment = re.search(r"^[ \t]*_OVERLAP=.*$", match[0][2], re.M)
        self.assertIsNotNone(assignment)
        rows = self.project / "overlap rows"
        rows.write_text("S01 skills/example.py\nS02 skills/example.py\n")
        script = f'_TMPF="$TMPF"\n{assignment.group()}\nprintf \'%s\\n\' "$_OVERLAP"\n'
        result = subprocess.run(
            ["bash"], input=script, cwd=self.project,
            env=dict(self.env, TMPF=str(rows)), text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "skills/example.py: S01 S02")
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
