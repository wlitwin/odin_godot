#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_AUTHORITY_MODERATION_COMPAT_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 - "$ROOT/tests/replay_authority_moderation_compat/reference" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);manifest=json.loads((root/'manifest.json').read_text())
for n,h in manifest.items():assert hashlib.sha256((root/n).read_bytes()).hexdigest()==h['adapted_sha256'],n
PY
odin build "$ROOT/tests/replay_authority_moderation_compat" -collection:godot="$ROOT" -out:"$work/compat"
"$work/compat"
echo REPLAY_AUTHORITY_MODERATION_COMPAT_OK
