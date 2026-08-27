#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the Phase 4 hot-reload milestone test.
# Greps for PHASE4_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/phase4/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase4"

# The live test swaps this authored fixture to v2. Always start at v1, and restore both
# source + generated artifacts on exit so repeated/local test runs leave a coherent tree.
cp "$PROJ/fixtures/lifecycle_toggle_v1.odin" "$PROJ/scripts/lifecycle_toggle.odin"
LOG=""
restore_v1() {
    cp "$PROJ/fixtures/lifecycle_toggle_v1.odin" "$PROJ/scripts/lifecycle_toggle.odin"
    SKIP_CORE=1 bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null 2>&1 || true
    if [ -n "$LOG" ]; then
        rm -f "$LOG"
    fi
}
trap restore_v1 EXIT

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
if ! grep -q "RELOAD_READER_DRAINED" "$LOG"; then
    echo "PHASE4_FAIL: reload did not drain an in-flight old-generation method"
    exit 1
fi
if ! grep -q "RELOAD_SNAPSHOT_FREE_SAFE" "$LOG"; then
    echo "PHASE4_FAIL: synchronous instance free invalidated the reload snapshot"
    exit 1
fi
echo "  ok  reload drained an in-flight script call and survived re-entrant instance free"
if ! grep -q "ODIN_RELOAD_GENERATIONS_RETAINED" "$LOG"; then
    echo "PHASE4_FAIL: retained DLL generation warning was not surfaced"
    exit 1
fi
echo "  ok  retained DLL generation cost surfaced with a restart recommendation"
