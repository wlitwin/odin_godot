import fs from 'node:fs';import assert from 'node:assert/strict';
const [wasm,reference]=process.argv.slice(2),module=new WebAssembly.Module(fs.readFileSync(wasm));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const e=new WebAssembly.Instance(module,{}).exports;assert.equal(e.run(),0);
const summary=JSON.parse(fs.readFileSync(reference,'utf8'));assert.equal(String(BigInt.asUintN(64,e.hash())),summary.canonical_hash);assert.equal(e.size(),Number(summary.shape[0]));
console.log('REPLAY_SCHEMA_LARGE_WASM_EQUAL hash='+summary.canonical_hash+' bytes='+e.size());
