#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_DEDICATED_BROWSER_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_dedicated_browser/build.sh" "$work"
for mode in planned crash repeat;do python3 "$ROOT/tests/replay_dedicated_browser/execute.py" "$work" "$mode";done
echo REPLAY_DEDICATED_BROWSER_COMPLETE_OK
