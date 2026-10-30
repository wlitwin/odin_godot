#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_PLAYBACK_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Playback logs: $work"' EXIT
REPLAY_SCRUBBER_OUT="$work/native" bash "$ROOT/tests/replay_scrubber/run.sh"
mkdir -p "$work/files"
odin run "$ROOT/tests/replay_recording/playback_fixture" -collection:godot="$ROOT" -out:"$work/make-fixture" -- "$work/native/run/original.rplrec" "$work/native/run/branch.rplrec" "$work/files"
python3 - "$work/files/oversize.rplrec" <<'PY'
import sys
with open(sys.argv[1],'wb') as file:file.truncate(16*1024*1024+1)
PY
python3 "$ROOT/tests/replay_recording/playback.py" "$work/native" "$work/files" "$work/native-playback"
bash "$ROOT/tests/replay_scrubber/web.sh" "$work/native" "$work/web"
bash "$ROOT/tests/replay_recording/playback_web.sh" "$work/web" "$work/files" "$work/browser-playback"
echo REPLAY_PLAYBACK_OK
