#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_room_service"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) echo 'The bundled SQLite service currently supports macOS/Linux.' >&2; exit 1 ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
rm -rf "$work";trap - EXIT
exec "$GODOT" --headless --max-fps 120 --path "$PROJ" "$@"
