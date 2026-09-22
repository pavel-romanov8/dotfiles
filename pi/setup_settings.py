#!/usr/bin/env python3
"""Apply dotfiles-owned Pi appearance settings without replacing private settings."""

import json
import os
from pathlib import Path
import sys
import tempfile


def read_object(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def configure(agent_dir):
    managed = read_object(Path(__file__).with_name("settings.json"))
    if set(managed) != {"theme", "editorPaddingX"}:
        raise ValueError("Only theme and editorPaddingX may be managed by dotfiles")

    # Resolve existing symlinks rather than replacing them.
    target = (agent_dir / "settings.json").resolve()
    existing = read_object(target) if target.exists() else {}
    merged = {**existing, **managed}
    if target.exists() and merged == existing:
        print(f"ok:   {target} (Pi appearance already configured)")
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        fd, backup = tempfile.mkstemp(prefix="settings.json.bak.", dir=target.parent)
        with os.fdopen(fd, "wb") as stream:
            stream.write(target.read_bytes())
        print(f"backup: {target} -> {backup}")

    # Same-directory rename is atomic; temp files and settings stay private (0600).
    fd, temporary = tempfile.mkstemp(prefix=".settings.json.", dir=target.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(merged, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f"merge: {target} (theme, editorPaddingX only)")


if __name__ == "__main__":
    try:
        configure(Path(sys.argv[1]).expanduser())
    except (OSError, ValueError) as error:
        sys.exit(f"Pi settings not updated: {error}")
