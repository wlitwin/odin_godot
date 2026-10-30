import fs from 'node:fs';import assert from 'node:assert/strict';
const [wasm,log]=process.argv.slice(2),module=new WebAssembly.Module(fs.readFileSync(wasm));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const e=new WebAssembly.Instance(module,{}).exports;assert.equal(e.run(),0);
const expected=fs.readFileSync(log,'utf8').match(/SHUFFLE_CORPUS_OK cases=256 hash=(\d+)/)[1];assert.equal(String(BigInt.asUintN(64,e.hash())),expected);
console.log('SHUFFLE_WASM_EQUAL hash='+expected);
