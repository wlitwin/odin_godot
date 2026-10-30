#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_authority_godot"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
if ! "$GODOT" --headless --path "$PROJ" >"$work/run.log" 2>&1; then cat "$work/run.log"; exit 1; fi
cat "$work/run.log"
grep -q '^REPLAY_LEASE_GODOT_OK' "$work/run.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_LEASE_FAIL|ObjectDB instances were leaked' "$work/run.log"; then exit 1; fi
"${ODIN:-odin}" check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
