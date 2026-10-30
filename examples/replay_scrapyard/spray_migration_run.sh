#!/usr/bin/env bash
set -euo pipefail
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
python3 - "$work/tag.png" <<'PY'
import struct,zlib,random,sys,hashlib
from pathlib import Path
rng=random.Random(888)
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
pixels=bytearray()
for y in range(128):
 pixels.append(0)
 for x in range(128):pixels.extend((rng.randrange(256),rng.randrange(256),255,255))
data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
Path(sys.argv[1]).write_bytes(data);Path(sys.argv[1]+'.sha256').write_text(hashlib.sha256(data).hexdigest())
PY
export RSY_MIGRATION_SPRAYS=1 RSY_SPRAY_SOURCE="$work/tag.png" RSY_SPRAY_EXPECTED="$(cat "$work/tag.png.sha256")"
bash "$(dirname "${BASH_SOURCE[0]}")/migration_run.sh"
echo REPLAY_SCRAPYARD_SPRAY_MIGRATION_OK
