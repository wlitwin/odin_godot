#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_PAYLOAD_OUT:-$(mktemp -d)}";mkdir -p "$work";trap 'echo "Payload profile logs: $work"' EXIT
odin build "$ROOT/tests/replay_payload_profile" -collection:godot="$ROOT" -o:speed -out:"$work/profile"
"$work/profile" | tee "$work/profile.log"

python3 "$ROOT/tests/replay_payload_profile/report.py" "$work"
