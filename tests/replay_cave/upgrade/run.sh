#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
version="${REPLAY_CAVE_SOURCE_VERSION:-1}"
case "$version" in 1) token=cave-definition-legacy ;; 2) token=cave-lobby-legacy ;; *) exit 1 ;; esac
source="$ROOT/tests/replay_cave/fixtures/content$version/cave.replay"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_CAVE_UPGRADE_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Cave upgrade logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
python3 - "$source" "$work" <<'PYSOURCE'
from pathlib import Path
import hashlib,sys
source,work=map(Path,sys.argv[1:]);raw=source.read_bytes()
(work/'source.sha256').write_text(hashlib.sha256(raw).hexdigest())
(work/'corrupt.replay').write_bytes(raw[:-1])
PYSOURCE
odin build "$PROJ/tools/upgrade_save" -collection:godot="$ROOT" -out:"$work/upgrade"
"$work/upgrade" "$source" "$work/current.replay" >"$work/convert.log"
python3 - "$work" <<'PY'
from pathlib import Path
import json,re,sys,hashlib
root=Path(sys.argv[1]);match=re.search(r'tick=(\d+) hash=(-?\d+)',(root/'convert.log').read_text());assert match
(root/'current.replay.json').write_text(json.dumps({'tick':match[1],'hash':match[2]}))
(root/'current.sha256').write_text(hashlib.sha256((root/'current.replay').read_bytes()).hexdigest())
PY
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" REPLAY_CAVE_ROLE=solo REPLAY_CAVE_TOKEN="$token" REPLAY_CAVE_RESUME=1 REPLAY_CAVE_SAVE="$work/current.replay" "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/resume.log" 2>&1
cat "$work/convert.log" "$work/resume.log";rg -q REPLAY_CAVE_SAVE_RESUME_OK "$work/resume.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/resume.log";then exit 1;fi
# A new destination is required even for repeated explicit conversion.
python3 - "$work" <<'PYEXISTING'
from pathlib import Path
import hashlib,sys
work=Path(sys.argv[1]);(work/'resumed.sha256').write_text(hashlib.sha256((work/'current.replay').read_bytes()).hexdigest())
PYEXISTING
code=0;"$work/upgrade" "$source" "$work/current.replay" >"$work/existing.log" 2>&1 || code=$?
[[ "$code" == 1 ]];rg -q 'publish=Exist' "$work/existing.log"
code=0;"$work/upgrade" "$work/corrupt.replay" "$work/corrupt-output.replay" >"$work/corrupt.log" 2>&1 || code=$?
[[ "$code" == 1 && ! -e "$work/corrupt-output.replay" ]];rg -q UPGRADE_ERROR "$work/corrupt.log"
python3 - "$source" "$work" <<'PYVERIFY'
from pathlib import Path
import hashlib,sys
work=Path(sys.argv[2])
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest()==(work/'source.sha256').read_text()
assert hashlib.sha256((work/'current.replay').read_bytes()).hexdigest()==(work/'resumed.sha256').read_text()
print('REPLAY_CAVE_UPGRADE_SOURCE_PRESERVED')
PYVERIFY
echo REPLAY_CAVE_UPGRADE_GATE_OK
