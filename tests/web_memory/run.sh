#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
python3 "$ROOT/tests/web_memory/run.py" "${WEB_MEMORY_OUT:-$(mktemp -d)/checks}"
echo WEB_MEMORY_OK
