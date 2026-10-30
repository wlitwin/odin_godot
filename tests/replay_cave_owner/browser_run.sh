#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_OWNER_WEB_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave_owner/browser_build.sh" "$work/build"
for mode in planned crash save;do
 python3 "$ROOT/tests/replay_cave_owner/browser_execute.py" "$work/build" "$work/$mode" "$mode"
 python3 "$ROOT/tests/replay_cave_owner/browser_verify.py" "$work/$mode" "$mode"
done
echo REPLAY_CAVE_OWNER_BROWSER_OK
