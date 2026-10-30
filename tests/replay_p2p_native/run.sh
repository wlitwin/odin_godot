#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_P2P_NATIVE_OUT:-$(mktemp -d)}"; export REPLAY_P2P_NATIVE_OUT="$out"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/tests/replay_p2p_native/build.sh";fi
python3 "$ROOT/tests/replay_p2p_native/run.py" "$out" "${REPLAY_P2P_NATIVE_RUN:-$out/runtime}" "${REPLAY_P2P_NATIVE_MODE:-creator}"
