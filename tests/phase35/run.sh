#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the Phase 3.5 headless milestone test.
# Greps for PHASE35_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase35/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase35"

bash "$ROOT/build/build_scripts.sh"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the milestone test.
"$GODOT" --headless --path "$PROJ" --script test_phase35.gd
