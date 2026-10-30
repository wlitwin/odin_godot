#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";SERVER="$ROOT/tests/replay_web_authority/server";work="${RSB_LOGS:-$(mktemp -d)}"
for mode in ${RSB_MODES:-planned crash};do case "$mode" in planned|crash) ;; *) echo "Unsupported Scrapyard browser mode: $mode" >&2;exit 1 ;; esac;done
mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore";echo "Scrapyard browser logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$SERVER" >"$work/server-build.log" 2>&1
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for project in "$PROJ" "$SERVER";do
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
done
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
PORT="${PORT:-$((21000+RANDOM%9000))}";CONTROL="${CONTROL:-$((31000+RANDOM%9000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
server_pid="";trap 'kill "$http_pid" ${server_pid:-} 2>/dev/null || true' EXIT
python3 - "$work/tag.png" <<'PYFIX'
import hashlib,random,struct,sys,zlib
from pathlib import Path
rng=random.Random(888)
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
pixels=bytearray()
for y in range(128):
 pixels.append(0)
 for x in range(128):pixels.extend((rng.randrange(256),rng.randrange(256),255,255))
data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
Path(sys.argv[1]).write_bytes(data);Path(sys.argv[1]+'.sha256').write_text(hashlib.sha256(data).hexdigest())
PYFIX
hash="$(cat "$work/tag.png.sha256")"
for mode in ${RSB_MODES:-planned crash};do
 mkdir -p "$work/$mode"
 RWA_SIGNAL=1 RWA_GAME=scrapyard RWA_PORT="$CONTROL" RWA_DB="$work/$mode/authority.sqlite" RWA_DONE="$work/$mode/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVER" >"$work/$mode/server.log" 2>&1 & server_pid=$!
 for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/$mode/server.log";then break;fi;sleep 0.1;done
 RSB_LOGS="$work/$mode" node "$PROJ/web_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$CONTROL/control" "$mode" "$work/tag.png" "$hash" | tee "$work/$mode/driver.log"
 touch "$work/$mode/done";wait "$server_pid";server_pid=""
 if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/$mode/server.log";then cat "$work/$mode/server.log";exit 1;fi
done
python3 "$PROJ/web_report.py" "$work"
echo REPLAY_SCRAPYARD_WEB_MIGRATION_OK
