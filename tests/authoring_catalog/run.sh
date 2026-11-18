#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
work="${AUTHORING_CATALOG_OUT:-$(mktemp -d)}"
echo "Catalog acceptance logs: $work"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import shutil,sys
root,out=map(Path,sys.argv[1:]);p=out/'project';p.mkdir(parents=True,exist_ok=False)
shutil.copytree(root/'tests/authoring_catalog/scripts',p/'scripts')
shutil.copy2(root/'examples/replay_scrapyard/odin_godot.gdextension',p/'odin_godot.gdextension')
(p/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Catalog acceptance"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(p/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/probe.odin" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n')
def entry(path,id,script='entry'):
 f=p/path;f.parent.mkdir(parents=True,exist_ok=True)
 f.write_text(f'[gd_resource type="Resource" load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/{script}.odin" id="1"]\n[resource]\nscript = ExtResource("1")\nid = {id}\n')
entry('payload.tres',2)
for directory in ['good','ordered']:
 entry(directory+'/a.tres.extra.tres',5)
 (p/directory/'a.tres.remap').write_text('[remap]\npath="res://payload.tres"\n')
entry('good/a.tres',2)
entry('duplicate/first.tres',2);entry('duplicate/second.tres',2)
entry('wrong/first.tres',2,'wrong');entry('negative/first.tres',-1);entry('reserved/first.tres',0)
PY
project="$work/project"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
# Pre-register the extension, preserving the remap fixtures without editor import.
python3 "$ROOT/build/box3d_profile.py" --prepare-import "$project" >"$work/prepare.log" 2>&1
python3 - "$project" "$work/runtime.log" <<'PY'
import os,subprocess,sys
with open(sys.argv[2], 'w') as log:
 subprocess.run([os.environ['GODOT'],'--headless','--path',sys.argv[1]], stdout=log,stderr=subprocess.STDOUT,check=True,timeout=30)
PY
rg -q AUTHORING_CATALOG_OK "$work/runtime.log"
if rg -n 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/runtime.log"; then exit 1; fi
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect >"$work/wasm.log" 2>&1
echo AUTHORING_CATALOG_OK
