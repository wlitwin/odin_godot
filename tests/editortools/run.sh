#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Editor-tooling test: custom class ICONS, @tool ergonomics (gd.is_editor()), an Odin
# EditorPlugin, and (stretch) an EditorInspectorPlugin. Build the dlls, then run TWO
# headless-EDITOR passes and assert observable side-effects.
#
#   Pass A (--editor --headless --quit-after): the enabled Odin EditorPlugin auto-loads;
#     its _enter_tree prints EDITORTOOLS_PLUGIN_ENTER_TREE. Also guards against
#     signal 11 / "must be overridden" regressions at editor-open + plugin-load time.
#   Pass B (--editor --headless --script test_editortools.gd): drives the icon
#     (_get_class_icon_path), @tool (_ready ran + gd.is_editor()), and inspector-dispatch
#     checks; prints EDITORTOOLS_DRIVER_OK.
#
# Prints EDITORTOOLS_OK covering ONLY what is asserted; visual-only items (icon PIXELS in
# the dock, live Inspector UI) are excluded and noted. Greps for EDITORTOOLS_OK.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/editortools/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/editortools"
SCRIPTS="$PROJ/addons/odinplugin"

# Build the scripts dll (all Odin classes live in the addons/odinplugin package) + core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ" "$SCRIPTS"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg + import so the editor loads the GDExtension
# and scans the filesystem (registers global classes incl. the icon path).
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- Pass A: editor open with the Odin EditorPlugin enabled -> _enter_tree runs ----
echo "== Pass A: editor --headless (Odin EditorPlugin _enter_tree) =="
ALOG="$(mktemp)"
trap 'rm -f "$ALOG" "${BLOG:-}"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 8 >"$ALOG" 2>&1
ARC=$?
set -e
echo "----- Pass A output (tail) -----"; tail -n 20 "$ALOG"; echo "--------------------------------"

if grep -qE "signal 11|Segmentation|must be overridden|Required virtual" "$ALOG"; then
	echo "EDITORTOOLS_FAIL: editor open hit a crash / missing-virtual error:"
	grep -nE "signal 11|Segmentation|must be overridden|Required virtual" "$ALOG" | head
	exit 1
fi
if ! grep -q "EDITORTOOLS_PLUGIN_ENTER_TREE" "$ALOG"; then
	echo "EDITORTOOLS_FAIL: Odin EditorPlugin _enter_tree did not run (no sentinel in editor log)"
	exit 1
fi
echo "  ok  Odin EditorPlugin loaded + _enter_tree executed (EDITORTOOLS_PLUGIN_ENTER_TREE)"

# The editor reopened main.tscn and the //gd:tool ToolWidget._ready ran in edit mode, taking
# its gd.is_editor()==true branch (which prints this marker). Corroborates Pass B's gated
# ProjectSetting read of the same side-effect.
if grep -q "EDITORTOOLS_TOOL_READY_IN_EDITOR" "$ALOG"; then
	echo "  ok  //gd:tool _ready ran in editor (gd.is_editor() branch) at editor-open"
fi

# ---- Pass B: driver for icon / @tool / inspector-dispatch ----
echo "== Pass B: editor --headless --script test_editortools.gd =="
BLOG="$(mktemp)"
set +e
"$GODOT" --editor --headless --path "$PROJ" --script test_editortools.gd >"$BLOG" 2>&1
BRC=$?
set -e
echo "----- Pass B output -----"; cat "$BLOG"; echo "-------------------------"

if grep -qE "signal 11|Segmentation|must be overridden|Required virtual" "$BLOG"; then
	echo "EDITORTOOLS_FAIL: driver hit a crash / missing-virtual error"; exit 1
fi
if grep -q "EDITORTOOLS_FAIL" "$BLOG"; then
	echo "EDITORTOOLS_FAIL: driver reported a failure (see above)"; exit 1
fi
if ! grep -q "EDITORTOOLS_DRIVER_OK" "$BLOG"; then
	echo "EDITORTOOLS_FAIL: driver did not complete (no EDITORTOOLS_DRIVER_OK)"; exit 1
fi

# Honest reporting of the stretch + visual-only items.
if grep -q "EDITORTOOLS_INSPECTOR_DISPATCH_OK" "$BLOG"; then
	echo "  ok(stretch)  EditorInspectorPlugin virtuals dispatch into Odin (proven by direct call)"
else
	echo "  (stretch)    EditorInspectorPlugin virtual dispatch NOT proven headless (see NOTE above)"
fi
echo "  (visual-only, not asserted)  icon PIXELS in Scene dock, the script-level"
echo "                               _get_class_icon_path dock render, and live Inspector UI"

echo "EDITORTOOLS_OK"
