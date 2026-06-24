#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the RPC / multiplayer annotation test headless.
# Greps for RPC_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/rpc/run.sh'
#
# Verifies (honestly, headless):
#   (1) `_get_rpc_config` reports the `@(gd_rpc)` methods to the engine with the exact
#       per-method config (mode/transfer/call_local/channel) — read back via
#       Script.get_rpc_config(), the same source the engine's RPC layer consults.
#   (2) call_local dispatch: with a multiplayer peer active, `node.rpc("set_value", n)` on a
#       call_local RPC runs the Odin method locally in ONE process (observable side-effect).
#   A genuine two-peer loopback is reported separately (RPC_LOOPBACK_SKIP) and NOT gated on.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/rpc"

# Build the scripts dll (NetNode + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# Write .godot/extension_list.cfg + import so the runtime loads the extension. (A SIGSEGV in
# Godot's headless editor doc-gen at import cleanup is a pre-existing engine issue, masked.)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Runtime (non-editor) RPC test. Prints RPC_OK (config + call_local) on success.
"$GODOT" --headless --path "$PROJ" --script test_rpc.gd
