#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_CARRIER_WEB_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave_carrier/browser_build.sh" "$work/native"
bash "$ROOT/tests/replay_cave_carrier/web.sh" "$work/native" "$work/web"
echo REPLAY_CAVE_CARRIER_WEB_OK
