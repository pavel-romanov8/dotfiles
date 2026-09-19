#!/usr/bin/env bash

# Shared helpers for the internal ff modules. This file is sourced, not invoked.

ff_require_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    printf 'ff: fzf is required but was not found in PATH.\n' >&2
    return 1
  fi
}

ff_fzf() {
  command fzf \
    --height=80% \
    --tmux=90%,80% \
    --layout=reverse \
    --style=full \
    --info=inline-right \
    --no-separator \
    --with-shell='bash -c' \
    "$@"
}

ff_shell_quote() {
  printf '%q' "$1"
}

ff_copy() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  else
    printf 'ff: no clipboard command found (tried pbcopy, wl-copy, and xclip).\n' >&2
    return 1
  fi
}

# Remove terminal control characters from untrusted preview output while
# preserving Unicode, tabs, and newlines.
ff_sanitize() {
  python3 -c 'import sys
text = sys.stdin.read()
sys.stdout.write("".join(ch for ch in text if ch in "\\n\\t" or (ord(ch) >= 32 and ord(ch) != 127)))'
}
