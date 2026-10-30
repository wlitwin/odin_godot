#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_multiplayer_generation";work="${REPLAY_GENERATION_OUT:-$(mktemp -d)}";mkdir -p "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
# Retain reports from an earlier failed attempt without replaying them as a
# current editor-import failure.
for name in .odin_crash.log .odin_crash.prev.log;do
 if [[ -f "$PROJ/bin/$name" ]];then mv "$PROJ/bin/$name" "$work/previous-$name";fi
done
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
"$GODOT" --headless --max-fps 60 --path "$PROJ" --script driver.gd --quit-after 600 >"$work/runtime.log" 2>&1
cat "$work/runtime.log"
if rg -q 'ERROR:|SCRIPT ERROR|instances were leaked|resources still in use' "$work/runtime.log";then exit 1;fi
rg -q REPLAY_MULTIPLAYER_GENERATION_OK "$work/runtime.log"
echo "Generation logs: $work"
