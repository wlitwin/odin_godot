#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_LZ4_STAGING_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 - "$ROOT/tests/replay_lz4_staging/reference" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);h=json.loads((p/'sha256.json').read_text());data=(p/'lz4.odin').read_bytes()
assert hashlib.sha256(data).hexdigest()==h['adapted_sha256']
assert hashlib.sha256(data.replace(b'package lz4_reference',b'package replay_delta',1)).hexdigest()==h['original_sha256']
PY
odin build "$ROOT/tests/replay_lz4_staging" -collection:godot="$ROOT" -o:speed -out:"$work/staging"
"$work/staging" | tee "$work/staging.log"
echo REPLAY_LZ4_STAGING_CHECK_OK
