#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# "Show on save" reload test — prove a newly-added Odin @export appears IN-PROCESS
# (no editor restart) after the save/reload path rebuilds + swaps the scripts dll.
#
# Builds the dlls, opens a headless EDITOR, and runs test_reload_exports.gd which:
#   edits widget.odin to add `@export new_field` -> script.reload(true) (the save path) ->
#   background rebuild -> deferred main-thread dll swap + placeholder refresh -> asserts
#   get_property_list() now contains `new_field` in the SAME process. Prints RELOAD_EXPORTS_OK.
#
# The live Inspector PANEL redraw is UI/visual and is NOT asserted here (headless); what is
# proven is the property-list refresh in-process, which is the thing that was broken.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/reload_exports/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/reload_exports"
SCRIPTS="$PROJ/scripts"

# Always start from the clean baseline source (a previously-interrupted run may have left an
# edited widget.odin); the driver restores it, but be defensive.
git -C "$ROOT" checkout -- tests/reload_exports/scripts/widget.odin 2>/dev/null || true

# Build core + scripts dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ" "$SCRIPTS"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg + import so the editor loads the GDExtension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

echo "== editor --headless --script test_reload_exports.gd =="
LOG="$(mktemp)"
trap 'rm -f "$LOG"; git -C "$ROOT" checkout -- tests/reload_exports/scripts/widget.odin 2>/dev/null || true' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --script test_reload_exports.gd >"$LOG" 2>&1
RC=$?
set -e
echo "----- driver output -----"; cat "$LOG"; echo "-------------------------"

if grep -qE "signal 11|Segmentation|must be overridden|Required virtual" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: crash / missing-virtual error during run"
	grep -nE "signal 11|Segmentation|must be overridden|Required virtual" "$LOG" | head
	exit 1
fi
if grep -q "RELOAD_EXPORTS_FAIL" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: driver reported a failure (see above)"
	exit 1
fi
if ! grep -q "RELOAD_EXPORTS_OK" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: driver did not complete (no RELOAD_EXPORTS_OK; rc=$RC)"
	exit 1
fi

echo "  ok  new @export appeared in-process after save+rebuild+reload (no restart)"
echo "  (visual-only, not asserted)  live Inspector PANEL redraw"
echo "RELOAD_EXPORTS_OK"
