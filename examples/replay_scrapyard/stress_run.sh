#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";work="$(mktemp -d)";pids=()
cleanup() { for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]];then echo "Scrapyard stress logs: $work";else rm -rf "$work";fi; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
SCRIPT_BUILD_FLAGS="${SCRIPT_BUILD_FLAGS:--o:minimal}" bash "$ROOT/build/build_scripts.sh" "$PROJ"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
SCRIPT_BUILD_FLAGS="${SCRIPT_BUILD_FLAGS:--o:minimal}" bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi
# Match the original stress harness's magazine/no-jam override through data.
mkdir "$work/mods"
python3 - "$PROJ/data/guns" "$work/mods/bench.json" <<'PYMOD'
from pathlib import Path
import re,json,sys
rows=[]
for p in sorted(Path(sys.argv[1]).glob('*.tres')):
 text=p.read_text()
 def number(key):return float(re.search(r'^'+key+r' = ([0-9.]+)$',text,re.M)[1])
 def vector(key):return [float(v) for v in re.search(r'^'+key+r' = Vector2\(([^)]+)\)',text,re.M)[1].split(',')]
 row={key:int(number(key)) for key in ['id','cooldown','dmg','reload_ticks','jam_taps','ttl']}
 row.update(name=re.search(r'^name = "([^"]+)"',text,re.M)[1],kind=['bolt','rivet','nade','lance','mend'][int(number('kind'))],mag=255,jam_per_mille=0,speed=number('speed'),sprite_pos=vector('sprite_pos'),sprite_size=vector('sprite_size'))
 rows.append(row)
Path(sys.argv[2]).write_text(json.dumps({'guns':rows}))
PYMOD
export RSY_MODS_DIR="$work/mods"
export RSY_RUN=1 RSY_WAVE_BASE=40 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_REST=300 RSY_BARRELS=0 RSY_PERSIST=0 RSY_RESULT_DIR="$work"
export RSY_PORT=$((40000+RANDOM%10000)) RSY_LATENCY="${RSY_LATENCY:-120}" RSY_REQUIRE_STOCK=0
for role in host client;do
 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="stress-$role" "$GODOT" --headless --path "$PROJ" --script stress_test.gd >"$work/$role.log" 2>&1 & pids+=("$!")
 sleep 0.5
done
printf 'role,measuring,rss_kib\n' >"$work/rss.csv"
deadline=$((SECONDS+110))
while ((SECONDS<deadline));do
 live=0
 for i in 0 1;do
  role=host;if [[ "$i" == 1 ]];then role=client;fi
  pid="${pids[$i]}"
  if kill -0 "$pid" 2>/dev/null;then
   live=1;sample=0
   if [[ -f "$work/measuring-$role.json" && ! -f "$work/sampled-$role.json" ]];then sample=1;fi
   rss="$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')"
   if [[ -n "$rss" ]];then printf '%s,%s,%s\n' "$role" "$sample" "$rss" >>"$work/rss.csv";fi
  fi
 done
 if ((live==0));then break;fi
 if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep 0.1
done
cat "$work/host.log" "$work/client.log"
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
if rg -q 'ObjectDB instances were leaked' "$work/"*.log;then exit 1;fi
python3 "$PROJ/tools/stress_report.py" "$work"
echo REPLAY_SCRAPYARD_STRESS_OK
