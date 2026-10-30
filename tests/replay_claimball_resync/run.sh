#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_RESYNC_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_claimball_resync/build.sh" "$work/app"
RCB_TRACE_REFRESH=1 RCB_TRACE="$work/app/fault/logs/observer.trace" python3 "$ROOT/tests/replay_claimball_ui/regression.py" "$work/app" fault
"$work/app/replay-trace" "$work/app/fault/logs/observer.trace" >"$work/replay.log" 2>&1
python3 "$ROOT/tests/replay_claimball_resync/verify.py" "$work/app/fault/logs"
bash "$ROOT/tests/replay_claimball_trace/targets.sh" "$work/targets" "$work/app/fault/logs/observer.trace"
echo REPLAY_CLAIMBALL_RESYNC_EFFECTS_OK
