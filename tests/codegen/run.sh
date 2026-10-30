#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the richer-authoring codegen test headless.
#
# Two passes:
#   1. EDITOR placeholder path  (--editor) -> CODEGEN_EDITOR_OK  (groups + default-value virtual)
#   2. runtime real-instance path           -> CODEGEN_OK         (onready + defaults + get/set)
# Both must pass; run_all greps for CODEGEN_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/codegen/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/codegen"

# Build the scripts dll (Probe + boot) + the core dll via the codegen pipeline.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Bare-import composition (bare.odin): `import "godot:play"` without an alias must
# bind the package name and register the embed's replicated fields — the old
# alias-only rule skipped them SILENTLY (compiled fine, never replicated). The
# descriptor lands in the ONE consolidated artifact, in bare.odin's section.
GEN="$PROJ/scripts/odin_godot_scripts.gen.odin"
grep -q 'offset_of(BareProbe, health)' "$GEN" \
  || { echo "CODEGEN_FAIL: bare-import embed did not compose (no health descriptor in $GEN)"; exit 1; }

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# Import and both assertion passes must finish without engine errors/leaks.
work="${CODEGEN_LOGS:-$(mktemp -d)}"
mkdir -p "$work"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
CODEGEN_EDITOR_CHECK=1 "$GODOT" --editor --headless --path "$PROJ" --quit-after 900 >"$work/editor.log" 2>&1
"$GODOT" --headless --path "$PROJ" --script test_runtime.gd >"$work/runtime.log" 2>&1
cat "$work/editor.log" "$work/runtime.log"
rg -q '^CODEGEN_EDITOR_OK$' "$work/editor.log"
rg -q '^CODEGEN_OK$' "$work/runtime.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use|RIDs.*leaked|Scan thread aborted' "$work/"*.log; then
 cat "$work/"*.log
 exit 1
fi
