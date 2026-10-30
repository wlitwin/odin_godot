#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";mkdir -p "$work/project/scripts"
cp "$ROOT/tests/replay_steam_room/failure/probe.odin" "$work/project/scripts/probe.odin"
cp "$ROOT/tests/replay_steam_room/fake_steam.gd" "$ROOT/tests/replay_steam_room/fake_peer.gd" "$work/project/"
cp "$ROOT/tests/replay_steam/project.godot" "$ROOT/tests/replay_steam/odin_godot.gdextension" "$work/project/"
cat > "$work/project/main.tscn" <<'SCENE'
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/probe.odin" id="1"]
[ext_resource type="Script" path="res://fake_steam.gd" id="2"]
[node name="SteamRoomFailureProbe" type="Node"]
script = ExtResource("1")
[node name="FakeSteam" type="Node" parent="."]
script = ExtResource("2")
SCENE
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/build.log" 2>&1
export ODIN_SCRIPTS_DLL="$work/project/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$work/project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -40 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$work/project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/final-build.log" 2>&1
REPLAY_CAVE_MEMBER=1 "$GODOT" --headless --path "$work/project" >"$work/run.log" 2>&1
rg -q REPLAY_STEAM_ROOM_FAILURES_OK "$work/run.log"
if rg -q 'ERROR:|instances were leaked|resources still in use' "$work/run.log";then tail -40 "$work/run.log";exit 1;fi
odin check "$work/project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
