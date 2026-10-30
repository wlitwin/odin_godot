#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="$1";work="$2";mkdir -p "$work"
python3 - "$ROOT" "$source" "$work" <<'PY'
from pathlib import Path
import shutil,sys
root,source,out=map(Path,sys.argv[1:]);project=out/'project'
shutil.copytree(source/'project',project,ignore=shutil.ignore_patterns('.godot','out'))
p=project/'project.godot';s=p.read_text().replace('run/main_scene="res://main.tscn"','run/main_scene="res://editor_browser.tscn"');assert 'res://editor_browser.tscn' in s;p.write_text(s)
shutil.copy2(root/'tests/replay_editor/browser.gd',project/'editor_browser.gd')
(project/'editor_browser.tscn').write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://editor_browser.gd" id="script"]\n[node name="EditorViews" type="Node"]\nscript = ExtResource("script")\n')
PY
project="$work/project";case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then cat "$work/export.log";exit 1;fi
port=$((20000+RANDOM%9000));pid=""
trap '[[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; }' EXIT
bash "$ROOT/tests/web/serve.sh" "$project/out" "$port" >"$work/server.log" 2>&1 &pid=$!
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$port/index.html" 2>/dev/null;then break;fi;sleep .1;done
node "$ROOT/tests/replay_editor/browser.mjs" "http://127.0.0.1:$port/index.html" "$work" >"$work/driver.log" 2>&1
cat "$work/driver.log"
