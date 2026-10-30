#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_steam_core" -collection:godot="$ROOT" -out:"$work/steam"
echo REPLAY_STEAM_CORE_OK
