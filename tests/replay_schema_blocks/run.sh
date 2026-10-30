#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SCHEMA_BLOCK_OUT:-$(mktemp -d)}";mkdir -p "$work";trap 'echo "Schema block logs: $work"' EXIT
python3 - "$ROOT/tests/replay_schema_blocks/reference" <<'PYREF'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);original=json.loads((root/'sha256.json').read_text());adapted=json.loads((root/'compiled-sha256.json').read_text())
for name,expected in original.items():
    text=(root/name).read_text();assert hashlib.sha256(text.encode()).hexdigest()==adapted[name]
    assert hashlib.sha256(text.replace('package schema_block_reference','package replay_schema',1).encode()).hexdigest()==expected
print('SCHEMA_BLOCK_REFERENCE_OK namespace_only=true')
PYREF
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_schema_blocks" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode"
 odin build "$ROOT/tests/replay_schema_blocks/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_schema_blocks/check.mjs" "$work/$mode.wasm"
done
echo REPLAY_SCHEMA_BLOCKS_OK
