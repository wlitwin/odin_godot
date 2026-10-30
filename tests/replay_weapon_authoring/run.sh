#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_WEAPON_AUTHORING_OUT:-$(mktemp -d)}";mkdir -p "$work";export SCRIPT_BUILD_FLAGS=-o:speed
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
if [[ -n "${REPLAY_WEAPON_AUTHORING_REUSE:-}" ]];then
 python3 "$ROOT/tests/replay_weapon_authoring/reuse.py" "$REPLAY_WEAPON_AUTHORING_REUSE" "$work" >"$work/prepare.log"
else
python3 "$ROOT/tests/replay_weapon_authoring/prepare.py" "$work" >"$work/prepare.log"
for impl in kit replay;do for variant in new cold;do
 base="$work/$impl/$variant";project="$base/project"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$base/build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$base/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$base/import.log";then cat "$base/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$base/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$base/final-build.log" 2>&1
done;done
python3 - "$work" "$ext" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(sys.argv[1]);ext=sys.argv[2]
(root/'build.json').write_text(json.dumps({'odin':subprocess.check_output(['odin','version'],text=True).strip(),'flags':['-debug','-o:speed'],'binaries':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for impl in ['kit','replay'] for variant in ['new','cold'] for p in (root/impl/variant/'project/bin').glob('*.'+ext)}},indent=2)+'\n')
PY
fi
# Execute both generated catalogs independently of the Godot runtime.
for variant in new cold;do
 expected=8;if [[ "$variant" == cold ]];then expected=7;fi
 odin build "$ROOT/tests/replay_weapon_authoring/native_stock" -collection:godot="$ROOT" -collection:subject="$work/replay/$variant/project" -define:EXPECTED_GUNS="$expected" -out:"$work/stock-$variant"
 "$work/stock-$variant"
done
cases='shared_resource host_only_resource';conditions='local delayed';repetitions=2
if [[ "${REPLAY_WEAPON_AUTHORING_SMOKE:-0}" == 1 ]];then cases='shared_resource';conditions='local';repetitions=1;fi
python3 - "$work" "$cases" "$conditions" "$repetitions" <<'PY'
from pathlib import Path
import json,sys
(Path(sys.argv[1])/'run-plan.json').write_text(json.dumps({'cases':sys.argv[2].split(),'conditions':sys.argv[3].split(),'repetitions':int(sys.argv[4]),'receive_delay_ms':{'local':0,'delayed':120},'loss_permyriad':0,'duplicate_permyriad':0},indent=2)+'\n')
PY
pids=();trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Weapon authoring logs: $work"' EXIT
for ((pair=1;pair<=repetitions;pair++));do
 order='kit replay';if ((pair%2==0));then order='replay kit';fi
 for condition in $conditions;do
  delay=0;if [[ "$condition" == delayed ]];then delay=120;fi
  for scenario in $cases;do for impl in $order;do
   folder="$work/runs/$pair/$condition/$scenario/$impl";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
   for role in host client;do
    variant=new;if [[ "$role" == client && "$scenario" == host_only_resource ]];then variant=cold;fi
    project="$work/$impl/$variant/project"
    WEAPON_ROLE="$role" WEAPON_IMPL="$impl" WEAPON_CASE="$scenario" WEAPON_DIR="$folder" \
    SY_ROLE= SY_NAME="$role" SY_TOKEN="weapon-$role" SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=0 SY_WAVES=1 SY_BARRELS=0 SY_LATENCY="$delay" SY_JITTER=0 SY_LOSS=0 SY_BURST=0 SY_BANDWIDTH=0 SY_PORT="$port" SY_MAG=0 SY_NOJAM=0 SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
    RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="weapon-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=1 RSY_LATENCY="$delay" RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
    ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script weapon_authoring.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
    for _ in {1..240};do [[ -f "$folder/seated-$role.json" ]] && break;if rg -q 'WEAPON_AUTHORING_FAIL|SCRIPT ERROR|ERROR:' "$folder/$role.log";then cat "$folder/$role.log";exit 1;fi;sleep 0.05;done
    [[ -f "$folder/seated-$role.json" ]] || { cat "$folder/$role.log";exit 1; }
   done
   deadline=$((SECONDS+75))
   while ((SECONDS<deadline));do
    live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
    ((live==0)) && break
    if rg -q 'WEAPON_AUTHORING_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
    sleep 0.1
   done
   ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
   for role in host client;do rg -q REPLAY_WEAPON_AUTHORING_PEER_OK "$folder/$role.log";done
   if rg -q 'instances were leaked|resources still in use|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
  done;done
 done
done
if [[ "${REPLAY_WEAPON_AUTHORING_SMOKE:-0}" == 1 ]];then
 python3 "$ROOT/tests/replay_weapon_authoring/report.py" "$work" --allow-partial;echo REPLAY_WEAPON_AUTHORING_SMOKE_OK
else
 python3 "$ROOT/tests/replay_weapon_authoring/report.py" "$work"
 python3 "$ROOT/tests/replay_weapon_authoring/verify_report.py" "$work"
 echo REPLAY_WEAPON_AUTHORING_OK
fi
