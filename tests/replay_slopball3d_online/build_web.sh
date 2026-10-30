#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
native="$1";work="$2";mkdir -p "$work"
python3 - "$ROOT" "$native" "$work" <<'PY'
from pathlib import Path
import shutil,sys,hashlib,json
root,native,out=map(Path,sys.argv[1:]);project=out/'project'
shutil.copytree(native/'project',project,ignore=shutil.ignore_patterns('.godot','out'))
shutil.copy2(root/'tests/replay_slopball3d_online/bridge.gd',project/'online_test.gd')
p=project/'slopball3d.tscn';s=p.read_text();s=s.replace('[ext_resource type="Script"','[ext_resource type="Script" path="res://online_test.gd" id="online_probe"]\n\n[ext_resource type="Script"',1);s+='\n[node name="OnlineProbe" type="Node" parent="."]\nscript = ExtResource("online_probe")\n';p.write_text(s)
shutil.copy2(root/'tests/web/export_presets.cfg',project/'export_presets.cfg')
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in project.rglob('*') if p.is_file() and 'bin' not in p.parts and not p.name.endswith('.gen.odin')},indent=2)+'\n')
PY
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$work/project" >"$work/build.log" 2>&1
mkdir -p "$work/project/out";touch "$work/project/out/.gdignore"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_SCRIPTS_DLL="$work/project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$work/project" --export-release Web "$work/project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then tail -60 "$work/export.log";exit 1;fi
