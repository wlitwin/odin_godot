#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"
work="$(mktemp -d)"; producer=""
cleanup() {
  if [[ -n "$producer" ]]; then kill "$producer" 2>/dev/null || true; wait "$producer" 2>/dev/null || true; fi
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard save logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RSY_ROLE=solo RSY_PERSIST=1 RSY_PROFILE_DIR="$work" RSY_SAVE="$work/run.replay" RSY_RESULT_DIR="$work" RSY_RUN=0 RSY_ENCOUNTER=migration
unset RSY_TOKEN
export RSY_SPRAY="$work/no-spray.png"
RSY_RESUME=0 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/save.log" 2>&1 &
producer=$!
for _ in {1..450}; do
  if rg -q '^RSY_SAVE_READY' "$work/save.log"; then break; fi
  if ! kill -0 "$producer" 2>/dev/null; then cat "$work/save.log"; exit 1; fi
  sleep 0.1
done
if ! rg -q '^RSY_SAVE_READY' "$work/save.log"; then cat "$work/save.log"; exit 1; fi
kill -KILL "$producer"; wait "$producer" 2>/dev/null || true; producer=""
if ! RSY_RESUME=1 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/resume.log" 2>&1; then cat "$work/save.log" "$work/resume.log"; exit 1; fi
cat "$work/save.log" "$work/resume.log"
rg -q '^RSY_SAVE_RESUME_OK' "$work/resume.log"
if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_SCRAPYARD_FAIL|ObjectDB instances were leaked' "$work/save.log" "$work/resume.log"; then exit 1; fi
# Existing checkpoint-only files are still readable when their world has no
# external dependencies. Extract the untouched root to exercise that entry path.
python3 - "$work/run.replay" "$work/legacy.replay" <<'PYLEGACY'
from pathlib import Path
import struct,sys
data=Path(sys.argv[1]).read_bytes();size=struct.unpack_from('<I',data,56)[0]
assert struct.unpack_from('<H',data,54)[0]==0
Path(sys.argv[2]).write_bytes(data[96:96+size])
PYLEGACY
if ! RSY_RESUME=1 RSY_SAVE="$work/legacy.replay" "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/legacy.log" 2>&1; then cat "$work/legacy.log"; exit 1; fi
cat "$work/legacy.log"; rg -q '^RSY_SAVE_RESUME_OK' "$work/legacy.log"
if rg -q 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/legacy.log"; then exit 1; fi
echo RSY_LEGACY_CHECKPOINT_RESUME_OK
# A fresh token must not silently claim the saved local seat.
set +e
RSY_RESUME=1 RSY_TOKEN=wrong-save-owner RSY_PERSIST=0 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/identity.log" 2>&1
result=$?
set -e
cat "$work/identity.log"; ((result != 0)); rg -q RSY_SAVE_ERROR\ identity "$work/identity.log"
python3 - "$work/run.replay" <<'PY'
from pathlib import Path
import hashlib,sys
p=Path(sys.argv[1]); data=bytearray(p.read_bytes()); data[-1]^=1; p.write_bytes(data)
Path(str(p)+'.sha256').write_text(hashlib.sha256(data).hexdigest())
PY
set +e
RSY_RESUME=1 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/corrupt.log" 2>&1
result=$?
set -e
cat "$work/corrupt.log"; ((result != 0)); rg -q 'RSY_SAVE_ERROR load=Codec' "$work/corrupt.log"
python3 - "$work/run.replay" <<'PY'
from pathlib import Path
import hashlib,sys
p=Path(sys.argv[1]); assert hashlib.sha256(p.read_bytes()).hexdigest()==Path(str(p)+'.sha256').read_text()
print('RSY_SAVE_CORRUPTION_PRESERVED')
PY
echo REPLAY_SCRAPYARD_SAVE_OK
