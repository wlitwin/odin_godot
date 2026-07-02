#!/usr/bin/env bash
# lldb-godot.sh — legacy shim. The real launcher is build/debug_game.sh (shipped in the
# addon, richer interface: file:line breakpoints, godot_lldb.py pretty-printers, panic
# auto-break, batch mode; also what the editor's Project > Tools debugger items run).
# This preserves the old dev-facing calling convention:
#
#   tools/lldb-godot.sh <symbol-regex> <project-dir> [extra godot args...]
#
# which maps 1:1 onto:
#
#   build/debug_game.sh --break <symbol-regex> <project-dir> -- [extra godot args...]
set -euo pipefail

if [[ $# -lt 2 ]]; then
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi

SYMBOL="$1"; shift
PROJECT="$1"; shift
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$HERE/../build/debug_game.sh" --break "$SYMBOL" "$PROJECT" -- "$@"
