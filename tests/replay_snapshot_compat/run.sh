#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SNAPSHOT_COMPAT_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Snapshot compatibility logs: $work"' EXIT
python3 - "$ROOT/tests/replay_snapshot_compat/reference" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);manifest=json.loads((root/'manifest.json').read_text())
assert {p.name for p in root.glob('*.odin')}==set(manifest)
for name,digest in manifest.items():
 data=(root/name).read_bytes();assert hashlib.sha256(data).hexdigest()==digest['adapted_sha256']
 original=data.replace(b'package replay_net_legacy\n',b'package replay_net\n',1)
 assert original!=data and hashlib.sha256(original).hexdigest()==digest['original_sha256']
PY
odin build "$ROOT/tests/replay_snapshot_compat" -collection:godot="$ROOT" -out:"$work/compat"
"$work/compat" | tee "$work/compat.log"

python3 - "$ROOT/tests/replay_snapshot_compat/parts_reference" <<'PYREF'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);manifest=json.loads((root/'manifest.json').read_text())
assert {p.name for p in root.glob('*.odin')}==set(manifest)
for name,digest in manifest.items():
 data=(root/name).read_bytes();assert hashlib.sha256(data).hexdigest()==digest['adapted_sha256']
 original=data.replace(b'package replay_net_parts_reference\n',b'package replay_net\n',1)
 assert original!=data and hashlib.sha256(original).hexdigest()==digest['original_sha256']
PYREF
odin build "$ROOT/tests/replay_snapshot_compat/parts" -collection:godot="$ROOT" -out:"$work/parts"
"$work/parts" | tee "$work/parts.log"
echo REPLAY_SNAPSHOT_COMPAT_ALL_OK
