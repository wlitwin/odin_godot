#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the custom-resource end-to-end test headless.
# Greps for RESOURCES_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/resources/run.sh'
#
# Verifies a `//gd:extends Resource` Odin script: instantiate + @export + method, a real
# `.tres` save/load value round-trip, and a resource-typed @export slot on a node.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/resources"

# Build the scripts dll (ItemData + Holder + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg + import so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Pass 1: EDITOR context — a custom resource is editable in-editor (real instance);
# assert the @export vars show + an edit/save/reload round-trip persists, with NO crash
# or missing-virtual error (gotcha #4). Prints RESOURCES_EDITOR_OK.
ELOG="$(mktemp)"
trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --script test_editor_resources.gd >"$ELOG" 2>&1
set -e
cat "$ELOG"
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "RESOURCES_FAIL: editor logged a crash / missing-virtual error"
    grep -nE "signal 11|must be overridden|Required virtual" "$ELOG" | head
    exit 1
fi
if ! grep -q "RESOURCES_EDITOR_OK" "$ELOG"; then
    echo "RESOURCES_FAIL: editor-context resource check did not pass"
    exit 1
fi

# Pass 2: runtime (real instance) — instantiate + @export + method + .tres round-trip +
# resource-typed @export. Prints RESOURCES_OK (what run_all greps for).
"$GODOT" --headless --path "$PROJ" --script test_resources.gd
