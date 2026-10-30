#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_LOADED_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_loaded_migration/build.sh" "$work"
bash "$ROOT/tests/replay_loaded_migration/execute.sh" "$work" "$work/run"
