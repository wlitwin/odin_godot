#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ODIN="${ODIN:-odin}"
work="${KIT_BINDINGS_OUT:-$(mktemp -d)}"
mkdir -p "$work/scripts"
cp -R "$ROOT/tests/kit_subpackages/bindings/." "$work/scripts/"
sgen="${SGEN_BIN:-$work/scriptgen}"
if [[ -z "${SGEN_BIN:-}" ]]; then
    "$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$sgen"
fi
"$sgen" "$work/scripts" -godot:"$ROOT" -project:"$work"
"$ODIN" test "$work/scripts" -collection:godot="$ROOT" -out:"$work/bindings.test" -custom-attribute:gd_command -custom-attribute:gd_half -custom-attribute:gd_method
"$ODIN" check "$work/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_command -custom-attribute:gd_half -custom-attribute:gd_method
python3 "$ROOT/tests/kit_subpackages/composition.py" "$ROOT" "$work" "$sgen" "$ODIN"
echo KIT_COMMAND_BINDINGS_OK
