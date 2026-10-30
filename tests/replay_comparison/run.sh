#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
export SCRIPT_BUILD_FLAGS=-o:speed
scenario="${REPLAY_COMPARISON_SCENARIO:-idle}"
case "$scenario" in idle|firing|combat) ;; *) echo "Unknown comparison scenario: $scenario";exit 2;; esac
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]];then
 echo "REPLAY_COMPARISON_BASELINE_MISSING: requires the original sibling Scrapyard project"
 exit 0
fi
work="${REPLAY_COMPARISON_DIR:-$(mktemp -d)}";mkdir -p "$work"
if [[ -e "$work/kit" || -e "$work/replay" || -e "$work/contract.json" ]];then echo "Comparison requires a fresh output directory: $work";exit 2;fi
echo "Comparison logs: $work"
python3 "$ROOT/tests/replay_comparison/prepare.py" "$work" >"$work/prepare.log"
for implementation in kit replay;do
 SCRIPT_BUILD_FLAGS=-o:speed bash "$ROOT/build/build_scripts.sh" "$work/$implementation/project" >"$work/$implementation/build.log" 2>&1
done
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for implementation in kit replay;do
 project="$work/$implementation/project"
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$implementation/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$implementation/import.log";then cat "$work/$implementation/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$implementation/import-build-wait.json"
done
# Import may invoke the editor's rebuild worker. Finish with an explicit build
# after the editor exits, then fingerprint the exact artifacts used by all runs.
for implementation in kit replay;do
 bash "$ROOT/build/build_scripts.sh" "$work/$implementation/project" >"$work/$implementation/final-build.log" 2>&1
done
python3 - "$work" "$ext" <<'PYBUILD'
from pathlib import Path
import hashlib,json,platform,sys,subprocess
root=Path(sys.argv[1]);ext=sys.argv[2];binaries={}
for implementation in ['kit','replay']:
 for p in (root/implementation/'project/bin').glob('*.'+ext):binaries[str(p.relative_to(root))]=hashlib.sha256(p.read_bytes()).hexdigest()
(root/'build-manifest.json').write_text(json.dumps({'binaries':binaries,'script_flags':['-debug','-o:speed'],'platform':platform.platform(),'odin':subprocess.check_output(['odin','version'],text=True).strip(),'final_build_after_editor_import':True},indent=2)+'\n')
PYBUILD
pids=();trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done' EXIT
for ((pair=1;pair<=${REPLAY_COMPARISON_REPETITIONS:-3};pair++));do
 order='kit replay';if ((pair%2==0));then order='replay kit';fi
 for implementation in $order;do
  project="$work/$implementation/project";folder="$work/pair-$pair/$implementation";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
  for role in host client;do
   COMPARE_SCENARIO="$scenario" COMPARE_IMPL="$implementation" COMPARE_ROLE="$role" COMPARE_DIR="$folder" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" \
    SY_ROLE= SY_NAME="$role" SY_TOKEN="compare-$pair-$role" SY_FRESH=1 SY_MAG=0 SY_NOJAM=0 SY_SEED=1337 SY_HZ=60 SY_MOBS=0 SY_WAVES=1 SY_BARRELS=0 SY_LATENCY=120 SY_PORT="$port" SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
    RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="compare-$pair-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY=120 RSY_PORT="$port" RSY_RESULT_DIR="$folder" COMPARE_PHASES="${REPLAY_COMPARISON_PHASES:-0}" \
    "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
   sleep 0.3
  done
  printf 'role,rss_kib\n' >"$folder/rss.csv"
  deadline=$((SECONDS+40))
  while ((SECONDS<deadline));do
   live=0
   for i in 0 1;do
    if kill -0 "${pids[$i]}" 2>/dev/null;then
     live=1;label=host;if ((i==1));then label=client;fi
     value=$({ ps -p "${pids[$i]}" -o rss= 2>/dev/null || true; } | tr -d ' ');if [[ -n "$value" ]];then printf '%s,%s\n' "$label" "$value" >>"$folder/rss.csv";fi
    fi
   done
   if ((live==0));then break;fi
   if rg -q 'COMPARE_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
   sleep 0.1
  done
  ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
  for role in host client;do rg -q "COMPARE_OK $role" "$folder/$role.log";done
  if rg -q 'instances were leaked|resources still in use|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
 done
done
python3 "$ROOT/tests/replay_comparison/report.py" "$work"
if [[ "$scenario" == combat ]];then echo REPLAY_COMPARISON_COMBAT_OK;elif [[ "$scenario" == firing ]];then echo REPLAY_COMPARISON_FIRING_OK;else echo REPLAY_COMPARISON_IDLE_OK;fi
