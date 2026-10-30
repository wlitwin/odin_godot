#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_SOCIAL_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave_social/build.sh" "$work/native"
CAVE_SOCIAL_RENDERED=1 python3 "$ROOT/tests/replay_cave_social/execute.py" "$work/native"
bash "$ROOT/tests/replay_cave_social/web.sh" "$work/native" "$work/web"
echo REPLAY_CAVE_SOCIAL_COMPLETE_OK
