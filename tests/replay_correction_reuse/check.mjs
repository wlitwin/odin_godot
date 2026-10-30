import fs from 'node:fs';import assert from 'node:assert/strict';
const [wasm,log]=process.argv.slice(2), expected=fs.readFileSync(log,'utf8').match(/hash=(\d+)/)[1];
const {instance}=await WebAssembly.instantiate(fs.readFileSync(wasm),{env:{}});
assert.equal(BigInt.asUintN(64,instance.exports.verify()).toString(),expected);console.log('CORRECTION_REUSE_WASM_OK hash='+expected);
