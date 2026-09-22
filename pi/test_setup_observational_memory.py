"""Offline installer tests; no live Pi configuration or npm calls."""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from setup_observational_memory import check, configure


class ObservationalMemorySettingsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.agent = self.root / "agent"
        self.settings = self.agent / "settings.json"

    def configure(self):
        with redirect_stdout(io.StringIO()):
            configure(self.agent)

    def test_shared_config_preserves_unrelated_settings_and_is_idempotent(self):
        self.agent.mkdir()
        self.settings.write_text(json.dumps({"theme": "dark", "packages": ["npm:other@1.0.0"]}))

        self.configure()
        value = json.loads(self.settings.read_text())
        self.assertEqual(value["theme"], "dark")
        self.assertEqual(value["packages"], ["npm:other@1.0.0"])
        self.assertEqual(value["observational-memory"], {
            "compactAfterTokensMode": "ratio",
            "compactAfterTokensRatio": 0.5,
            "showWorkerNotifications": False,
        })
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)
        self.assertEqual(len(list(self.agent.glob("settings.json.bak.*"))), 1)

        original = self.settings.read_bytes()
        before = self.settings.stat().st_mtime_ns
        self.configure()
        self.assertEqual(self.settings.read_bytes(), original)
        self.assertEqual(self.settings.stat().st_mtime_ns, before)
        self.assertEqual(len(list(self.agent.glob("settings.json.bak.*"))), 1)

    def test_existing_configuration_is_replaced_by_shared_config(self):
        self.agent.mkdir()
        custom = {"observeAfterTokens": 12345, "showWorkerNotifications": True}
        self.settings.write_text(json.dumps({"observational-memory": custom}))
        self.configure()
        self.assertEqual(json.loads(self.settings.read_text())["observational-memory"], {
            "compactAfterTokensMode": "ratio",
            "compactAfterTokensRatio": 0.5,
            "showWorkerNotifications": False,
        })
        self.assertEqual(len(list(self.agent.glob("settings.json.bak.*"))), 1)

    def test_invalid_settings_are_rejected(self):
        self.agent.mkdir()
        for text in ["invalid", "[]", '{"observational-memory": null}', '{"observational-memory": false}']:
            self.settings.write_text(text)
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                check(self.agent)
            self.assertEqual(self.settings.read_text(), text)

    def test_existing_settings_symlink_is_preserved(self):
        self.agent.mkdir()
        private = self.root / "private-settings.json"
        private.write_text('{"theme":"light"}\n')
        self.settings.symlink_to(private)
        self.configure()
        self.assertTrue(self.settings.is_symlink())
        value = json.loads(private.read_text())
        self.assertEqual(value["theme"], "light")
        self.assertIn("observational-memory", value)

    def test_broken_settings_symlink_is_rejected(self):
        self.agent.mkdir()
        self.settings.symlink_to(self.root / "missing.json")
        with self.assertRaises(OSError):
            check(self.agent)
        self.assertTrue(self.settings.is_symlink())


class ObservationalMemorySetupScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.agent = self.root / "agent"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        pi = self.bin / "pi"
        pi.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/pi-invocations"\n')
        pi.chmod(0o755)
        self.env = {
            **os.environ,
            "HOME": str(self.root),
            "PI_CODING_AGENT_DIR": str(self.agent),
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
        }

    def run_setup(self):
        return subprocess.run(
            ["bash", str(Path(__file__).with_name("setup-observational-memory.sh"))],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_installs_pinned_package_and_applies_shared_settings(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = (self.root / "pi-invocations").read_text()
        self.assertIn("--no-approve install npm:pi-observational-memory@3.1.4", invocation)
        value = json.loads((self.agent / "settings.json").read_text())
        self.assertEqual(value["observational-memory"]["compactAfterTokensMode"], "ratio")

    def test_invalid_settings_stop_before_install(self):
        self.agent.mkdir()
        (self.agent / "settings.json").write_text("invalid")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "pi-invocations").exists())


if __name__ == "__main__":
    unittest.main()
