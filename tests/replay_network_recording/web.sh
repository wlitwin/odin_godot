#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
native="$1";work="$2";mkdir -p "$work"
python3 - "$ROOT" "$native" "$work" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
root,native,out=map(Path,sys.argv[1:]);project=out/'project'
shutil.copytree(native/'project',project,ignore=shutil.ignore_patterns('.godot','out'))
p=project/'project.godot';s=p.read_text();assert 'run/main_scene="res://main.tscn"' in s;p.write_text(s.replace('run/main_scene="res://main.tscn"','run/main_scene="res://recording_test.tscn"'))
shutil.copy2(root/'tests/replay_network_recording/browser.gd',project/'recording_test.gd')
(project/'recording_test.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://recording_test.gd" id="1"]\n[node name="RecordingTest" type="Node"]\nscript = ExtResource("1")\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file() and 'bin' not in p.parts and not p.name.endswith('.gen.odin')},indent=2)+'\n')
PY
project="$work/project"
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then tail -40 "$work/export.log";exit 1;fi
port=$((20000+RANDOM%9000));server=""
trap '[[ -z "$server" ]] || { kill "$server" 2>/dev/null || true;wait "$server" 2>/dev/null || true; };echo "Browser recording logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$project/out" "$port" >"$work/server.log" 2>&1 &server=$!
node "$ROOT/tests/replay_network_recording/browser.mjs" "http://127.0.0.1:$port/index.html?role=solo&dev=1&persist=0&audio=0&run=0&encounter=migration&resume=0&token=recording-browser" "$native/verify_recording" "$work/browser" >"$work/driver.log" 2>&1
cat "$work/driver.log"
