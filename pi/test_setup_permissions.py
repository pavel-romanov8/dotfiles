"""Offline installer tests; no live Pi configuration or npm calls."""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest

from setup_permissions import configure, validate_policy


class PermissionSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.agent = Path(self.temp.name) / "agent"
        self.policy = self.agent / "permissions.json"
        self.extension = self.agent / "extensions" / "dotfiles-permissions"

    def setup(self):
        with redirect_stdout(io.StringIO()):
            configure(self.agent)

    def test_seed_private_policy_and_idempotent_link(self):
        self.setup()
        self.assertTrue(self.extension.is_symlink())
        self.assertTrue((self.extension / "index.ts").is_file())
        policy = validate_policy(self.policy.read_text())
        self.assertNotIn("*", policy["permission"])
        self.assertNotIn("edit", policy["permission"])
        self.assertEqual(policy["permission"]["bash"]["rm"], "ask")
        self.assertEqual(self.policy.stat().st_mode & 0o777, 0o600)
        original = self.policy.read_bytes()
        before = self.policy.stat().st_mtime_ns
        self.setup()
        self.assertEqual(self.policy.read_bytes(), original)
        self.assertEqual(self.policy.stat().st_mtime_ns, before)
        self.assertFalse((self.agent / "settings.json").exists())

    def test_existing_policy_and_unrelated_extensions_preserved(self):
        self.extension.parent.mkdir(parents=True)
        other = self.extension.parent / "other.ts"
        other.write_text("export default function() {}")
        self.policy.write_text('{"permission":{"*":"deny"}}')
        original = self.policy.read_bytes()
        self.setup()
        self.assertEqual(self.policy.read_bytes(), original)
        self.assertTrue(other.is_file())

    def test_invalid_policy_prevents_extension_install(self):
        self.agent.mkdir()
        for text in ["oops", '[]', '{"permission":{"*":"alow"}}']:
            self.policy.write_text(text)
            with self.assertRaises(ValueError):
                self.setup()
            self.assertEqual(self.policy.read_text(), text)
            self.assertFalse(self.extension.exists())

    def test_conflicting_extension_is_not_replaced(self):
        self.extension.mkdir(parents=True)
        with self.assertRaises(ValueError):
            self.setup()
        self.assertTrue(self.extension.is_dir())
        self.assertFalse(self.extension.is_symlink())
        self.assertFalse(self.policy.exists())

    def test_existing_policy_symlink_preserved(self):
        self.agent.mkdir()
        private = self.agent / "private.json"
        private.write_text(json.dumps({"permission": {"*": "ask"}}))
        self.policy.symlink_to(private)
        self.setup()
        self.assertTrue(self.policy.is_symlink())
        self.assertEqual(json.loads(private.read_text()), {"permission": {"*": "ask"}})

    def test_broken_policy_symlink_is_not_replaced(self):
        self.agent.mkdir()
        self.policy.symlink_to(self.agent / "missing.json")
        with self.assertRaises(OSError):
            self.setup()
        self.assertTrue(self.policy.is_symlink())
        self.assertFalse(self.extension.exists())


if __name__ == "__main__":
    unittest.main()
