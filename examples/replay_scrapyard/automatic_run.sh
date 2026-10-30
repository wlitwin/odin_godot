#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";work="${REPLAY_AUTO_OUT:-$(mktemp -d)}";mkdir -p "$work/profiles" "$work/early-profiles"
host_pid=""
cleanup(){ if [[ -n "$host_pid" ]];then kill "$host_pid" 2>/dev/null || true;wait "$host_pid" 2>/dev/null || true;fi;echo "Automatic preference logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
export RSY_PROFILE_DIR="$work/profiles" RSY_TOKEN=automatic-preference-test RSY_PERSIST=1 RSY_RUN=0 RSY_MOBS=0 RSY_AUDIO=0 RSY_SPRAY="$work/absent.png" RSY_PORT=$((42000+RANDOM%9000))
RSY_ROLE=solo RSY_AUTO_PHASE=early RSY_PROFILE_DIR="$work/early-profiles" RSY_TOKEN=automatic-early-test "$GODOT" --headless --path "$PROJ" --script automatic_test.gd >"$work/early.log" 2>&1
rg -q REPLAY_AUTOMATIC_EARLY_OK "$work/early.log"
RSY_ROLE=solo RSY_AUTO_PHASE=create "$GODOT" --headless --path "$PROJ" --script automatic_test.gd >"$work/create.log" 2>&1
rg -q REPLAY_AUTOMATIC_CREATED "$work/create.log"
RSY_ROLE=host RSY_TOKEN=automatic-other-host RSY_PERSIST=0 "$GODOT" --headless --path "$PROJ" >"$work/host.log" 2>&1 & host_pid=$!
for _ in {1..100};do if rg -q REPLAY_SCRAPYARD_READY "$work/host.log";then break;fi;sleep 0.05;done
RSY_ROLE=client RSY_AUTO_PHASE=client "$GODOT" --headless --path "$PROJ" --script automatic_test.gd >"$work/client.log" 2>&1
rg -q REPLAY_AUTOMATIC_RESEATED "$work/client.log";rg -q REPLAY_AUTOMATIC_EXPLICIT_SAVED "$work/client.log"
kill "$host_pid";wait "$host_pid" 2>/dev/null || true;host_pid=""
RSY_ROLE=solo RSY_AUTO_PHASE=explicit "$GODOT" --headless --path "$PROJ" --script automatic_test.gd >"$work/explicit.log" 2>&1
rg -q REPLAY_AUTOMATIC_EXPLICIT_RELOADED "$work/explicit.log"
if rg -q 'SCRIPT ERROR|ERROR:|RSY_AUTO_FAIL|RSY_PROFILE_ERROR|instances were leaked' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
cat "$work/create.log" "$work/client.log" "$work/explicit.log"
echo REPLAY_SCRAPYARD_AUTOMATIC_OK
