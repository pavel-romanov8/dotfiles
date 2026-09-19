#!/usr/bin/env python3
import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from typing import Dict, Optional, Union

ROOT = Path(__file__).resolve().parent
FF = ROOT / "bin" / "ff"
ENV_MODULE = ROOT / "modules" / "10-environment"
SSH_HELPER = ROOT / "lib" / "ssh_hosts.py"
DOCKER_MODULE = ROOT / "modules" / "30-docker"


def run(
    *args: Union[str, Path], env: Optional[Dict[str, str]] = None
) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(arg) for arg in args],
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )


class LauncherTests(unittest.TestCase):
    def test_list_exposes_only_the_three_initial_workflows(self) -> None:
        result = run(FF, "--list")
        titles = [line.split("\t", 1)[0] for line in result.stdout.splitlines()]
        self.assertEqual(
            titles,
            ["Environment variables", "SSH hosts", "Docker containers"],
        )


class EnvironmentTests(unittest.TestCase):
    def test_list_contains_names_but_never_values(self) -> None:
        env = os.environ.copy()
        env["FF_TEST_SECRET_TOKEN"] = "do-not-print-this-value"

        result = run(ENV_MODULE, "--list", env=env)

        self.assertIn("FF_TEST_SECRET_TOKEN\t", result.stdout)
        self.assertNotIn("do-not-print-this-value", result.stdout)

    def test_sensitive_preview_is_masked_until_explicitly_revealed(self) -> None:
        env = os.environ.copy()
        env["FF_TEST_SECRET_TOKEN"] = "do-not-print-this-value"

        masked = run(ENV_MODULE, "--preview", "FF_TEST_SECRET_TOKEN", env=env)
        revealed = run(
            ENV_MODULE,
            "--preview-reveal",
            "FF_TEST_SECRET_TOKEN",
            env=env,
        )

        self.assertIn("[masked", masked.stdout)
        self.assertNotIn("do-not-print-this-value", masked.stdout)
        self.assertIn("do-not-print-this-value", revealed.stdout)


class SshHostTests(unittest.TestCase):
    def test_recursive_includes_known_hosts_and_wildcard_filtering(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            ssh_dir = home / ".ssh"
            include_dir = ssh_dir / "config.d"
            include_dir.mkdir(parents=True)
            (ssh_dir / "config").write_text(
                textwrap.dedent(
                    """\
                    Include config.d/*
                    Host direct-alias *.wildcard !negated
                      HostName direct.example.com
                    """
                )
            )
            (include_dir / "work").write_text(
                "Host included-alias\n  HostName included.example.com\n"
            )
            (ssh_dir / "known_hosts").write_text(
                "known.example ssh-ed25519 AAAA\n"
                "[port.example]:2222 ssh-ed25519 BBBB\n"
                "|1|hashed|entry ssh-ed25519 CCCC\n"
            )
            env = os.environ.copy()
            env["HOME"] = str(home)

            result = run("python3", SSH_HELPER, env=env)
            hosts = {line.split("\t", 1)[0] for line in result.stdout.splitlines()}

            self.assertIn("direct-alias", hosts)
            self.assertIn("included-alias", hosts)
            self.assertIn("known.example", hosts)
            self.assertIn("port.example", hosts)
            self.assertNotIn("*.wildcard", hosts)
            self.assertNotIn("!negated", hosts)
            self.assertFalse(any(host.startswith("|1|") for host in hosts))


class DockerTests(unittest.TestCase):
    def test_list_and_preview_use_stable_hidden_id_and_sanitize_logs(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            bin_dir = Path(temp)
            docker = bin_dir / "docker"
            docker.write_text(
                textwrap.dedent(
                    """\
                    #!/usr/bin/env bash
                    case "$1" in
                      ps)
                        printf 'abcdef123456\\tapi\\tservice:latest\\tUp 2 minutes\\t127.0.0.1:8080->80/tcp\\n'
                        ;;
                      inspect)
                        case "$3" in
                          *RestartCount*)
                            printf 'Name\\t/api\\nImage\\tservice:latest\\nState\\trunning\\nStarted\\tnow\\nRestart count\\t0\\n'
                            ;;
                          *State.Running*) printf 'true\\n' ;;
                          *Name*) printf '/api\\n' ;;
                        esac
                        ;;
                      logs)
                        printf '\\033[31mhello from container\\033[0m\\n'
                        ;;
                      info) exit 0 ;;
                      *) exit 1 ;;
                    esac
                    """
                )
            )
            docker.chmod(docker.stat().st_mode | stat.S_IXUSR)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"

            listing = run(DOCKER_MODULE, "--list", env=env)
            preview = run(DOCKER_MODULE, "--preview", "abcdef123456", env=env)

            self.assertIn("ID\tNAME\tIMAGE\tSTATUS\tPORTS", listing.stdout)
            self.assertIn("abcdef123456\tapi\tservice:latest", listing.stdout)
            self.assertIn("hello from container", preview.stdout)
            self.assertNotIn("\x1b", preview.stdout)


if __name__ == "__main__":
    unittest.main()
