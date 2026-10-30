#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";work="${RSB_ROUND_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Speedball round logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
fi
args=(--headless)
if [[ "${RSB_ROUND_RENDER:-0}" == 1 ]];then args=(--rendering-method gl_compatibility --audio-driver Dummy);fi
port=$((40000+RANDOM%10000))
for role in host client observer;do
 RSB_ROLE= RSB_BOT=idle RSB_UI_ROLE="$role" RSB_UI_DIR="$work" RSB_PORT="$port" RSB_TOKEN="round-$role" RSB_LATENCY=120 RSB_TEST=0 RSB_PLAYERS=2 RSB_GOALS=1 "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script round_test.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep .3
done
deadline=$((SECONDS+110))
while ((SECONDS<deadline));do
 live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
 ((live==0)) && break
 if rg -q 'SPEEDBALL_UI_FAIL|SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep .1
done
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client observer;do rg -q "REPLAY_SPEEDBALL_ROUND_PEER_OK role=$role" "$work/$role.log";done
if rg -q 'instances were leaked|resources still in use' "$work/"*.log;then exit 1;fi
python3 - "$work" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);rows=[json.loads((p/f'result-{role}.json').read_text()) for role in ('host','client','observer')]
for row in rows:
 assert row['round']==2 and row['winner']>0
 assert all(row[key]==rows[0][key] for key in ('winner','left','right','kicks','spikes'))
PY
echo REPLAY_SPEEDBALL_ROUND_OK
