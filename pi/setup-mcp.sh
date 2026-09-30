#!/usr/bin/env bash
# Seed Pi's built-in MCP configuration; separate from appearance-only setup.sh.
set -euo pipefail

PI_DIR="$(cd "$(dirname "$0")" && pwd)"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

for tool in pi python3 npx; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: $tool is required for Pi MCP setup." >&2
        exit 1
    }
done

# Seed once; never overwrite private config or a symlink (including a broken
# one). Re-running preserves /mcp customizations.
python3 - "$PI_DIR/mcp.json" "$PI_AGENT_DIR/mcp.json" <<'PY'
import json
import os
from pathlib import Path
import sys

source, target = map(Path, sys.argv[1:])
try:
    value = json.loads(source.read_text())
    if os.path.lexists(target):
        existing = json.loads(target.read_text())
        if not isinstance(existing, dict):
            raise ValueError("expected a JSON object")
        print(f"keep: {target} (existing MCP configuration; no servers imported)")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
        print(f"seed: {target} (Playwright + GitHub, no embedded credentials)")
except (OSError, ValueError) as error:
    sys.exit(f"MCP setup stopped: {error}")
PY

echo 'Pi MCP: restart Pi (or /reload), then run /mcp to inspect the servers.'
echo 'If pi-mcp-adapter is still installed, migrate your private config and permissions first; then run pi remove npm:pi-mcp-adapter.'
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    echo 'GitHub (shared template): export GITHUB_PERSONAL_ACCESS_TOKEN before launching Pi, or configure a private credential header.'
fi
