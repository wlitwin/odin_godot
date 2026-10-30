#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "P2P benchmark logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
"${ODIN:-odin}" build "$ROOT/tests/replay_p2p/bench" -collection:godot="$ROOT" -o:speed -out:"$work/bench"
"$work/bench" | tee "$work/bench.log"
node "$ROOT/tests/replay_p2p/bench.mjs" "$work/bench.log" | tee "$work/summary.json"
echo REPLAY_P2P_BENCH_OK
