#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SPLIT-ADDON layout test — the Godot Asset Library / drop-in install shape:
#
#   res://addons/odin_godot/bin/macos/libodin_godot.dylib   (the prebuilt CORE)
#   res://bin/libodinscripts.dylib                          (the user's scripts)
#
# i.e. the core dll and the scripts dll are NOT siblings. This is what a consumer
# gets when they install the addon and build their own scripts, and it is the
# layout the backlog once recorded as broken on macOS ("core's dlopen of the
# scripts dll FAILS") — the scripts dll is fully self-contained (its only dylib
# dependency is libSystem; verified with otool -L), so the core's location must
# not matter. This test pins that: it builds the phase35 dlls, rearranges a COPY
# of the project into the split layout (unsetting ODIN_SCRIPTS_DLL so the core's
# own resolution runs: core-sibling first, then the res://bin fallback), and
# asserts an Odin script class loads, attaches, and RUNS (_ready fires).
#
# Prints SPLITADDON_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/splitaddon/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/tests/platform.sh"
SRC="$ROOT/tests/phase35"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/splitaddon"

# Build the phase35 dlls (core + scripts) via the standard pipeline.
bash "$ROOT/build/build_scripts.sh" >/dev/null

# Copy the project and rearrange into the split layout.
cp -r "$SRC" "$PROJ"
rm -rf "$PROJ/.godot"
mkdir -p "$PROJ/addons/odin_godot/bin/$ODIN_GODOT_TEST_PLATFORM"
mv "$PROJ/bin/libodin_godot.$ODIN_GODOT_TEST_LIB_EXT" \
    "$PROJ/addons/odin_godot/bin/$ODIN_GODOT_TEST_PLATFORM/"
rm -rf "$PROJ/bin/libodin_godot.$ODIN_GODOT_TEST_LIB_EXT.dSYM"
python3 - "$PROJ/odin_godot.gdextension" "$ODIN_GODOT_TEST_PLATFORM" "$ODIN_GODOT_TEST_LIB_EXT" <<'PY'
from pathlib import Path
import sys
manifest, platform, extension = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
source = 'res://bin/libodin_godot.' + extension
target = 'res://addons/odin_godot/bin/' + platform + '/libodin_godot.' + extension
text = manifest.read_text()
assert source in text, 'the active platform has no core manifest entry'
manifest.write_text(text.replace(source, target))
PY

# Driver: load an .odin script by res:// path, attach it, let _ready run.
cat > "$PROJ/test_splitaddon.gd" <<'EOF'
extends SceneTree

var frames := 0

func _initialize() -> void:
	var s: Script = load("res://scripts/ping.odin")
	if s == null:
		print("SPLITADDON_FAIL: could not load ping.odin as a Script (scripts dll not loaded?)")
		quit(1); return
	var n := Node.new()
	n.set_script(s)
	get_root().add_child(n)
	if not n.has_method("add"):
		print("SPLITADDON_FAIL: Odin method missing after attach"); quit(1); return
	if int(n.call("add", 2, 3)) != 5:
		print("SPLITADDON_FAIL: Odin method dispatch returned wrong value"); quit(1); return

func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	print("SPLITADDON_DRIVER_OK")
	quit(0)
	return true
EOF

# The point of the test is the core's OWN scripts-dll resolution — no env override.
unset ODIN_SCRIPTS_DLL

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

OUT="$("$GODOT" --headless --path "$PROJ" --script test_splitaddon.gd 2>&1)" || true
echo "$OUT" | tail -n 8

if echo "$OUT" | grep -q "odin: failed to load scripts dll"; then
	echo "SPLITADDON_FAIL: core could not load the scripts dll in the split layout"
	exit 1
fi
if ! echo "$OUT" | grep -q "SPLITADDON_DRIVER_OK"; then
	echo "SPLITADDON_FAIL: driver did not complete"
	exit 1
fi
echo "SPLITADDON_OK"
