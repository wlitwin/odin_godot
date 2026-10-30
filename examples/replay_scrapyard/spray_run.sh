#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard spray logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 - "$work" <<'PY'
import sys,struct,zlib,random,hashlib,json
from pathlib import Path
root=Path(sys.argv[1]);refs={}
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
for index,name in enumerate(['host','client','replacement']):
 rng=random.Random(100+index);pixels=bytearray()
 for y in range(128):
  pixels.append(0)
  for x in range(128):
   color=[rng.randrange(256) for _ in range(3)];color[index]=255
   pixels.extend((*color,255))
 data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
 (root/(name+'.png')).write_bytes(data);refs[name]={'hash':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
(root/'bad.png').write_bytes(b'not a png')
(root/'fixtures.json').write_text(json.dumps(refs))
PY
export RSY_RUN=0 RSY_MOBS=0 RSY_ENCOUNTER=spray RSY_PERSIST=0 RSY_RESULT_DIR="$work" RSY_PORT=$((40000 + RANDOM % 12000)) RSY_LATENCY="${RSY_LATENCY:-120}"
launch() {
  local label="$1" role="$2" source="$work/$1.png"
  local display_args=(--headless) screenshot=""
  if [[ "$label" == host && "${RSY_HEADED_HOST:-0}" == 1 ]]; then display_args=(); screenshot="${RSY_SCREENSHOT:-}"; fi
  RSY_ROLE="$role" RSY_NAME="$label" RSY_TOKEN="spray-$label" RSY_SPRAY="$source" RSY_SPRAY_STORE="$work/$label-saved.png" RSY_SCREENSHOT="$screenshot" \
    "$GODOT" "${display_args[@]}" --path "$PROJ" --script spray_test.gd >"$work/$label.log" 2>&1 & pids+=("$!")
}
launch host host
sleep 0.5
launch client client
for stage in before after; do
  receipt=initial-ready; if [[ "$stage" == after ]]; then receipt=updated-host; fi
  deadline=$((SECONDS+80))
  while [[ ! -f "$work/$receipt.json" ]]; do
    if ((SECONDS>=deadline)) || rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
    sleep 0.05
  done
  if [[ "$stage" == before ]]; then launch observer observer; else launch after observer; fi
done
deadline=$((SECONDS+100))
while ((SECONDS<deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live==0)); then break; fi
  if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/observer.log" "$work/after.log"
((SECONDS<deadline))
for pid in "${pids[@]}"; do wait "$pid"; done; pids=()
for label in host client observer after; do rg -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$label.log"; done
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
python3 - "$work" <<'PY'
from pathlib import Path
import sys,json,re
root=Path(sys.argv[1]);assert (root/'host-saved.png').read_bytes()==(root/'replacement.png').read_bytes()
assert any('pending=1' in (root/(p+'.log')).read_text() for p in ['host','client','observer','after'])
proposal=json.loads((root/'finish.json').read_text())
for role in ['host','client','observer','after']:
 stopped=json.loads((root/('stopped-'+role+'.json')).read_text()); assert proposal['tick']>=stopped['after']
print('RSY_SPRAY_FILES_AND_PENDING_OK')
PY
echo REPLAY_SCRAPYARD_SPRAY_OK
