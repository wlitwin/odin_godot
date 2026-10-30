#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]];then echo "REPLAY_COMPARISON_BASELINE_MISSING: requires original sibling Scrapyard";exit 0;fi
work="${REPLAY_MIXED_OUT:-$(mktemp -d)}";mkdir -p "$work";export SCRIPT_BUILD_FLAGS=-o:speed
if [[ -e "$work/kit" || -e "$work/replay" || -e "$work/contract.json" ]];then echo "Comparison requires a fresh output directory: $work";exit 2;fi
export COMPARE_PHASES=0
python3 "$ROOT/tests/replay_mixed_comparison/prepare.py" "$work" >"$work/prepare.log"
kit_collection="$ROOT"
if [[ "${REPLAY_MIXED_OWNER_CONTROL:-0}" == 1 ]];then
 if [[ -n "${REPLAY_MIXED_REUSE:-}" ]];then echo "Owner-control runs require their own verified build" >&2;exit 2;fi
 python3 "$ROOT/tests/replay_movement_audit/prepare_framework.py" "$work/owner-framework" >"$work/owner-framework.log"
 kit_collection="$work/owner-framework"
 python3 - "$work" <<'PYCONTROL'
from pathlib import Path
import hashlib,json,shutil,sys
root=Path(sys.argv[1]);control=json.loads((root/'framework-source.json').read_text());control['root']=str(root/'owner-framework')
control['sha256']={name:hashlib.sha256((root/'owner-framework'/name).read_bytes()).hexdigest() for name in control['sha256']}
(root/'kit-framework-source.json').write_text(json.dumps(control,indent=2)+'\n')
shutil.copy2(root/'owner-framework/repair.json',root/'owner-control.json')
PYCONTROL
fi
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
if [[ -n "${REPLAY_MIXED_REUSE:-}" ]];then
 python3 "$ROOT/tests/replay_mixed_comparison/reuse.py" "$REPLAY_MIXED_REUSE" "$work"
else
for impl in kit replay;do
 project="$work/$impl/project"
 collection="$ROOT";[[ "$impl" == kit ]] && collection="$kit_collection"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/build.log" 2>&1
 ODIN_GODOT_ROOT="$collection" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$impl/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$impl/import.log";then cat "$work/$impl/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$impl/build-wait.json"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/final-build.log" 2>&1
done
fi
repetitions=3;if [[ "${REPLAY_MIXED_PILOT:-0}" == 1 ]];then repetitions=1;fi
python3 - "$work" "$ext" "$repetitions" "$ROOT" "$kit_collection" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys,os
root=Path(sys.argv[1]);ext=sys.argv[2]
(root/'build-manifest.json').write_text(json.dumps({'collections':{'kit':sys.argv[5],'replay':sys.argv[4]},'odin':subprocess.check_output(['odin','version'],text=True).strip(),'flags':['-debug','-o:speed'],'binaries':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for impl in ('kit','replay') for p in (root/impl/'project/bin').glob('*.'+ext)}},indent=2)+'\n')
(root/'run-plan.json').write_text(json.dumps({'repetitions':int(sys.argv[3]),'owner_control':sys.argv[4]!=sys.argv[5],'correction_reuse':os.environ.get('REPLAY_MIXED_REUSE_EQUAL','0')=='1'},indent=2)+'\n')
PY
pids=();trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Mixed comparison logs: $work"' EXIT
for ((pair=1;pair<=repetitions;pair++));do
 order='kit replay';if ((pair%2==0));then order='replay kit';fi
 for impl in $order;do
  project="$work/$impl/project";folder="$work/pair-$pair/$impl";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
  collection="$ROOT";[[ "$impl" == kit ]] && collection="$kit_collection"
  for role in host client;do
   COMPARE_REUSE_EQUAL="${REPLAY_MIXED_REUSE_EQUAL:-0}" ODIN_GODOT_ROOT="$collection" COMPARE_IMPL="$impl" COMPARE_ROLE="$role" COMPARE_DIR="$folder" \
   SY_ROLE= SY_NAME="$role" SY_TOKEN="mixed-$role" SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=0 SY_WAVES=1 SY_BARRELS=0 SY_LATENCY=120 SY_JITTER=0 SY_LOSS=0 SY_BURST=0 SY_BANDWIDTH=0 SY_PORT="$port" SY_MAG=0 SY_NOJAM=0 SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
   RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="mixed-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY=120 RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
   ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
   sleep 0.3
  done
  printf 'role,measuring,rss_kib\n' >"$folder/rss.csv"
  deadline=$((SECONDS+90))
  while ((SECONDS<deadline));do
   live=0
   for i in 0 1;do
    pid="${pids[$i]}";label=host;if ((i==1));then label=client;fi
    if kill -0 "$pid" 2>/dev/null;then
     live=1;measuring=0;if [[ -f "$folder/measuring-$label.json" && ! -f "$folder/sampled-$label.json" ]];then measuring=1;fi
     rss=$({ ps -p "$pid" -o rss= 2>/dev/null || true; } | tr -d ' ');if [[ -n "$rss" ]];then printf '%s,%s,%s\n' "$label" "$measuring" "$rss" >>"$folder/rss.csv";fi
    fi
   done
   ((live==0)) && break
   if rg -q 'MIXED_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
   sleep 0.1
  done
  ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
 done
done
if [[ "${REPLAY_MIXED_PILOT:-0}" == 1 ]];then python3 "$ROOT/tests/replay_mixed_comparison/report.py" "$work" --allow-partial;echo REPLAY_MIXED_PILOT_OK
else python3 "$ROOT/tests/replay_mixed_comparison/report.py" "$work";python3 "$ROOT/tests/replay_mixed_comparison/verify_report.py" "$work";echo REPLAY_MIXED_COMPARISON_OK;fi
