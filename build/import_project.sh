#!/usr/bin/env bash
# Checked cold import for an Odin project. Predeclare extensions before Godot's
# scan so late documentation callbacks cannot outlive fast-import teardown.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT="${1:?Usage: import_project.sh PROJECT [LOG]}"
LOG="${2:-$PROJECT/bin/odin_import.log}"
GODOT="${GODOT:-godot}"
mkdir -p "$(dirname "$LOG")"
if ! python3 "$ROOT/build/box3d_profile.py" --prepare-import "$PROJECT" >"$LOG" 2>&1 ||
   ! "$GODOT" --headless --path "$PROJECT" --editor --import >>"$LOG" 2>&1; then
    tail -n 60 "$LOG" >&2
    echo "Godot import failed; full log: $LOG" >&2
    exit 1
fi
if grep -Eq 'SCRIPT ERROR|ERROR:|leaked at exit|resources still in use' "$LOG"; then
    tail -n 60 "$LOG" >&2
    echo "Godot import reported errors; full log: $LOG" >&2
    exit 1
fi
echo "ODIN_IMPORT_OK $PROJECT"
