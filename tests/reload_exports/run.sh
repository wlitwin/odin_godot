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
# The editor's reload-on-save coordinator resolves the collection root for the rebuild. In this
# in-repo (non-installed) layout it can't be auto-derived from the core dll location, so declare
# it explicitly (an installed addons/odin_godot/ install derives it automatically).
export ODIN_GODOT_ROOT="$ROOT"

# Doctored second checkout for the ABI-skew phase: clone the collection root
# (APFS clonefile — instant; plain cp -R fallback) and grow Class_Desc, whose complete layout
# is fingerprinted, so a scripts dll built against the copy carries a DIFFERENT ABI fingerprint
# than this core — the exact "addon updated while the editor kept its startup core" skew.
SKEWROOT="$(mktemp -d)"
for d in build decl dist events flow flowgd gdext godot kit kititems libgd play runtime scriptgen; do
	[ -d "$ROOT/$d" ] || continue
	cp -c -R "$ROOT/$d" "$SKEWROOT/$d" 2>/dev/null || cp -R "$ROOT/$d" "$SKEWROOT/$d"
done
perl -0pi -e 's/\nClass_Desc :: struct \{/\nClass_Desc :: struct \{\n\t_abi_skew_test_pad: u64,/' "$SKEWROOT/runtime/runtime.odin"
grep -q '_abi_skew_test_pad' "$SKEWROOT/runtime/runtime.odin" || { echo "RELOAD_EXPORTS_FAIL: skew-root doctoring failed"; exit 1; }
export ODIN_GODOT_SKEW_ROOT="$SKEWROOT"

# Same ABI, doctored provenance: this root builds layout-compatible scripts while
# reporting a deliberately different Odin version. The loader must accept it based on the
# complete ABI fingerprint instead of reinstating exact compiler-string lockstep.
COMPATROOT="$(mktemp -d)"
for d in build decl dist events flow flowgd gdext godot kit kititems libgd play runtime scriptgen; do
	[ -d "$ROOT/$d" ] || continue
	cp -c -R "$ROOT/$d" "$COMPATROOT/$d" 2>/dev/null || cp -R "$ROOT/$d" "$COMPATROOT/$d"
done
perl -0pi -e 's/return ODIN_VERSION/return "doctored-compatible-compiler"/' "$COMPATROOT/runtime/runtime.odin"
grep -q 'doctored-compatible-compiler' "$COMPATROOT/runtime/runtime.odin" || { echo "RELOAD_EXPORTS_FAIL: compatible-root doctoring failed"; exit 1; }
export ODIN_GODOT_COMPAT_ROOT="$COMPATROOT"

# First pass: write .godot/extension_list.cfg + import so the editor loads the GDExtension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

echo "== editor --headless --script test_reload_exports.gd =="
LOG="$(mktemp)"
trap 'rm -f "$LOG" "$SCRIPTS"/doomed.odin "$SCRIPTS"/doomed.odin.uid "$SCRIPTS"/gun_probe.odin "$SCRIPTS"/gun_probe.odin.uid; rm -rf "$SKEWROOT" "$COMPATROOT"; git -C "$ROOT" checkout -- tests/reload_exports/scripts/widget.odin 2>/dev/null || true' EXIT
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
if grep -q "background scripts build FAILED" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: a create/delete edit burst surfaced a transient build failure"
	grep -n "background scripts build FAILED" "$LOG" | head
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

if ! grep -q "GEN_ORPHAN_SWEPT" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: the deletion probe never swept the deleted script's generated section"
	exit 1
fi
if ! grep -q "NEW_CLASS_EXPORTS_SHOWN" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: new-class placeholder never showed its exports after the swap"
	exit 1
fi
if ! grep -q "COMPILER_SKEW_ABI_COMPATIBLE" "$LOG" || ! grep -q "ODIN_COMPILER_SKEW_ABI_COMPATIBLE" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: a matching ABI did not safely admit the doctored compiler-version fixture"
	exit 1
fi
if ! grep -q "SKEW_SWAP_REFUSED_OLD_CODE_KEPT" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: ABI-skew phase did not refuse cleanly (old code not kept?)"
	exit 1
fi
if ! grep -q "RESTART THE EDITOR" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: the ABI-skew refusal never surfaced as an editor error (stderr-only again?)"
	exit 1
fi
if ! grep -q "SKEW_RECOVERED_AFTER_RESTORE" "$LOG"; then
	echo "RELOAD_EXPORTS_FAIL: reload pipeline did not recover after the skew root was restored"
	exit 1
fi
echo "  ok  new @export appeared in-process after save+rebuild+reload (no restart)"
echo "  ok  a deleted script's generated section swept itself (the deletion probe)"
echo "  ok  create/delete coalescing completed without a transient failed-build state"
echo "  ok  a brand-new class's exports appeared on its stale placeholder after the swap"
echo "  ok  a different compiler identity loads when the complete native ABI fingerprint matches"
echo "  ok  an ABI-skewed rebuild is refused LOUDLY (restart-the-editor error), old code kept, pipeline recovers"
echo "  (visual-only, not asserted)  live Inspector PANEL redraw"
echo "RELOAD_EXPORTS_OK"
