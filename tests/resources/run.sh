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

case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
work="${RESOURCES_LOGS:-$(mktemp -d)}"
mkdir -p "$work"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
RESOURCES_EDITOR_CHECK=1 "$GODOT" --editor --headless --path "$PROJ" --quit-after 900 >"$work/editor.log" 2>&1
"$GODOT" --headless --path "$PROJ" --script test_resources.gd >"$work/runtime.log" 2>&1
cat "$work/editor.log" "$work/runtime.log"
rg -q '^RESOURCES_EDITOR_OK$' "$work/editor.log"
rg -q '^RESOURCES_OK$' "$work/runtime.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use|RIDs.*leaked|Scan thread aborted' "$work/"*.log; then
 cat "$work/"*.log
 exit 1
fi
