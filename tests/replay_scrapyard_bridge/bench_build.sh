#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
project="$1";out="$2";mkdir -p "$out"
cp "$ROOT/tests/replay_scrapyard_bridge/bench_probe.odin" "$project/scripts/bridge_bench.odin"
cp "$ROOT/tests/replay_scrapyard_bridge/bench.gd" "$project/bridge_bench.gd"
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$project" >"$out/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --quit-after 120 >"$out/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$out/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$out/final-build.log" 2>&1
if rg -q 'ERROR:|SCRIPT ERROR' "$out/import.log";then cat "$out/import.log";exit 1;fi
