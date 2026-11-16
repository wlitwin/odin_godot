#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_NETWORK_RECORDING_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_NETWORK_RECORDING_OUT="$work/native" bash "$ROOT/tests/replay_network_recording/run.sh"
bash "$ROOT/tests/replay_network_recording/targets.sh" "$work/targets" "$work/native/run/host.rplrec" "$work/native/run/client.rplrec"
if [[ "${SKIP_WEB:-0}" == 1 ]]; then
    echo 'SUITE_NATIVE_ONLY_OK: native checks completed; browser checks omitted'
    exit 0
fi
bash "$ROOT/tests/replay_network_recording/web.sh" "$work/native" "$work/web"
# Reuse the verified tools for the browser-produced input, retaining its mutation
# artifacts separately from the two required native inputs.
mkdir -p "$work/browser-targets"
for tool in verify.wasm verify_recording mutate; do
    cp "$work/targets/$tool" "$work/browser-targets/$tool"
done
node "$ROOT/tests/replay_network_recording/targets.mjs" "$work/browser-targets/verify.wasm" "$work/browser-targets/verify_recording" "$work/web/browser/downloads/scrapyard.rplrec" | tee "$work/browser-targets/targets.log"
echo REPLAY_NETWORK_RECORDING_ALL_OK
