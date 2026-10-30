#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_TRACE_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_claimball_trace/build.sh" "$work/app"
live_status=0
RCB_TRACE="$work/app/fault/logs/observer.trace" python3 "$ROOT/tests/replay_claimball_ui/regression.py" "$work/app" fault || live_status=$?
"$work/app/replay-trace" "$work/app/fault/logs/observer.trace" >"$work/replay.log" 2>&1
cat "$work/replay.log"
for kind in world effects; do
 "$work/app/mutate-trace" "$kind" "$work/app/fault/logs/observer.trace" "$work/mutated-$kind.trace"
 if "$work/app/replay-trace" "$work/mutated-$kind.trace" >"$work/mutated-$kind.log" 2>&1; then
  echo "Mutated $kind expectation was accepted" >&2;exit 1
 fi
 rg -q TRACE_STATE_MISMATCH "$work/mutated-$kind.log"
done
[[ "$live_status" == 0 ]] || exit "$live_status"
echo REPLAY_CLAIMBALL_TRACE_OK
