#!/usr/bin/env bash
# Build (via the codegen pipeline) + run the typed cross-script + global-class test
# headless. Greps for CROSSSCRIPT_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/crossscript/run.sh'
#
# Two payoffs are verified:
#   (1) Global class_name registration: an Odin `//gd:class <Name>` is reported as a global
#       class name (Script.get_global_name()) and, after an editor scan, registered in the
#       project's global class list.
#   (2) Typed cross-script references (Option A): Controller obtains a TYPED ^Enemy ref to a
#       live Enemy node at runtime and reads/writes its exported field + calls its method
#       directly; a GDScript driver asserts the Enemy's hp changed.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/crossscript"

# Build the scripts dll (Controller + Enemy + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# Write .godot/extension_list.cfg + import so the runtime loads the extension. (A SIGSEGV
# in Godot's headless editor doc-gen at import cleanup, EditorHelp::_gen_extensions_docs,
# is a pre-existing engine issue unrelated to this extension — masked here as elsewhere.)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) Global class_name (gating): the editor's filesystem scan runs in this editor
#      session and calls our _handles_global_class_type + _get_global_class_name virtuals.
#      The driver asserts BOTH Script.get_global_name() == <Name> (the exact ScriptExtension
#      virtual the scan reads) AND that the class is registered in
#      ProjectSettings.get_global_class_list() (i.e. the engine treats <Name> as a TYPE).
GLOG="$(mktemp)"
trap 'rm -f "$GLOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --script test_global_class.gd >"$GLOG" 2>&1
set -e
cat "$GLOG"
if grep -qE "signal 11|must be overridden|Required virtual" "$GLOG"; then
    echo "CROSSSCRIPT_FAIL: editor logged a crash / missing-virtual error"
    exit 1
fi
if ! grep -q "CROSSSCRIPT_GLOBAL_OK" "$GLOG"; then
    echo "CROSSSCRIPT_FAIL: global class_name check did not pass"
    exit 1
fi

# ---- (2) Typed cross-script references (gating): runtime two-script test. Prints
#      CROSSSCRIPT_OK (what run_all greps for).
"$GODOT" --headless --path "$PROJ" --script test_crossscript.gd
