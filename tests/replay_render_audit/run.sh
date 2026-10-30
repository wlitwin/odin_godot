#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_RENDER_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 "$ROOT/tests/replay_render_audit/prepare.py" "$work" >"$work/prepare.log"
node "$ROOT/tests/replay_render_audit/trace_test.mjs" >"$work/trace-test.log"
project="$work/project";server="$ROOT/tests/replay_web_authority/server"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for target in "$server" "$project";do
 label="${target##*/}"
 bash "$ROOT/build/build_scripts.sh" "$target" >"$work/$label-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$target/bin/libodinscripts.$ext" "$GODOT" --headless --path "$target" --editor --quit-after 120 >"$work/$label-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$target" "$work/$label-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$target" >"$work/$label-final-build.log" 2>&1
done
for script in mesh_probe_test glob_view_test area_view_test cast_path_test ordnance_view_test walls_test wounds_test actors_test;do
 RSY_PERSIST=0 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script "$script.gd" >"$work/$script.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:|WORKBENCH_FAIL|instances were leaked|resources still in use' "$work/$script.log";then cat "$work/$script.log";exit 1;fi
done
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/web-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then cat "$work/export.log";exit 1;fi
[[ -e "$ROOT/examples/replay_scrapyard/node_modules" ]] || ln -s "$ROOT/tests/web/node_modules" "$ROOT/examples/replay_scrapyard/node_modules"
port=$((21000+RANDOM%8000));control=$((31000+RANDOM%7000));pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Render audit: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$project/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
RWA_SIGNAL=1 RWA_SIGNAL_ONLY=1 RWA_GAME=scrapyard RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$server/bin/libodinscripts.$ext" "$GODOT" --headless --path "$server" >"$work/server.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep .1;done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
RSB_HARDWARE=1 RSB_RENDER_TRACE=1 node "$ROOT/examples/replay_scrapyard/web_ui_drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" "$work/browser" >"$work/driver.log" 2>&1
touch "$work/done";wait "${pids[1]}"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then cat "$work/server.log";exit 1;fi
python3 "$ROOT/tests/replay_render_audit/report.py" "$work"
