#!/usr/bin/env python3
"""Enumerate SSH destinations without initiating network connections."""

import glob
import os
import re
import shlex
from pathlib import Path
from typing import Dict, Optional, Set

SAFE_HOST = re.compile(r"^[^\s\x00-\x1f\x7f]+$")
WILDCARDS = set("*?!")


def clean_host(value: str) -> Optional[str]:
    value = value.strip()
    if not value or value.startswith(("|", "@", "-")):
        return None
    if any(char in value for char in WILDCARDS):
        return None

    # known_hosts writes non-default ports as [hostname]:port. The SSH command
    # needs the hostname/alias; the port still belongs in SSH config.
    bracketed = re.fullmatch(r"\[([^]]+)](?::\d+)?", value)
    if bracketed:
        value = bracketed.group(1)

    if not SAFE_HOST.fullmatch(value):
        return None
    return value


def parse_ssh_file(
    path: Path,
    source_label: str,
    include_base: Path,
    hosts: Dict[str, str],
    visited: Set[Path],
) -> None:
    try:
        resolved = path.expanduser().resolve()
    except OSError:
        return
    if resolved in visited:
        return
    visited.add(resolved)

    try:
        lines = resolved.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return

    for line in lines:
        try:
            words = shlex.split(line, comments=True, posix=True)
        except ValueError:
            continue
        if len(words) < 2:
            continue

        keyword = words[0].lower()
        values = words[1:]
        if keyword == "host":
            for value in values:
                host = clean_host(value)
                if host:
                    hosts.setdefault(host, source_label)
        elif keyword == "include":
            for pattern in values:
                expanded = Path(os.path.expandvars(os.path.expanduser(pattern)))
                if not expanded.is_absolute():
                    expanded = include_base / expanded
                for included in sorted(glob.glob(str(expanded))):
                    parse_ssh_file(
                        Path(included),
                        f"included config · {Path(included).name}",
                        include_base,
                        hosts,
                        visited,
                    )


def parse_known_hosts(path: Path, hosts: Dict[str, str]) -> None:
    try:
        lines = path.expanduser().read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", "|", "@")):
            continue
        fields = stripped.split()
        if not fields:
            continue
        for value in fields[0].split(","):
            host = clean_host(value)
            if host:
                hosts.setdefault(host, "known_hosts")


def parse_etc_hosts(path: Path, hosts: Dict[str, str]) -> None:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return

    for line in lines:
        words = line.partition("#")[0].split()
        if len(words) < 2 or words[0] == "0.0.0.0":
            continue
        for value in words[1:]:
            host = clean_host(value)
            if host:
                hosts.setdefault(host, "/etc/hosts")


def main() -> None:
    home = Path.home()
    ssh_dir = home / ".ssh"
    hosts: Dict[str, str] = {}
    visited: Set[Path] = set()

    parse_ssh_file(ssh_dir / "config", "ssh config", ssh_dir, hosts, visited)
    parse_ssh_file(
        Path("/etc/ssh/ssh_config"),
        "system ssh config",
        Path("/etc/ssh"),
        hosts,
        visited,
    )
    parse_known_hosts(ssh_dir / "known_hosts", hosts)
    parse_known_hosts(ssh_dir / "known_hosts2", hosts)
    parse_etc_hosts(Path("/etc/hosts"), hosts)

    for host in sorted(hosts, key=str.casefold):
        print(f"{host}\t{hosts[host]}")


if __name__ == "__main__":
    main()
