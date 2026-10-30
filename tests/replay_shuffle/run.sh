#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SHUFFLE_OUT:-$(mktemp -d)}";mkdir -p "$work";trap 'echo "Shuffle logs: $work"' EXIT
python3 - "$ROOT/tests/replay_shuffle/reference" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);manifest=json.loads((root/'manifest.json').read_text());assert {p.name for p in root.glob('*.odin')}==set(manifest)
for name,hashes in manifest.items():
 data=(root/name).read_bytes();assert hashlib.sha256(data).hexdigest()==hashes['adapted_sha256']
 original=data.replace(b'package replay_schema_reference\n',b'package replay_schema\n',1)
 assert original!=data and hashlib.sha256(original).hexdigest()==hashes['original_sha256']
PY
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_shuffle" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" | tee "$work/$mode.log"
 odin build "$ROOT/tests/replay_shuffle/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_shuffle/check.mjs" "$work/$mode.wasm" "$work/$mode.log"
done
echo REPLAY_SHUFFLE_OK
