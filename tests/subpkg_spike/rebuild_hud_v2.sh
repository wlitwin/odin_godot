#!/usr/bin/env bash
# Rebuild the module as HUD v2 (ui/ GAIN 10 -> 100), simulating a dev's edit-save in a
# SUBPACKAGE. Invoked by test_subpkg.gd via OS.execute mid-test (the godot process is
# launched inside the nix dev shell, so `odin` is on PATH). One dll per module: the
# subpackage is compiled into the SAME libodinscripts.dylib as the module root, so this
# is an ordinary main-module rebuild — the point of the phase is that reloading a script
# whose source lives in a subfolder swaps that dll and preserves instance state.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_BUILD_FLAGS="-define:HUD_V=2"
export SKIP_CORE=1
bash "$ROOT/build/build_scripts.sh" "$PROJ"
