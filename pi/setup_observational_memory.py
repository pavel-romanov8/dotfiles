#!/usr/bin/env python3
"""Apply the shared Pi observational-memory configuration safely."""

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile


SETTINGS_KEY = "observational-memory"


def read_object(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def read_managed_config():
    path = Path(__file__).with_name("observational-memory.json")
    value = read_object(path)
    if set(value) != {SETTINGS_KEY} or not isinstance(value[SETTINGS_KEY], dict):
        raise ValueError(f"{path}: expected only an {SETTINGS_KEY!r} object")

    return value[SETTINGS_KEY]


def settings_target(agent_dir):
    path = agent_dir / "settings.json"
    if os.path.lexists(path) and not path.exists():
        raise OSError(f"{path}: broken symlink")
    return path.resolve()


def inspect(agent_dir):
    managed = read_managed_config()
    target = settings_target(agent_dir)
    existing = read_object(target) if target.exists() else {}
    if SETTINGS_KEY in existing and not isinstance(existing[SETTINGS_KEY], dict):
        raise ValueError(f"{target}: {SETTINGS_KEY!r} must be a JSON object")
    return target, existing, managed


def check(agent_dir):
    inspect(agent_dir)


def configure(agent_dir):
    target, existing, managed = inspect(agent_dir)
    merged = {**existing, SETTINGS_KEY: managed}
    if target.exists() and merged == existing:
        print(f"ok:   {target} (shared observational-memory configuration already applied)")
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        fd, backup = tempfile.mkstemp(prefix="settings.json.bak.", dir=target.parent)
        with os.fdopen(fd, "wb") as stream:
            stream.write(target.read_bytes())
        print(f"backup: {target} -> {backup}")

    fd, temporary = tempfile.mkstemp(prefix=".settings.json.", dir=target.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(merged, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f"merge: {target} (shared observational-memory configuration)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("agent_dir", type=Path)
    args = parser.parse_args()
    (check if args.check else configure)(args.agent_dir.expanduser())


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        sys.exit(f"Observational-memory settings not updated: {error}")
