#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]];then echo "Missing original sibling Scrapyard" >&2;exit 1;fi
work="${REPLAY_JAM_OUT:-$(mktemp -d)}";mkdir -p "$work";export SCRIPT_BUILD_FLAGS=-o:speed
if [[ -e "$work/kit" || -e "$work/replay" || -e "$work/contract.json" ]];then echo "Comparison requires a fresh output directory: $work";exit 2;fi
export COMPARE_PHASES=0
export REPLAY_JAM_OWNER_CONTROL=1
export RSY_SNAPSHOT_EVERY="${REPLAY_JAM_SNAPSHOT_EVERY:-3}"
[[ "$RSY_SNAPSHOT_EVERY" =~ ^([1-9]|[12][0-9]|30)$ ]] || { echo "Snapshot interval must be 1..30" >&2;exit 2; }
if [[ -n "${REPLAY_JAM_REUSE:-}" ]];then echo "This workload requires a fresh verified build" >&2;exit 2;fi
python3 "$ROOT/tests/replay_jam_comparison/prepare.py" "$work" >"$work/prepare.log"
kit_collection="$ROOT"
if [[ "${REPLAY_JAM_OWNER_CONTROL:-0}" == 1 ]];then
 if [[ -n "${REPLAY_JAM_REUSE:-}" ]];then echo "Owner-control runs require their own verified build" >&2;exit 2;fi
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
for impl in kit replay;do
 project="$work/$impl/project"
 collection="$ROOT";[[ "$impl" == kit ]] && collection="$kit_collection"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/build.log" 2>&1
 ODIN_GODOT_ROOT="$collection" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$impl/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$impl/import.log";then cat "$work/$impl/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$impl/build-wait.json"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/final-build.log" 2>&1
done
repetitions=3;if [[ "${REPLAY_JAM_PILOT:-0}" == 1 ]];then repetitions=1;fi
python3 - "$work" "$ext" "$repetitions" "$ROOT" "$kit_collection" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys,os
root=Path(sys.argv[1]);ext=sys.argv[2]
(root/'build-manifest.json').write_text(json.dumps({'collections':{'kit':sys.argv[5],'replay':sys.argv[4]},'odin':subprocess.check_output(['odin','version'],text=True).strip(),'flags':['-debug','-o:speed'],'binaries':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for impl in ('kit','replay') for p in (root/impl/'project/bin').glob('*.'+ext)}},indent=2)+'\n')
(root/'run-plan.json').write_text(json.dumps({'repetitions':int(sys.argv[3]),'owner_control':sys.argv[4]!=sys.argv[5],'correction_reuse':False,'trace_actions':os.environ.get('REPLAY_JAM_TRACE','0')=='1','snapshot_every':int(os.environ['RSY_SNAPSHOT_EVERY']),'conditions':os.environ.get('REPLAY_JAM_CONDITIONS','delay lossy').split()},indent=2)+'\n')
PY
proxy_pid="";pids=();trap '[[ -z "$proxy_pid" ]] || { kill "$proxy_pid" 2>/dev/null || true;wait "$proxy_pid" 2>/dev/null || true; };for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Jam comparison logs: $work"' EXIT
for condition in ${REPLAY_JAM_CONDITIONS:-delay lossy};do
for ((pair=1;pair<=repetitions;pair++));do
 order='kit replay';if ((pair%2==0));then order='replay kit';fi
 for impl in $order;do
  project="$work/$impl/project";folder="$work/$condition/pair-$pair/$impl";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
  collection="$ROOT";[[ "$impl" == kit ]] && collection="$kit_collection"
  latency=120;host_port="$port";front_port="$port"
  if [[ "$condition" == lossy ]];then
   latency=0
   read -r host_port front_port < <(python3 - <<'PYPORT'
import socket
s=[socket.socket(socket.AF_INET,socket.SOCK_DGRAM) for _ in range(2)]
for sock in s:sock.bind(('127.0.0.1',0))
print(*(sock.getsockname()[1] for sock in s))
for sock in s:sock.close()
PYPORT
)
   python3 - "$work/contract.json" "$folder/proxy-config.json" <<'PYCONFIG'
from pathlib import Path
import json,sys
Path(sys.argv[2]).write_text(json.dumps(json.loads(Path(sys.argv[1]).read_text())['conditions']['lossy']['raw_udp'],indent=2)+'\n')
PYCONFIG
   python3 "$ROOT/tests/replay_network_faults/proxy.py" --listen "$front_port" --host "$host_port" --config "$folder/proxy-config.json" --out "$folder/proxy" --seed "$((1337+pair))" >"$folder/proxy.log" 2>&1 &proxy_pid=$!
   for _ in {1..100};do [[ -f "$folder/proxy/ready.json" ]] && break;sleep .05;done
   [[ -f "$folder/proxy/ready.json" ]]
  fi
  for role in host client;do
   port="$front_port";[[ "$role" == host ]] && port="$host_port"
   COMPARE_CONDITION="$condition" COMPARE_REUSE_EQUAL=0 ODIN_GODOT_ROOT="$collection" COMPARE_IMPL="$impl" COMPARE_ROLE="$role" COMPARE_DIR="$folder" \
   SY_ROLE= SY_NAME="$role" SY_TOKEN="endurance-$role" SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=0 SY_WAVES=1 SY_BARRELS=0 SY_LATENCY="$latency" SY_JITTER=0 SY_LOSS=0 SY_BURST=0 SY_BANDWIDTH=0 SY_PORT="$port" SY_MAG=0 SY_NOJAM=0 SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
   RSY_TRACE="${REPLAY_JAM_TRACE:-0}" RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="endurance-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY="$latency" RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
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
   if rg -q 'JAM_WORKLOAD_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
   sleep 0.1
  done
  ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
  if [[ -n "$proxy_pid" ]];then kill "$proxy_pid";wait "$proxy_pid";proxy_pid="";fi
 done
done
done
if [[ "${REPLAY_JAM_PILOT:-0}" == 1 ]];then python3 "$ROOT/tests/replay_jam_comparison/report.py" "$work" --allow-partial;echo REPLAY_JAM_PILOT_OK
else python3 "$ROOT/tests/replay_jam_comparison/report.py" "$work";python3 "$ROOT/tests/replay_jam_comparison/verify_report.py" "$work";echo REPLAY_JAM_COMPARISON_OK;fi
