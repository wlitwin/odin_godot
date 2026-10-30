#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_AUTHORING_OUT:-$(mktemp -d)}"
mkdir -p "$work"
python3 "$ROOT/examples/replay_scrapyard/tools/stock.py" --check
bash "$ROOT/tests/replay_definitions/run.sh"
bash "$ROOT/tests/replay_schema/run.sh"
odin test "$ROOT/tests/replay_evolution" -collection:godot="$ROOT" -out:"$work/evolution"
odin test "$ROOT/tests/replay_scenarios" -collection:godot="$ROOT" -out:"$work/scenarios"
python3 "$ROOT/tests/replay_scenarios/peers_test.py" "$work/peer-helper"
odin test "$ROOT/tests/replay_stormcaller/model" -collection:godot="$ROOT" -out:"$work/storm-model"
bash "$ROOT/tests/replay_stormcaller/corpus.sh" "$work/corpus"
export REPLAY_EDITOR_OUT="$work/editor"
bash "$ROOT/tests/replay_editor/build.sh"
python3 "$ROOT/tests/replay_editor/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_authoring/artifact.py" "$REPLAY_EDITOR_OUT/project" "$work/artifacts"
# Reuse the imported project; add Stormcaller's observer probes for real peers.
cp "$ROOT/tests/replay_stormcaller/probe.odin" "$REPLAY_EDITOR_OUT/project/scripts/storm_probe.odin"
for source in "$ROOT"/tests/replay_stormcaller/*.gd;do cp "$source" "$REPLAY_EDITOR_OUT/project/storm_$(basename "$source")";done
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$REPLAY_EDITOR_OUT/project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$REPLAY_EDITOR_OUT/project" > "$work/storm-build.log" 2>&1
python3 "$ROOT/tests/replay_stormcaller/execute.py" "$REPLAY_EDITOR_OUT"
echo REPLAY_AUTHORING_OK
