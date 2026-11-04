#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
OUTPUT=${1:-$(mktemp -d)}
MODE=${2:-All}
ODIN_BIN=${ODIN:-odin}
case "$MODE" in All|Native) ;; *) printf 'mode must be All or Native\n' >&2; exit 2 ;; esac
mkdir -p "$OUTPUT/native" "$OUTPUT/wasm"
platform_flags=()
if [[ $(uname -s) == Darwin ]]; then platform_flags+=(-minimum-os-version:15.0); fi
"$ODIN_BIN" test "$REPO/tests/box3d_protocol" "-collection:godot=$REPO" \
  "-out:$OUTPUT/tests" -o:speed "${platform_flags[@]}" >"$OUTPUT/tests.log" 2>&1
"$ODIN_BIN" build "$REPO/tests/box3d_protocol/native" "-collection:godot=$REPO" \
  "-out:$OUTPUT/corpus" -o:speed "${platform_flags[@]}" >"$OUTPUT/build.log" 2>&1
"$OUTPUT/corpus" "$OUTPUT/native" >"$OUTPUT/corpus.log" 2>&1
if [[ "$MODE" == Native ]]; then
  python3 "$REPO/tests/box3d_protocol/golden.py" "$OUTPUT/native" >"$OUTPUT/golden.json"
  printf 'BOX3D_PROTOCOL_OK mode=Native evidence=%s\n' "$OUTPUT"
  exit 0
fi
"$ODIN_BIN" build "$REPO/tests/box3d_protocol/wasm" "-collection:godot=$REPO" \
  -target:freestanding_wasm32 -no-entry-point "-out:$OUTPUT/protocol.wasm" >"$OUTPUT/wasm-build.log" 2>&1
node --input-type=module - "$OUTPUT/protocol.wasm" "$OUTPUT/wasm" >"$OUTPUT/wasm.log" 2>&1 <<'JS'
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
const module = new WebAssembly.Module(readFileSync(process.argv[2]));
assert.deepEqual(WebAssembly.Module.imports(module), []);
const instance = new WebAssembly.Instance(module, {});
assert.equal(instance.exports.verify(), 0);
writeFileSync(process.argv[3]+'/signature.bin', Buffer.from(Array.from({length:480},(_,i)=>instance.exports.signature_byte(i))));
writeFileSync(process.argv[3]+'/trace.bin', Buffer.from(Array.from({length:instance.exports.trace_size()},(_,i)=>instance.exports.trace_byte(i))));
writeFileSync(process.argv[3]+'/descriptor.bin', Buffer.from(Array.from({length:32},(_,i)=>instance.exports.descriptor_byte(i))));
console.log('BOX3D_PROTOCOL_WASM_OK');
JS
python3 "$REPO/tests/box3d_protocol/golden.py" "$OUTPUT/native" "$OUTPUT/wasm" >"$OUTPUT/golden.json"
printf 'BOX3D_PROTOCOL_OK mode=All evidence=%s\n' "$OUTPUT"
