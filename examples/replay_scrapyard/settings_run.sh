#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";work="${REPLAY_SETTINGS_OUT:-$(mktemp -d)}";mkdir -p "$work/profiles"
trap 'echo "Settings logs: $work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
 ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" RSY_ROLE=solo RSY_TOKEN=settings-fixture RSY_PERSIST=1 RSY_PROFILE_DIR="$work/profiles" RSY_SETTINGS_PATH="$work/preferences" RSY_SPRAY="$work/no-spray.png"
for mode in create reload corrupt;do
 if [[ "$mode" == corrupt ]];then
  python3 - "$work/preferences" <<'PY'
from pathlib import Path
import sys,hashlib
p=Path(sys.argv[1]);data=bytearray(p.read_bytes());data[-1]^=1;p.write_bytes(data)
Path(str(p)+'.sha256').write_text(hashlib.sha256(data).hexdigest())
PY
 fi
 RSY_SETTINGS_TEST="$mode" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script settings_test.gd >"$work/$mode.log" 2>&1
 cat "$work/$mode.log";rg -q "REPLAY_SETTINGS_OK mode=$mode" "$work/$mode.log"
 if rg -q 'SCRIPT ERROR|ERROR:|SETTINGS_FAIL|instances were leaked|resources still in use' "$work/$mode.log";then exit 1;fi
done
python3 - "$work/preferences" <<'PY'
from pathlib import Path
import hashlib,sys
p=Path(sys.argv[1]);assert hashlib.sha256(p.read_bytes()).hexdigest()==Path(str(p)+'.sha256').read_text()
PY
echo REPLAY_SCRAPYARD_SETTINGS_OK
