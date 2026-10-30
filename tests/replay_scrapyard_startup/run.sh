#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_STARTUP_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Scrapyard startup logs: $work"' EXIT
odin build "$ROOT/tests/replay_scrapyard_startup" -collection:godot="$ROOT" -o:speed -out:"$work/startup"
"$work/startup" | tee "$work/corpus.log"
