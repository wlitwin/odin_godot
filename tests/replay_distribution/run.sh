#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_DISTRIBUTION_OUT:-$(mktemp -d)}";mkdir -p "$work";work="$(cd "$work" && pwd -P)";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Replay package logs: $work"' EXIT
python3 "$ROOT/tests/replay_distribution/snapshot.py" "$ROOT" "$work/source"
nix build --no-link --print-out-paths "path:$work/source#default" >"$work/package-path.txt" 2>"$work/package-build.log"
package="$(tail -n 1 "$work/package-path.txt")/addons/odin_godot"
[[ -f "$package/replay/runner.odin" || -f "$package/replay/timeline.odin" ]]
[[ -f "$package/replay/.gdignore" && -f "$package/template/replay/main.tscn" && -f "$package/docs/replay.md" ]]
project="$work/consumer";mkdir -p "$project/addons"
cp -R "$package" "$project/addons/odin_godot"
chmod -R u+w "$project"
cp -R "$project/addons/odin_godot/template/replay/." "$project/"
cp "$ROOT/tests/replay_distribution/driver.gd" "$project/driver.gd"
addon="$project/addons/odin_godot"
export ODIN_GODOT_ROOT="$addon"
unset ODIN_SCRIPTS_DLL
SKIP_CORE=1 bash "$addon/build/build_scripts.sh" "$project" >"$work/consumer-build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
SKIP_CORE=1 bash "$addon/build/build_scripts.sh" "$project" >"$work/consumer-final-build.log" 2>&1
REPLAY_STARTER_ROLE=solo "$GODOT" --headless --path "$project" --script driver.gd >"$work/solo.log" 2>&1
rg -q REPLAY_PACKAGE_SOLO_OK "$work/solo.log"
export REPLAY_STARTER_PORT=$((41000+RANDOM%8000)) REPLAY_STARTER_TEST_DIR="$work"
for role in host client observer;do
 REPLAY_STARTER_ROLE="$role" "$GODOT" --headless --max-fps 60 --path "$project" --script driver.gd >"$work/$role.log" 2>&1 &pids+=("$!");sleep 0.3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client observer;do rg -q "REPLAY_PACKAGE_NETWORK_OK role=$role" "$work/$role.log";done
if rg -q 'REPLAY_PACKAGE_FAIL|REPLAY_STARTER_ERROR|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/solo.log "$work"/host.log "$work"/client.log "$work"/observer.log "$work"/import.log;then exit 1;fi
odin check "$project/scripts" -collection:godot="$addon" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
cp "$ROOT/tests/replay_distribution/browser_probe.gd" "$ROOT/tests/replay_distribution/browser_test.tscn" "$project/"
python3 - "$project/project.godot" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);p.write_text(p.read_text().replace('res://main.tscn','res://browser_test.tscn'))
PY
mkdir -p "$project/out";touch "$project/out/.gdignore"
bash "$addon/build/build_web.sh" "$project" >"$work/web-build.log" 2>&1
"$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
[[ -f "$project/out/libodin_godot.wasm" ]]
port=$((21000+RANDOM%9000))
bash "$addon/build/serve.sh" "$project/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$port/index.html" 2>/dev/null;then break;fi;sleep 0.1;done
node "$ROOT/tests/replay_distribution/drive.mjs" "http://127.0.0.1:$port/index.html" "$work"
python3 - "$ROOT" "$project" "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
root,project,out=map(Path,sys.argv[1:]);addon=project/'addons/odin_godot'
for name in ['core','godot','gdext','libgd','runtime','decl','flow','flowgd','events','kit','play','replay','scriptgen','template','build','docs']:
 assert (addon/name/'.gdignore').exists(),name
for p in (addon/'replay').rglob('*.odin'):
 assert p.read_bytes()==(out/'source'/p.relative_to(addon)).read_bytes(),p
source_refs=[]
for p in project.rglob('*.odin'):
 if str(root) in p.read_text(errors='replace'):source_refs.append(str(p.relative_to(project)))
assert not source_refs,source_refs
(out/'result.json').write_text(json.dumps({'addon':str(addon),'solo':True,'browser':True,'network_roles':['host','client','observer'],'original_checkout_references':source_refs,'replay_files':len(list((addon/'replay').rglob('*.odin')))},indent=2)+'\n')
print('REPLAY_PACKAGE_ISOLATED_OK')
PY
echo REPLAY_DISTRIBUTION_OK
