#!/usr/bin/env bash
# Build the Phase 2 dlls (core + compiled scripts) into tests/phase2/bin/.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash build/build_phase2.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BIN="$ROOT/tests/phase2/bin"
mkdir -p "$BIN"

# Shared helpers: $ODIN override + atomic_odin_dll (temp+mv publish — never write over the
# live test dlls — plus a clean-temp build so no stale `.o` from an old runtime layout
# survives an incremental `-out:` build). Legacy intermediates from earlier non-atomic
# builds are scrubbed explicitly below.
source "$ROOT/build/common.sh"
rm -f "$BIN"/libodinscripts-*.o "$BIN"/libodin_godot-*.o

# The compiled scripts dll: the project's authored res://scripts sources (Player +
# the runtime registry boot), as a dll. The same `res://scripts/player.odin` is the
# resource attached to the node — single-file authoring, no separate stub.
atomic_odin_dll "$ROOT/tests/phase2/scripts" "$BIN/libodinscripts.dylib" -debug

# The core ScriptLanguageExtension dll.
atomic_odin_dll "$ROOT/core" "$BIN/libodin_godot.dylib" -debug

echo "Built:"
echo "  $BIN/libodin_godot.dylib"
echo "  $BIN/libodinscripts.dylib"
