#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_duel";work="${RDP_REJOIN_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo 'Rejoin requires an empty output directory' >&2;exit 2; }
trap 'for pid in "${pids[@]}";do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };done;echo "P2P rejoin logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
fi
export RDP_TEST=1 RDP_LIVE_REJOIN=1 RDP_LATENCY=120 RDP_JITTER=20 RDP_LOSS=1000 RDP_DUPLICATE=1000 RDP_PORT=$((40000+RANDOM%12000))
RDP_ROLE=listen RDP_STAGE= "$GODOT" --headless --max-fps 60 --path "$PROJ" >"$work/listen.log" 2>&1 &pids+=("$!");listener="${pids[0]}"
for _ in {1..100};do rg -q REPLAY_DUEL_LISTENING "$work/listen.log" && break;sleep .05;done
RDP_ROLE=dial RDP_STAGE=save RDP_ARCHIVE="$work/dial.rply" "$GODOT" --headless --max-fps 60 --path "$PROJ" >"$work/saved-dial.log" 2>&1 &pids+=("$!")
deadline=$((SECONDS+35))
while ((SECONDS<deadline));do
 if rg -q 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 rg -q RDP_SAVED "$work/saved-dial.log" && break
 sleep .1
done
rg -q RDP_SAVED "$work/saved-dial.log"
kill -KILL "${pids[1]}";wait "${pids[1]}" 2>/dev/null || true;pids[1]=""
# Keep the listener alive through timeout; its simulation and input buffers remain.
deadline=$((SECONDS+10))
while ((SECONDS<deadline));do rg -q RDP_REJOIN_WAIT "$work/listen.log" && break;kill -0 "$listener";sleep .1;done
rg -q RDP_REJOIN_WAIT "$work/listen.log";kill -0 "$listener"
RDP_ROLE=dial RDP_STAGE=resume RDP_ARCHIVE="$work/dial.rply" "$GODOT" --headless --max-fps 60 --path "$PROJ" >"$work/dial.log" 2>&1 &pids+=("$!")
deadline=$((SECONDS+35))
while ((SECONDS<deadline));do
 if rg -q 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 live=0;for pid in "${pids[@]}";do if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null;then live=1;fi;done
 ((live==0)) && break;sleep .1
done
((SECONDS<deadline));for pid in "${pids[@]}";do [[ -z "$pid" ]] || wait "$pid";done;pids=()
rg -q 'RDP_LIVE_REBOUND count=1 .*retained=true' "$work/listen.log"
rg -q RDP_RESTORED "$work/dial.log"
node "$PROJ/check.mjs" "$work"
if rg -q 'instances were leaked|resources still in use|ERROR:' "$work/listen.log" "$work/dial.log";then exit 1;fi
echo REPLAY_DUEL_LIVE_REJOIN_OK
