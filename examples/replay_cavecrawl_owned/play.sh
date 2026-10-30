#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
bash "$ROOT/examples/replay_cavecrawl_owned/build.sh" "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_SCRIPTS_DLL="$work/project/bin/libodinscripts.$ext" "$GODOT" --path "$work/project" "$@"
