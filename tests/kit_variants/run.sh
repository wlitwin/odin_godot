#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ODIN="${ODIN:-odin}"
work="${KIT_VARIANTS_OUT:-$(mktemp -d)}"
mkdir -p "$work"
sgen="${SGEN_BIN:-$work/scriptgen}"
if [[ -z "${SGEN_BIN:-}" ]]; then
    "$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$sgen"
fi
python3 "$ROOT/tests/kit_variants/codegen.py" "$ROOT" "$work/codegen" "$sgen" "$ODIN"
"$ODIN" run "$ROOT/tests/kit_variants/replay_refusal" -collection:godot="$ROOT" -disable-assert -out:"$work/replay-refusal"
python3 "$ROOT/tests/kit_variants/peers.py" "$ROOT" "$work/peers"
python3 "$ROOT/tests/kit_variants/invalid.py" "$ROOT" "$work/invalid"
echo KIT_SCENE_VARIANTS_OK
