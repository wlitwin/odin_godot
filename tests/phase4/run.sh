#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the Phase 4 hot-reload milestone test.
# Greps for PHASE4_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase4/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase4"

# Build core + scripts v1 (default RELOAD_V=1).
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load + reload.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Run the milestone test. The test rebuilds the scripts dll as v2 mid-run (OS.execute)
# then triggers the reload, so `odin` must be on PATH — it is, inside the nix shell.
# Capture the output: PHASE4_OK still flows to stdout (run_all greps it), and we ALSO assert
# the `<class>_reload` hook fired on the swap (reloader.odin prints RELOAD_HOOK_FIRED from it).
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$GODOT" --headless --path "$PROJ" --script test_phase4.gd 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
    echo "PHASE4_FAIL: test exited non-zero ($RC)"
    exit 1
fi
if ! grep -q "RELOAD_HOOK_FIRED" "$LOG"; then
    echo "PHASE4_FAIL: the <class>_reload hook did not fire on the dll swap"
    exit 1
fi
echo "  ok  <class>_reload hook fired on the swap (RELOAD_HOOK_FIRED)"
