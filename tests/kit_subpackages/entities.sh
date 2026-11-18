#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ODIN="${ODIN:-odin}"
work="${KIT_ENTITIES_OUT:-$(mktemp -d)}"
mkdir -p "$work"
sgen="${SGEN_BIN:-$work/scriptgen}"
if [[ -z "${SGEN_BIN:-}" ]]; then
    "$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$sgen"
fi
python3 "$ROOT/tests/kit_subpackages/events.py" "$ROOT" "$work/events" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/backups.py" "$ROOT" "$work/backups" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/schemas.py" "$ROOT" "$work/schemas" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/names.py" "$ROOT" "$work/names" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/callbacks.py" "$ROOT" "$work/callbacks" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/generics.py" "$ROOT" "$work/generics" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/identities.py" "$ROOT" "$work/identities" "$sgen" "$ODIN"
python3 "$ROOT/tests/kit_subpackages/entities.py" "$ROOT" "$work" "$ODIN" "$GODOT" "$sgen"
