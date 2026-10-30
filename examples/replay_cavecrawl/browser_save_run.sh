#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_BROWSER_SAVE_OUT:-$(mktemp -d)}";mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore"
trap 'echo "Browser save logs: $work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
port="${REPLAY_BROWSER_SAVE_PORT:-$((22000+RANDOM%8000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$port" >"$work/http.log" 2>&1 & serving=$!
trap 'kill "$serving" 2>/dev/null || true;wait "$serving" 2>/dev/null || true;echo "Browser save logs: $work"' EXIT
node "$PROJ/browser_save_drive.mjs" "http://127.0.0.1:$port/index.html" "$work"
