#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_NODES_OUT:-$(mktemp -d)}";export REPLAY_NODES_OUT="$out"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/tests/replay_nodes/build.sh";fi
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
ODIN_SCRIPTS_DLL="$out/current/bin/libodinscripts.$ext" "$GODOT" --headless --path "$out/current" >"$out/check.log" 2>&1
rg -q REPLAY_NODES_CONTRACT_OK "$out/check.log"
rg -q REPLAY_BODY_BINDINGS_OK "$out/check.log"
rg -q REPLAY_EFFECT_ROUTES_OK "$out/check.log"
rg -q REPLAY_INPUT_BINDINGS_OK "$out/check.log"
rg -q REPLAY_BAKE_OK "$out/check.log"
rg -q REPLAY_TYPED_VIEWS_OK "$out/check.log"
rg -q REPLAY_NODES_OK "$out/check.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$out/check.log";then cat "$out/check.log";exit 1;fi
echo REPLAY_NODES_LIFECYCLE_OK
