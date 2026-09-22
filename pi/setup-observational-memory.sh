#!/usr/bin/env bash
# Optional long-session memory extension; separate from appearance-only setup.sh.
set -euo pipefail

PI_DIR="$(cd "$(dirname "$0")" && pwd)"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PACKAGE="npm:pi-observational-memory@3.1.4"

for tool in pi python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: $tool is required for Pi observational-memory setup." >&2
        exit 1
    }
done

# Reject malformed private settings before installing anything. Pi merges the
# package into existing settings; running outside a project avoids local scope.
python3 "$PI_DIR/setup_observational_memory.py" --check "$PI_AGENT_DIR"
mkdir -p "$PI_AGENT_DIR"
(cd "$PI_AGENT_DIR" && npm_config_ignore_scripts=true pi --no-approve install "$PACKAGE")

# Apply the checked-in, context-scaled configuration on every machine while
# preserving all unrelated Pi settings.
python3 "$PI_DIR/setup_observational_memory.py" "$PI_AGENT_DIR"

echo 'Pi observational memory: restart Pi (or run /reload), start a new session, then run /om:status.'
