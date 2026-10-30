#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_LEGACY_TRACE_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_claimball_trace/legacy_build.sh" "$work/app"
status=0
for seed in ${RCB_TRACE_SEEDS:-1 2 3 4 5}; do
 [[ "$seed" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid trace seed: $seed" >&2;exit 1; }
 RCB_TRACE_FAULT_SEED="$seed" python3 "$ROOT/tests/replay_claimball_trace/legacy_execute.py" "$work/app" "seed-$seed" || status=1
 "$work/app/replay-trace" "$work/app/seed-$seed/logs/observer.trace" >"$work/old-$seed.log" 2>&1 || status=1
 "$work/app/replay-current" "$work/app/seed-$seed/logs/observer.trace" >"$work/current-$seed.log" 2>&1 || status=1
done
[[ "$status" == 0 ]] || exit 1
echo REPLAY_CLAIMBALL_LEGACY_TRACE_OK
