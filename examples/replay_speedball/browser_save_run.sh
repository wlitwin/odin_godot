#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";work="${RSB_BROWSER_SAVE_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Speedball browser save logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
 export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-final.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 mkdir -p "$PROJ/out";touch "$PROJ/out/.gdignore"
 "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
fi
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
http=$((21000+RANDOM%9000))
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$http" >"$work/http.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html" 2>/dev/null;then break;fi;sleep .1;done
node "$PROJ/browser_save_drive.mjs" "http://127.0.0.1:$http/index.html" "$work/browser" | tee "$work/driver.log"
echo REPLAY_SPEEDBALL_BROWSER_SAVE_OK
