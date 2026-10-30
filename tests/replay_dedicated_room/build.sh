#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";mkdir -p "$work"
project="$ROOT/tests/replay_dedicated_room"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -40 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1

python3 - "$ROOT" "$work" <<'PY2'
from pathlib import Path
import hashlib,json,subprocess,sys
root,out=map(Path,sys.argv[1:]);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','build','scriptgen'],cwd=root,text=True).splitlines()
for p in (root/'tests/replay_dedicated_room').rglob('*'):
 if p.is_file() and p.suffix in ('.odin','.godot','.tscn','.sh','.py') and 'bin' not in p.parts and '.godot' not in p.parts and not p.name.endswith('.gen.odin'):paths.append(str(p.relative_to(root)))
(out/'source-sha256.json').write_text(json.dumps({name:sha(root/name) for name in paths if Path(name).suffix in ('.odin','.godot','.tscn','.sh','.py','.nix')},indent=2)+'\n')
PY2
