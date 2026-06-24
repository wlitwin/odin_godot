#!/usr/bin/env bash
# Build the Phase 3 dlls (core + compiled scripts) into tests/phase3/bin/.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash build/build_phase3.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BIN="$ROOT/tests/phase3/bin"
mkdir -p "$BIN"

# The compiled scripts dll: the project's authored res://scripts sources
# (Ping/Counter/ToolProbe + the runtime registry boot), as a dll. Those same
# `res://scripts/*.odin` are the resources attached to nodes — single-file authoring.
odin build "$ROOT/tests/phase3/scripts" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$BIN/libodinscripts.dylib" \
    -debug

# The core ScriptLanguageExtension dll.
odin build "$ROOT/core" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$BIN/libodin_godot.dylib" \
    -debug

echo "Built:"
echo "  $BIN/libodin_godot.dylib"
echo "  $BIN/libodinscripts.dylib"
