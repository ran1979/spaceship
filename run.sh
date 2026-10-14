#!/usr/bin/env bash
# Launch the Godot project in this directory. Extra args are passed to Godot.
set -euo pipefail

if ! command -v godot >/dev/null 2>&1; then
  echo "error: 'godot' not found in PATH. Install Godot 4.x and make sure the CLI is on PATH." >&2
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec godot --path "$PROJECT_DIR" "$@"
