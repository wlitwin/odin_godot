#!/usr/bin/env bash
# Import readiness is a filesystem/resource barrier, not a number of editor frames.
# The caller supplies its retained log and keeps any script-build waiting separate.
odin_godot_test_import() {
    local project="$1" library="$2" log="$3"
    local root="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    # Declare extensions before the initial editor scan. Godot's deferred docs
    # callback can otherwise outlive teardown when an extension is discovered
    # during that scan (Godot #111645/#111048). This leaves the full import and
    # every engine error visible, and preserves existing cache entries.
    if ! python3 "$root/build/box3d_profile.py" --prepare-import "$project" >"$log" 2>&1; then
        tail -n 60 "$log"
        echo "Godot import preparation failed: $project" >&2
        return 1
    fi
    if ! ODIN_SCRIPTS_DLL="$library" "$GODOT" --headless --path "$project" --editor --import >>"$log" 2>&1; then
        tail -n 60 "$log"
        echo "Godot import failed: $project" >&2
        return 1
    fi
    if grep -Eq 'SCRIPT ERROR|ERROR:' "$log"; then
        tail -n 60 "$log"
        echo "Godot import reported errors: $project" >&2
        return 1
    fi
}
