#!/usr/bin/env bash
# Rebuild ONLY the enemies script module as v2 (STEP 10 -> 100), simulating a dev's
# edit-save in that one module. Invoked by test_modules.gd via OS.execute mid-test
# (the godot process is launched inside the nix dev shell, so `odin` is on PATH).
# The main module's dll is deliberately NOT rebuilt — the test asserts it stays live
# and untouched across the enemies-only swap. Prints the wall time as a datapoint for
# the spike's per-module-rebuild-floor measurement (run.sh surfaces it).
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_BUILD_FLAGS="-define:ENEMIES_V=2"
export SKIP_CORE=1
export BUILD_MODULES=0
START=$SECONDS
bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/modules/enemies"
echo "MODULE_REBUILD_SECONDS=$((SECONDS - START))"
