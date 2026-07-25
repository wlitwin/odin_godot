#!/usr/bin/env bash
# Build + run the Phase 2 headless milestone test. Greps for PHASE2_OK.
# (The sentinel-grep contract — which string means PASS — lives in tests/run_all.sh.)
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase2/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase2"

# This fixture HAND-WRITES its @(init) registration (that is what phase2 pins), so a
# scriptgen artifact here — e.g. from a repo-wide scriptgen sweep — is a redeclaration
# compile error. Sweep strays before building.
rm -f "$PROJ"/scripts/*.gen.odin

bash "$ROOT/build/build_phase2.sh"

# Make the scripts dll path unambiguous for the core's dynlib load (also works via
# globalize_path(res://bin/...), but the env override avoids any cwd ambiguity).
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the milestone test.
"$GODOT" --headless --path "$PROJ" --script test_phase2.gd
