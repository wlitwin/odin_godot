#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
python3 "$ROOT/tests/instance_lifecycle/games.py" "$@"
