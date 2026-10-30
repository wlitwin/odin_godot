#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_MOVEMENT_OUT:-$(mktemp -d)}";mkdir -p "$work"
[[ -z "$(ls -A "$work")" ]] || { echo "Movement audit needs an empty output directory" >&2;exit 2; }
export SCRIPT_BUILD_FLAGS=-o:speed COMPARE_PHASES=0
python3 "$ROOT/tests/replay_movement_audit/prepare_framework.py" "$work/framework" >"$work/framework.log"
python3 "$ROOT/tests/replay_movement_audit/prepare.py" "$work" "$work/framework" >"$work/prepare.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
for variant in original owner_preserved;do
 collection="$ROOT";[[ "$variant" == owner_preserved ]] && collection="$work/framework"
 project="$work/$variant/project"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$variant/build.log" 2>&1
 ODIN_GODOT_ROOT="$collection" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$variant/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$variant/wait.json"
 ODIN_GODOT_ROOT="$collection" bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$variant/final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$variant/import.log";then cat "$work/$variant/import.log";exit 1;fi
done
python3 - "$work" "$ext" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys
p=Path(sys.argv[1]);(p/'build.json').write_text(json.dumps({'flags':['-debug','-o:speed'],'odin':subprocess.check_output(['odin','version'],text=True).strip(),'binaries':{str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for v in ('original','owner_preserved') for f in (p/v/'project/bin').glob('*.'+sys.argv[2])}},indent=2)+'\n')
PY
pids=();trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Movement audit logs: $work"' EXIT
for pair in 1 2 3;do
 order='original owner_preserved';((pair%2==0)) && order='owner_preserved original'
 for variant in $order;do
  project="$work/$variant/project";folder="$work/pair-$pair/$variant";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
  collection="$ROOT";[[ "$variant" == owner_preserved ]] && collection="$work/framework"
  for role in host client;do
   ODIN_GODOT_ROOT="$collection" COMPARE_IMPL=kit COMPARE_ROLE="$role" COMPARE_DIR="$folder" SY_ROLE= SY_NAME="$role" SY_TOKEN="mixed-$role" SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=0 SY_WAVES=1 SY_BARRELS=0 SY_LATENCY=120 SY_JITTER=0 SY_LOSS=0 SY_BURST=0 SY_BANDWIDTH=0 SY_PORT="$port" SY_MAG=0 SY_NOJAM=0 SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
   sleep .3
  done
  deadline=$((SECONDS+90))
  while ((SECONDS<deadline));do
   live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
   ((live==0)) && break
   if rg -q 'MIXED_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
   sleep .1
  done
  ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
 done
done
python3 "$ROOT/tests/replay_movement_audit/report.py" "$work"
python3 "$ROOT/tests/replay_movement_audit/verify_report.py" "$work"
echo REPLAY_MOVEMENT_AUDIT_OK
