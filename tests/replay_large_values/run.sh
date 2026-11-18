#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import os,subprocess,sys,tempfile
root=Path(sys.argv[1]);odin=os.environ.get('ODIN','odin')
with tempfile.TemporaryDirectory(prefix='replay-large-values-') as out:
 subprocess.run([odin,'test',str(root/'tests/replay_large_values'),f'-collection:godot={root}','-o:speed',f'-out:{out}/tests'],check=True,timeout=90)
 subprocess.run([odin,'build',str(root/'tests/replay_large_values/fixture'),f'-collection:godot={root}','-target:freestanding_wasm32','-build-mode:obj','-o:speed','-no-entry-point',f'-out:{out}/values.o'],check=True,timeout=90)
print('REPLAY_LARGE_VALUES_OK')
PY
