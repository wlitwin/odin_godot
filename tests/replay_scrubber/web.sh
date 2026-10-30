#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="$1";work="$2";mkdir -p "$work"
python3 - "$source" "$work" "$ROOT" <<'PY'
from pathlib import Path
import shutil,sys,json,hashlib
source,out,root=map(Path,sys.argv[1:]);project=out/'project'
shutil.copytree(source/'project',project,ignore=shutil.ignore_patterns('.godot','out'))
p=project/'project.godot';s=p.read_text();s=s.replace('run/main_scene="res://hello.tscn"','run/main_scene="res://scrubber_web.tscn"');assert 'run/main_scene="res://scrubber_web.tscn"' in s;p.write_text(s)
shutil.copy2(root/'tests/replay_scrubber/browser.gd',project/'scrubber_web.gd')
(project/'scrubber_web.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scrubber_web.gd" id="1"]\n[node name="ScrubberBrowser" type="Node"]\nscript = ExtResource("1")\n')
shutil.copy2(root/'tests/web/export_presets.cfg',project/'export_presets.cfg')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file() and 'bin' not in p.parts and not p.name.endswith('.gen.odin')},indent=2)+'\n')
PY
project="$work/project"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then tail -50 "$work/export.log";exit 1;fi
port=$((20000+RANDOM%9000));pid=""
trap '[[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };echo "Scrubber browser logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$project/out" "$port" >"$work/server.log" 2>&1 &pid=$!
REPLAY_RECORDING_VERIFY="$source/verify_recording" node "$ROOT/tests/replay_scrubber/browser.mjs" "http://127.0.0.1:$port/index.html" "$work/browser" >"$work/driver.log" 2>&1
cat "$work/driver.log"
