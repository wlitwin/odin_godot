#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_SOCIAL_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Social logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1;fi
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
export REPLAY_CAVE_PORT=$((40000+RANDOM%10000)) REPLAY_SOCIAL_DIR="$work" REPLAY_CAVE_LATENCY=120 REPLAY_CAVE_JITTER=20 REPLAY_CAVE_LOSS=500 REPLAY_CAVE_DUPLICATE=500
for role in host client observer;do
 if [[ "$role" == observer ]];then
  for _ in {1..200};do [[ ! -f "$work/late_join" ]] || break;sleep 0.05;done
  [[ -f "$work/late_join" ]]
 fi
 REPLAY_CAVE_ROLE="$role" REPLAY_CAVE_TOKEN="social-$role" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script social_test.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep 0.3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client observer;do
 cat "$work/$role.log";rg -q "REPLAY_CAVE_SOCIAL_OK role=$role" "$work/$role.log"
 if rg -q 'SCRIPT ERROR|ERROR:|CAVE_SOCIAL_FAIL|instances were leaked|resources still in use' "$work/$role.log";then exit 1;fi
done
echo REPLAY_CAVE_SOCIAL_ALL_OK
