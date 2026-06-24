#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the ergonomic-helpers scene headless.
# Greps for ERGONOMICS_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/ergonomics/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/ergonomics"

# Build the scripts dll (Tester + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg + import so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the headless ergonomics test.
"$GODOT" --headless --path "$PROJ" --script test_ergonomics.gd
