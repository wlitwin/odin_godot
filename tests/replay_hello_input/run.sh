#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_HELLO_INPUT_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_view/run.sh"
bash "$ROOT/tests/replay_hello_input/build.sh" "$work/app"
for fps in 30 60 120 144;do python3 "$ROOT/tests/replay_hello_input/execute.py" "$work/app" "$work/pause-$fps" "$fps";done
python3 "$ROOT/tests/replay_hello_input/execute.py" "$work/app" "$work/cadence" 144 cadence
REPLAY_PLAYBACK_OUT="$work/playback" bash "$ROOT/tests/replay_recording/playback_run.sh"
if [[ "${SKIP_WEB:-0}" == 1 ]]; then
    echo 'SUITE_NATIVE_ONLY_OK: native checks completed; browser checks omitted'
    exit 0
fi
python3 "$ROOT/tests/replay_hello_input/browser.py" "$work/playback/web" "$work/pause-browser"
echo REPLAY_HELLO_INPUT_OK
