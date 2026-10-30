#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="${REPLAY_MUSTER_OUT:-$(mktemp -d)}"; mkdir -p "$work"
trap 'echo "Muster logs: $work"' EXIT
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
RSY_ROLE=solo RSY_NAME=muster-solo RSY_RUN=0 RSY_MOBS=0 RSY_PERSIST=0 "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script muster_test.gd >"$work/muster.log" 2>&1
cat "$work/muster.log"; rg -q REPLAY_MUSTER_VIEW_OK "$work/muster.log"
if rg -q 'SCRIPT ERROR|ERROR:|WORKBENCH_FAIL|instances were leaked|resources still in use' "$work/muster.log"; then exit 1; fi
