#!/usr/bin/env bash
# Rebuild ONLY the Phase 4 scripts dll as v2 (STEP 10 -> 100), simulating a dev's
# edit-save + recompile. Invoked by test_phase4.gd via OS.execute mid-test (the godot
# process is launched inside the nix dev shell, so `odin` is on PATH here).
set -euo pipefail
ROOT="/Users/walter/data/code/odin/odin_godot"
cp "$ROOT/tests/phase4/fixtures/lifecycle_toggle_v2.odin" \
   "$ROOT/tests/phase4/scripts/lifecycle_toggle.odin"
export SCRIPT_BUILD_FLAGS="-define:RELOAD_V=2"
export SKIP_CORE=1
bash "$ROOT/build/build_scripts.sh" "$ROOT/tests/phase4"
