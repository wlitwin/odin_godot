#!/usr/bin/env bash
# Import readiness is a filesystem/resource barrier, not a number of editor frames.
# The caller supplies its retained log and keeps any script-build waiting separate.
odin_godot_test_import() {
    local project="$1" library="$2" log="$3"
    if ! ODIN_SCRIPTS_DLL="$library" "$GODOT" --headless --path "$project" --editor --import >"$log" 2>&1; then
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
