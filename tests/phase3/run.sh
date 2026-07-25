#!/usr/bin/env bash
# Build + run the Phase 3 headless milestone test. Greps for PHASE3_OK.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase3/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase3"

# This fixture HAND-WRITES its @(init) registration (that is what the phase pins), so a
# scriptgen artifact here — e.g. from a repo-wide scriptgen sweep — is a redeclaration
# compile error. Sweep strays before building.
rm -f "$PROJ"/scripts/*.gen.odin

bash "$ROOT/build/build_phase3.sh"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the milestone test.
"$GODOT" --headless --path "$PROJ" --script test_phase3.gd
