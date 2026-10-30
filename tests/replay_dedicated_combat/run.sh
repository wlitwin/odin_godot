#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_DEDICATED_COMBAT_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_dedicated_combat/build.sh" "$work/native"
for mode in planned crash;do
 python3 "$ROOT/tests/replay_dedicated_combat/execute.py" "$work/native" "$work/native-$mode" "$mode"
 python3 "$ROOT/tests/replay_dedicated_combat/verify.py" "$work/native-$mode"
done
bash "$ROOT/tests/replay_dedicated_combat/build_web.sh" "$work/web"
for mode in planned crash;do
 python3 "$ROOT/tests/replay_dedicated_browser/execute.py" "$work/web" "$mode"
 python3 "$ROOT/tests/replay_dedicated_combat/verify.py" "$work/web/$mode" browser
done
echo REPLAY_DEDICATED_COMBAT_COMPLETE_OK
