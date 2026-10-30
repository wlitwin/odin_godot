#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_OBSERVATION_COMPAT_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 - "$ROOT/tests/replay_snapshot_compat/reference" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);manifest=json.loads((root/'manifest.json').read_text())
for name,digest in manifest.items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest['adapted_sha256']
PY
odin build "$ROOT/tests/replay_observation_compat" -collection:godot="$ROOT" -out:"$work/compat"
"$work/compat"
