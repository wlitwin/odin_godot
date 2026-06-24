#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the @export type/hint breadth test headless.
#
# Two passes:
#   1. EDITOR placeholder path  (--editor) -> EXPORT_TYPES_EDITOR_OK
#   2. runtime real-instance path           -> EXPORT_TYPES_OK
# Both must pass; run_all greps for EXPORT_TYPES_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/export_types/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/export_types"

# Build the scripts dll (Probe + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg + import so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Pass 1: editor-context placeholder property list (type + hint + hint_string).
"$GODOT" --editor --headless --path "$PROJ" --script test_editor_exports.gd

# Pass 2: runtime real-instance property list + set/get round-trips.
"$GODOT" --headless --path "$PROJ" --script test_export_types.gd
