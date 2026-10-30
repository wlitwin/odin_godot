#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_CAMPAIGN_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Campaign logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
python3 - "$work/environment.json" <<'PYENV'
from pathlib import Path
import os,json,platform,sys
Path(sys.argv[1]).write_text(json.dumps({'platform':platform.platform(),'receive_delay_ms':120,'jitter_ms':int(os.environ.get('REPLAY_CAVE_JITTER','0')),'loss_permyriad':int(os.environ.get('REPLAY_CAVE_LOSS','0')),'duplicate_permyriad':int(os.environ.get('REPLAY_CAVE_DUPLICATE','0')),'hz':20,'roles':['host','client','observer'],'frame_cap':60,'seed':1337},indent=2)+'\n')
PYENV
export REPLAY_CAVE_PORT=$((40000+RANDOM%10000)) REPLAY_CAMPAIGN_DIR="$work" REPLAY_CAVE_LATENCY=120
for role in host client observer;do
 REPLAY_CAVE_ROLE="$role" REPLAY_CAVE_TOKEN="campaign-$role" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script campaign_test.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep 0.3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client observer;do
 cat "$work/$role.log";rg -q "REPLAY_CAVE_CAMPAIGN_OK role=$role" "$work/$role.log"
 if rg -q 'SCRIPT ERROR|ERROR:|CAVE_CAMPAIGN_FAIL|instances were leaked|resources still in use' "$work/$role.log";then exit 1;fi
done
if [[ "${REPLAY_CAMPAIGN_RESTART:-0}" == 1 ]];then
 for role in host client observer;do rg -q "REPLAY_CAVE_RESTART_OK role=$role" "$work/$role.log";done
 echo REPLAY_CAVE_RESTART_ALL_OK
fi
python3 "$PROJ/campaign_verify.py" "$work"
echo REPLAY_CAVE_CAMPAIGN_ALL_OK
