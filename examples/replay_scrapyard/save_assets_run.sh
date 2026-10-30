#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard asset save logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 - "$work" <<'PY'
from pathlib import Path
import struct,zlib,random,hashlib,json,sys
root=Path(sys.argv[1]);rng=random.Random(412)
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
pixels=bytearray()
for y in range(128):
 pixels.append(0)
 for x in range(128):pixels.extend((255,rng.randrange(256),rng.randrange(256),255))
data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
(root/'client.png').write_bytes(data);(root/'expected.json').write_text(json.dumps({'hash':hashlib.sha256(data).hexdigest(),'bytes':len(data)}))
PY
export RSY_SAVE="$work/run.replay" RSY_RESULT_DIR="$work" RSY_RUN=0 RSY_ENCOUNTER=migration RSY_LATENCY=120 RSY_PERSIST=0 RSY_PORT=$((40000 + RANDOM % 10000))
launch() {
  local role="$1" phase="$2" restore=0
  if [[ "$role" == host && "$phase" == resume ]]; then restore=1; fi
  RSY_ROLE="$role" RSY_TOKEN="asset-save-$role" RSY_SPRAY="$work/$role.png" RSY_SAVE_PHASE="$phase" RSY_RESUME="$restore" \
    "$GODOT" --headless --path "$PROJ" --script save_assets_test.gd >"$work/$phase-$role.log" 2>&1 & pids+=("$!")
}
wait_receipt() {
  local receipt="$1"; local deadline=$((SECONDS+70))
  while [[ ! -f "$work/$receipt.json" ]]; do
    if ((SECONDS>=deadline)) || rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
    sleep 0.05
  done
}
export RSY_EPOCH=1
for role in host client observer; do launch "$role" save; sleep 0.5; done
wait_receipt saved
for pid in "${pids[@]}"; do kill -KILL "$pid"; wait "$pid" 2>/dev/null || true; done; pids=()
rm "$work/client.png"
echo RSY_ASSET_SOURCE_REMOVED
export RSY_EPOCH=2
launch host resume
wait_receipt restored-offline
launch observer resume
wait_receipt finish
for pid in "${pids[@]}"; do wait "$pid"; done; pids=()
cat "$work/save-host.log" "$work/resume-host.log" "$work/resume-observer.log"
rg -q RSY_ASSET_OFFLINE_RESTORED "$work/resume-host.log"
for role in host observer; do rg -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/resume-$role.log"; done
if rg -q 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
# Reframe the same valid checkpoint without its asset dependency. The generic
# container is valid; the game must still reject an incomplete save.
python3 - "$work" <<'PYMISSING'
from pathlib import Path
import sys,struct,hashlib
root=Path(sys.argv[1]);original=(root/'run.replay').read_bytes()
size=struct.unpack_from('<I',original,56)[0];body=original[96:96+size]
header=bytearray(original[:96]);struct.pack_into('<H',header,54,0);struct.pack_into('<I',header,60,len(body));header[64:96]=hashlib.sha256(body).digest()
def digest(data,value=0xcbf29ce484222325):
 for byte in data:value=((value^byte)*0x100000001b3)&0xffffffffffffffff
 return value
struct.pack_into('<Q',header,44,digest(header[52:],digest(header[:44])))
(root/'missing.replay').write_bytes(header+body)
(root/'good.sha256').write_text(hashlib.sha256(original).hexdigest())
print('RSY_ASSET_BUNDLE_BYTES',len(original))
PYMISSING
set +e
RSY_ROLE=host RSY_TOKEN=asset-save-host RSY_SPRAY="$work/no-image.png" RSY_RESUME=1 RSY_SAVE_PHASE=resume RSY_SAVE="$work/missing.replay" \
  "$GODOT" --headless --path "$PROJ" --script save_assets_test.gd >"$work/missing.log" 2>&1
result=$?
set -e
cat "$work/missing.log"; ((result!=0)); rg -q 'RSY_SAVE_ERROR load=Codec missing asset' "$work/missing.log"
python3 - "$work" <<'PYMISSING'
from pathlib import Path
import sys,hashlib
root=Path(sys.argv[1]);assert hashlib.sha256((root/'run.replay').read_bytes()).hexdigest()==(root/'good.sha256').read_text()
print('RSY_ASSET_BUNDLE_MISSING_REJECTED')
PYMISSING
echo REPLAY_SCRAPYARD_ASSET_SAVE_OK
