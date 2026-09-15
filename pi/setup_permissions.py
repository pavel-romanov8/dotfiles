#!/usr/bin/env python3
"""Opt-in installation of the dotfiles permission extension and seed policy."""

import json
import os
from pathlib import Path
import sys
import tempfile


def validate_policy(text):
    if len(text.encode()) > 65536:
        raise ValueError("Policy exceeds 64 KiB")
    data = json.loads(text)
    if not isinstance(data, dict) or set(data) != {"permission"} or not isinstance(data["permission"], dict):
        raise ValueError('Expected {"permission": {...rules}}')
    actions = {"allow", "ask", "deny"}
    for tool, rule in data["permission"].items():
        if not tool.strip():
            raise ValueError("Empty tool pattern")
        if isinstance(rule, str) and rule in actions:
            continue
        if not isinstance(rule, dict) or not rule:
            raise ValueError(f"Invalid rule for {tool}")
        for pattern, action in rule.items():
            if not pattern or not isinstance(action, str) or action not in actions:
                raise ValueError(f"Invalid input rule for {tool}")
    return data


def configure(agent_dir):
    root = Path(__file__).resolve().parent
    source = root / "extensions" / "permissions"
    destination = agent_dir / "extensions" / "dotfiles-permissions"
    policy = agent_dir / "permissions.json"
    existing_link = destination.is_symlink() and destination.resolve() == source.resolve()
    if os.path.lexists(destination) and not existing_link:
        raise ValueError(f"Refusing to replace {destination}; move it aside manually first")

    # Reject broken symlinks and invalid existing policies without modifying them.
    exists = os.path.lexists(policy)
    text = policy.read_text() if exists else (root / "permissions.example.json").read_text()
    validate_policy(text)
    if not exists:
        policy.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=".permissions.", dir=policy.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(text)
            # Atomic create-if-absent: no partially written policy, no overwrite
            # if another setup/editor created the destination in the meantime.
            os.link(temporary, policy)
        finally:
            os.unlink(temporary)
        print(f"seed: {policy} (private 0600; customize this machine-local file)")
    else:
        print(f"keep: {policy} (existing rules preserved)")

    destination.parent.mkdir(parents=True, exist_ok=True)
    if existing_link:
        print(f"ok:   {destination} -> {source}")
    else:
        destination.symlink_to(source, target_is_directory=True)
        print(f"link: {destination} -> {source}")
    print("Pi permissions: restart Pi or run /reload, then /permissions.")


if __name__ == "__main__":
    try:
        default = os.environ.get("PI_CODING_AGENT_DIR", "~/.pi/agent")
        configure(Path(sys.argv[1] if len(sys.argv) > 1 else default).expanduser().resolve())
    except (OSError, ValueError) as error:
        sys.exit(f"Permission setup stopped: {error}")
