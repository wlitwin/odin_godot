#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_hello"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
    bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi
case "$(uname -s)" in
    Darwin) ext=dylib ;;
    Linux) ext=so ;;
    *) ext=dll ;;
esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then
    cat "$work/import.log"
    exit 1
fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
for driver in hello_test.gd loot_test.gd; do
    if ! "$GODOT" --headless --path "$PROJ" --fixed-fps 60 --script "$driver" >"$work/$driver.log" 2>&1; then
        cat "$work/$driver.log"
        exit 1
    fi
    cat "$work/$driver.log"
    if grep -Eq 'SCRIPT ERROR|ERROR:|_FAIL:' "$work/$driver.log"; then exit 1; fi
done
grep -q '^REPLAY_HELLO_OK' "$work/hello_test.gd.log"
grep -q '^REPLAY_LOOT_VIEW_OK' "$work/loot_test.gd.log"
