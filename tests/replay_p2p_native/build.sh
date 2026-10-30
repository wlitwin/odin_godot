#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_P2P_NATIVE_OUT:?Set a fresh absolute output directory}"
python3 "$ROOT/tests/replay_p2p_native/prepare.py" "$out"
case "$(uname -s)" in Darwin) ext=dylib;; Linux) ext=so;; *) ext=dll;; esac
for name in duel service; do
    project="$out/$name";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$name-build.log" 2>&1
    "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$out/$name-import.log" 2>&1
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$out/$name-wait.json"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$name-final-build.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$out/$name-import.log";then cat "$out/$name-import.log";exit 1;fi
done
echo REPLAY_P2P_NATIVE_BUILD_OK
