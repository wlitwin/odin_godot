#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]];then echo "Missing original sibling Scrapyard" >&2;exit 1;fi
work="${REPLAY_INPUT_AUDIT_OUT:-$(mktemp -d)}";mkdir -p "$work";export SCRIPT_BUILD_FLAGS=-o:speed
if [[ -e "$work/replay" || -e "$work/contract.json" ]];then echo "Fresh output directory required: $work";exit 2;fi
python3 "$ROOT/tests/replay_network_faults/proxy_test.py" >"$work/proxy-tests.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
if [[ -n "${REPLAY_INPUT_AUDIT_REUSE:-}" ]];then
 python3 "$ROOT/tests/replay_input_audit/reuse.py" "$REPLAY_INPUT_AUDIT_REUSE" "$work"
 project="$(cd "$work/replay/project" && pwd -P)";export ODIN_GODOT_ROOT="$(cd "$work/framework" && pwd -P)"
else
python3 "$ROOT/tests/replay_input_audit/prepare.py" "$work" >"$work/prepare.log"
project="$work/replay/project";case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_GODOT_ROOT="$work/framework"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
python3 - "$work" "$ext" <<'PY'
from pathlib import Path
import hashlib,json,sys,subprocess
root=Path(sys.argv[1]);(root/'build-manifest.json').write_text(json.dumps({'odin':subprocess.check_output(['odin','version'],text=True).strip(),'flags':['-debug','-o:speed'],'binaries':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'replay/project/bin').glob('*.'+sys.argv[2])}},indent=2)+'\n')
PY
fi
pids=();proxy_pid="";trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;if [[ -n "$proxy_pid" ]];then kill "$proxy_pid" 2>/dev/null || true;wait "$proxy_pid" 2>/dev/null || true;fi;echo "Input audit logs: $work"' EXIT
repetitions=${REPLAY_INPUT_AUDIT_PAIRS:-3};conditions=lossy
if [[ "${REPLAY_NETWORK_FAULT_PILOT:-0}" == 1 ]];then repetitions=1;conditions=lossy;fi
python3 - "$work" "$repetitions" "$conditions" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1]);(root/'run-plan.json').write_text(json.dumps({'repetitions':int(sys.argv[2]),'conditions':sys.argv[3].split()},indent=2)+'\n')
PY
for ((pair=1;pair<=repetitions;pair++));do
 for condition in $conditions;do
  folder="$work/pair-$pair/$condition";mkdir -p "$folder"
  read -r host_port front_port < <(python3 - <<'PY'
import socket
s=[socket.socket(socket.AF_INET,socket.SOCK_DGRAM) for _ in range(2)]
for sock in s:sock.bind(('127.0.0.1',0))
print(*(sock.getsockname()[1] for sock in s))
for sock in s:sock.close()
PY
)
  python3 - "$work/contract.json" "$condition" "$folder/proxy-config.json" <<'PY'
from pathlib import Path
import json,sys
Path(sys.argv[3]).write_text(json.dumps(json.loads(Path(sys.argv[1]).read_text())['conditions'][sys.argv[2]]['raw_udp'],indent=2)+'\n')
PY
  python3 "$ROOT/tests/replay_network_faults/proxy.py" --listen "$front_port" --host "$host_port" --config "$folder/proxy-config.json" --out "$folder/proxy" --seed "$((1337+pair))" >"$folder/proxy.log" 2>&1 &proxy_pid=$!
  for _ in {1..100};do [[ -f "$folder/proxy/ready.json" ]] && break;sleep 0.05;done
  [[ -f "$folder/proxy/ready.json" ]];pids=()
  for role in host client;do
   port="$front_port";if [[ "$role" == host ]];then port="$host_port";fi
   COMPARE_REUSE_EQUAL=0 COMPARE_CONDITION=lossy COMPARE_IMPL=replay COMPARE_ROLE="$role" COMPARE_DIR="$folder" COMPARE_PHASES=0 \
   RSY_TRACE=0 RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="endurance-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY=0 RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
   ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
   sleep 0.3
  done
  deadline=$((SECONDS+100))
  while ((SECONDS<deadline));do
   live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
   ((live==0)) && break
   if rg -q 'ENDURANCE_FAIL|JAM_WORKLOAD_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
   sleep 0.1
  done
  ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
  kill "$proxy_pid";wait "$proxy_pid";proxy_pid=""
 done
done
echo REPLAY_INPUT_AUDIT_CAPTURED
