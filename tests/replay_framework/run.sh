#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
exec python3 "$ROOT/tests/replay_framework/run.py" "${REPLAY_FRAMEWORK_OUT:-$(mktemp -d)}"
