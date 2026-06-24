#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the Odin-script AUTOLOAD test headless, then a
# headless --editor smoke. Greps for AUTOLOAD_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/autoload/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/autoload"

# Build the scripts dll (GameManager autoload + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- editor --headless smoke: open the project in the editor and quit. The autoload
# node is instantiated in the editor too; this guards against `signal 11` / "must be
# overridden" regressions at autoload-init time. ----
echo "== editor --headless smoke =="
ED_LOG="$(mktemp)"
"$GODOT" --headless --editor --path "$PROJ" --quit-after 3 >"$ED_LOG" 2>&1 || true
if grep -Eq "signal 11|Segmentation|must be overridden" "$ED_LOG"; then
	echo "AUTOLOAD_FAIL: editor --headless smoke hit a crash / must-be-overridden:"
	grep -E "signal 11|Segmentation|must be overridden" "$ED_LOG" | head
	rm -f "$ED_LOG"
	exit 1
fi
echo "editor smoke clean (no signal 11 / must-be-overridden)"
rm -f "$ED_LOG"

# ---- run the headless autoload E2E ----
echo "== headless autoload E2E =="
"$GODOT" --headless --path "$PROJ" --script test_autoload.gd
