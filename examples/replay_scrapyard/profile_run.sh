#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"
trap 'if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard profile logs: $work"; else rm -rf "$work"; fi' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
bash "$ROOT/build/build_scripts.sh" "$PROJ"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q "SCRIPT ERROR|ERROR:" "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi
touch "$work/import.log"
export RSY_ROLE=solo RSY_PERSIST=1 RSY_PROFILE_DIR="$work" RSY_RUN=1 RSY_WAVE_BASE=1 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_REST=1 RSY_BARRELS=0
unset RSY_TOKEN
export RSY_SPRAY="$work/no-spray.png"
RSY_NAME=VaultRunner RSY_PROFILE_PHASE=earn "$GODOT" --headless --path "$PROJ" --script profile_test.gd >"$work/earn.log" 2>&1
cat "$work/earn.log"; rg -q RSY_PROFILE_EARN_OK "$work/earn.log"
RSY_NAME="" RSY_PROFILE_PHASE=load "$GODOT" --headless --path "$PROJ" --script profile_test.gd >"$work/load.log" 2>&1
cat "$work/load.log"; rg -q RSY_PROFILE_RELOAD_OK "$work/load.log"
if rg -q 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|RSY_PROFILE_ERROR' "$work/earn.log" "$work/load.log" "$work/import.log"; then exit 1; fi
python3 - "$work" <<'PY'
from pathlib import Path
import sys, hashlib
directory=Path(sys.argv[1]); profiles=list(directory.glob('replay_profile_*'))
assert len(profiles)==1
profile=profiles[0]; data=profile.read_bytes(); (directory/'good-profile').write_bytes(data)
damaged=bytearray(data); damaged[-1]^=1; profile.write_bytes(damaged)
(directory/'corrupt.sha256').write_text(hashlib.sha256(damaged).hexdigest())
PY
set +e
RSY_NAME="" RSY_PROFILE_PHASE=load "$GODOT" --headless --path "$PROJ" --script profile_test.gd >"$work/corrupt.log" 2>&1
result=$?
set -e
cat "$work/corrupt.log"; ((result != 0)); rg -q 'RSY_PROFILE_ERROR decode=Codec' "$work/corrupt.log"
python3 - "$work" <<'PY'
from pathlib import Path
import sys,hashlib
directory=Path(sys.argv[1]); profile=next(directory.glob('replay_profile_*'))
assert hashlib.sha256(profile.read_bytes()).hexdigest()==(directory/'corrupt.sha256').read_text()
assert len((directory/'replay_identity').read_bytes())==16
profile.write_bytes((directory/'good-profile').read_bytes())
print('RSY_PROFILE_CORRUPTION_PRESERVED')
PY
python3 - "$work" <<'PYFAIL'
from pathlib import Path
import sys
root=Path(sys.argv[1]); profile=next(root.glob('replay_profile_*'))
Path(str(profile)+'.pending').mkdir()
PYFAIL
RSY_NAME="" RSY_PROFILE_PHASE=write_failure "$GODOT" --headless --path "$PROJ" --script profile_test.gd >"$work/write-failure.log" 2>&1
cat "$work/write-failure.log"; rg -q RSY_PROFILE_WRITE_FAILURE_OBSERVED "$work/write-failure.log"
python3 - "$work" <<'PYFAIL'
from pathlib import Path
import sys
root=Path(sys.argv[1]); profile=next(p for p in root.glob('replay_profile_*') if p.is_file())
assert profile.read_bytes()==(root/'good-profile').read_bytes()
print('RSY_PROFILE_OLD_FILE_PRESERVED')
PYFAIL
echo REPLAY_SCRAPYARD_PROFILE_OK
