#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";work="${RSB_SAVE_LOGS:-$(mktemp -d)}";mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore"
echo "Scrapyard browser save logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
python3 - "$work" <<'PY'
import random,struct,zlib,sys
from pathlib import Path
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
for name,seed in [('a',888),('b',889)]:
 rng=random.Random(seed);pixels=bytearray()
 for y in range(128):
  pixels.append(0)
  for x in range(128):pixels.extend((rng.randrange(256),rng.randrange(256),255,255))
 data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
 Path(sys.argv[1],name+'.png').write_bytes(data)
PY
PORT="${PORT:-$((21000+RANDOM%9000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
trap 'kill "$http_pid" 2>/dev/null || true' EXIT
RSB_SAVE_LOGS="$work" node "$PROJ/web_save_drive.mjs" "http://127.0.0.1:$PORT/index.html" "$work/a.png" "$work/b.png"
