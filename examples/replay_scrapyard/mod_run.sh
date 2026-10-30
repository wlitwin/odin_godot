#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard mod logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import sys,json,copy
root=Path(sys.argv[1]);work=Path(sys.argv[2]);mods=work/'mods';decoy=work/'decoy';mods.mkdir();decoy.mkdir()
base=json.loads((root/'tests/replay_scrapyard/fixtures/mod-junk.json').read_text())
early=copy.deepcopy(base);early['guns'][0]['name']='earlier';early['guns'][0]['dmg']=2
(mods/'00-earlier.json').write_text(json.dumps(early));(mods/'10-junk.json').write_text(json.dumps(base))
gun=copy.deepcopy(base['guns'][0]);gun['id']=9;gun['name']='spare'
sparse={'guns':[gun],'status':[{'id':12,'name':'focus','duration':600,'max_stacks':1,'move_mult':1,'dot_dmg':0,'dot_every':0,'taken_mult':1,'dealt_mult':2,'tint':[1,1,1,0.5]}], 'abilities':[{'id':11,'name':'focus','family':'buff','cooldown':120,'range':200,'radius':0,'arc_cos':0,'speed':1,'dmg':0,'status':12,'self_buff':True}]}
(mods/'20-sparse.json').write_text(json.dumps(sparse))
bad=copy.deepcopy(base);bad['guns'][0]['name']='must-not-commit';bad['mobs'][0]['id']=999
(mods/'90-invalid.json').write_text(json.dumps(bad));(mods/'95-broken.json').write_text('{bad')
decoy_data=copy.deepcopy(base);decoy_data['guns'][0]['name']='client-only';(decoy/'decoy.json').write_text(json.dumps(decoy_data))
PY
export RSY_RESULT_DIR="$work" RSY_SAVE="$work/run.replay" RSY_RUN=0 RSY_MOBS=4 RSY_ENCOUNTER=melee RSY_PERSIST=0 RSY_LATENCY="${RSY_LATENCY:-120}" RSY_PORT=$((40000 + RANDOM % 10000))
launch() {
 local role="$1" directory="$work/decoy"
 if [[ "$role" == host ]]; then directory="$work/mods"; fi
 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="mod-$role" RSY_MODS_DIR="$directory" "$GODOT" --headless --path "$PROJ" --script mod_test.gd >"$work/$role.log" 2>&1 & pids+=("$!")
}
launch host
sleep 0.5
launch client
deadline=$((SECONDS+70))
while [[ ! -f "$work/mod-ready.json" ]]; do
 if ((SECONDS>=deadline)) || rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
 sleep 0.05
done
launch observer
while ((SECONDS<deadline)); do
 live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
 if ((live==0));then break;fi
 if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/observer.log"
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client observer;do rg -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$role.log";done
rg -q 'RSY_MODS_SKIP file=90-invalid.json' "$work/host.log"
if rg -q RSY_MODS "$work/client.log" "$work/observer.log";then exit 1;fi
RSY_ROLE=solo RSY_TOKEN=mod-host RSY_MODS_DIR="$work/decoy" RSY_MOD_PHASE=resume RSY_RESUME=1 "$GODOT" --headless --path "$PROJ" --script mod_test.gd >"$work/resume.log" 2>&1
cat "$work/resume.log";rg -q RSY_MOD_RESUME_OK "$work/resume.log"
if rg -q 'RSY_MODS|SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/resume.log";then exit 1;fi
if rg -q 'ObjectDB instances were leaked' "$work/"*.log;then exit 1;fi
echo REPLAY_SCRAPYARD_MOD_OK
