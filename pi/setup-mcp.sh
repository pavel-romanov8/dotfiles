#!/usr/bin/env bash
# Optional MCP trial; deliberately separate from the appearance-only setup.sh.
set -euo pipefail

PI_DIR="$(cd "$(dirname "$0")" && pwd)"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

for tool in pi python3 npx; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: $tool is required for Pi MCP setup." >&2
        exit 1
    }
done

# Validate before installation. Seed once; never overwrite private config or a
# symlink (including a broken one). Re-running preserves /mcp customizations.
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

# Pi merges this package into existing settings; provider/appearance settings stay.
# Run outside any project so package installation cannot load project resources.
(cd "$PI_AGENT_DIR" && npm_config_ignore_scripts=true pi --no-approve install npm:pi-mcp-adapter@2.34.0)

echo 'Pi MCP: restart Pi, then run /mcp to inspect the servers.'
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    echo 'GitHub: export GITHUB_PERSONAL_ACCESS_TOKEN before launching Pi (never commit the token).'
fi
