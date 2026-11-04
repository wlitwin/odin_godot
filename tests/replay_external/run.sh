#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
WORK=${1:-"${TMPDIR:-/tmp}/replay-external-tests"}
mkdir -p "$WORK"
cd "$REPO"
odin test tests/replay_external -collection:godot=. "-out:$WORK/native"
odin build tests/replay_external/wasm -collection:godot=. -target:freestanding_wasm32 \
  -no-entry-point "-out:$WORK/managed.wasm"
node --input-type=module - "$WORK/managed.wasm" <<'JS'
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const module = new WebAssembly.Module(readFileSync(process.argv[2]));
assert.deepEqual(WebAssembly.Module.imports(module), []);
const instance = new WebAssembly.Instance(module, {});
for (let i = 0; i < 3; i++) assert.equal(instance.exports.verify(), 0);
console.log('REPLAY_EXTERNAL_NATIVE_WASM_OK');
JS
