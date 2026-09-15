"""Offline setup checks: python3 -m unittest discover -s pi -p 'test_*.py'."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class McpSetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.agent = self.root / "agent"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "pi": 'printf "%s\\n" "$*" >> "$HOME/pi-invocations"',
            "npx": "exit 99",  # Setup must not start an MCP server.
        }.items():
            path = self.bin / name
            path.write_text(f"#!/bin/sh\n{body}\n")
            path.chmod(0o755)
        self.env = {
            **os.environ,
            "HOME": str(self.root),
            "PI_CODING_AGENT_DIR": str(self.agent),
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "GITHUB_PERSONAL_ACCESS_TOKEN": "test-secret-not-for-config",
        }

    def run_setup(self):
        return subprocess.run(
            ["bash", str(Path(__file__).with_name("setup-mcp.sh"))],
            env=self.env, capture_output=True, text=True,
        )

    def test_seed_and_repeat_preserve_customizations(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.agent / "mcp.json"
        config = json.loads(target.read_text())
        self.assertEqual(set(config["mcpServers"]), {"playwright", "GitHub"})
        self.assertTrue(config["settings"]["approveTools"])
        self.assertFalse(config["settings"]["scriptMode"])
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertNotIn(self.env["GITHUB_PERSONAL_ACCESS_TOKEN"], target.read_text())
        self.assertNotIn(self.env["GITHUB_PERSONAL_ACCESS_TOKEN"], result.stdout)
        target.write_text('{"mcpServers": {"private": {"url": "https://example.com"}}}\n')
        original = target.read_bytes()
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(target.read_bytes(), original)
        self.assertIn("install npm:pi-mcp-adapter@2.34.0", (self.root / "pi-invocations").read_text())

    def test_invalid_existing_config_stops_before_install(self):
        self.agent.mkdir()
        target = self.agent / "mcp.json"
        target.write_text("invalid json")
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertEqual(target.read_text(), "invalid json")
        self.assertFalse((self.root / "pi-invocations").exists())

    def test_existing_symlink_is_preserved(self):
        self.agent.mkdir()
        private = self.root / "private.json"
        private.write_text('{"mcpServers": {}}')
        target = self.agent / "mcp.json"
        target.symlink_to(private)
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertTrue(target.is_symlink())
        self.assertEqual(private.read_text(), '{"mcpServers": {}}')

    def test_broken_symlink_is_not_replaced(self):
        self.agent.mkdir()
        target = self.agent / "mcp.json"
        target.symlink_to(self.root / "missing.json")
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertTrue(target.is_symlink())
        self.assertFalse((self.root / "pi-invocations").exists())


if __name__ == "__main__":
    unittest.main()
