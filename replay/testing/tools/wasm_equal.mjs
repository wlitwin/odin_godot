// Usage: node wasm_equal.mjs module.wasm native.log [export=verify] [label]
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [wasm, log, entry = 'verify', label = 'REPLAY_SCENARIO_WASM_EQUAL'] = process.argv.slice(2);
const module = new WebAssembly.Module(fs.readFileSync(wasm));
assert.deepEqual(WebAssembly.Module.imports(module), [], 'corpus must be self-contained');
const exports = new WebAssembly.Instance(module, {}).exports;
const matches = [...fs.readFileSync(log, 'utf8').matchAll(/hash=(\d+)/g)];
assert.equal(matches.length, 1, 'expected one native result');
const wanted = BigInt(matches[0][1]);
assert.notEqual(wanted, 0n);
assert.equal(typeof exports[entry], 'function');
assert.equal(BigInt.asUintN(64, exports[entry]()), wanted);
console.log(label + ' ' + JSON.stringify({pass:true,hash:wanted.toString(),export:entry}));
