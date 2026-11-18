#!/usr/bin/env bash
# Import readiness is a filesystem/resource barrier, not a number of editor frames.
# The caller supplies its retained log and keeps any script-build waiting separate.
odin_godot_test_import() {
    local project="$1" library="$2" log="$3"
    local root="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    ODIN_GODOT_ROOT="$root" ODIN_SCRIPTS_DLL="$library" GODOT="$GODOT" \
        bash "$root/build/import_project.sh" "$project" "$log"
}
