#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="${REPLAY_SHOP_OUT:-$(mktemp -d)}"; mkdir -p "$work"
trap 'echo "Shop logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
  "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
args=(--headless)
if [[ "${RSY_HEADED_HOST:-0}" == 1 ]]; then args=(); fi
if [[ -n "${RSY_AUDIO_DRIVER:-}" ]]; then args+=(--audio-driver "$RSY_AUDIO_DRIVER"); fi
RSY_PERSIST=0 "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script shop_test.gd >"$work/shop.log" 2>&1
cat "$work/shop.log"
rg -q REPLAY_SHOP_UI_OK "$work/shop.log"
if rg -q 'SCRIPT ERROR|ERROR:|WORKBENCH_FAIL|instances were leaked|resources still in use' "$work/shop.log"; then exit 1; fi
