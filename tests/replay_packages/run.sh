#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_PACKAGES_OUT:-$(mktemp -d)}"
exec python3 "$ROOT/tests/replay_packages/run.py" "$ROOT" "$work"
