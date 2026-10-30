#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_unions/godot";work="${REPLAY_UNION_ENET_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Union ENet logs: $work"' EXIT
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
export UNION_PORT=$((40000+RANDOM%10000)) UNION_DIR="$work"
for role in host client;do UNION_ROLE="$role" "$GODOT" --headless --max-fps 60 --path "$PROJ" >"$work/$role.log" 2>&1 &pids+=("$!");sleep 0.3;done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client;do
 cat "$work/$role.log";rg -q REPLAY_UNION_ENET_OK "$work/$role.log"
 if rg -q 'SCRIPT ERROR|ERROR:|UNION_NET_FAIL|instances were leaked|resources still in use' "$work/$role.log";then exit 1;fi
done
cmp "$work/host.txt" "$work/client.txt"
odin check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
echo REPLAY_UNION_NETWORK_OK
