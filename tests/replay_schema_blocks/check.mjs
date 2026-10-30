import fs from 'node:fs';import assert from 'node:assert/strict';
const module=new WebAssembly.Module(fs.readFileSync(process.argv[2]));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const exports=new WebAssembly.Instance(module,{}).exports;assert.equal(exports.run(),0);console.log('SCHEMA_BLOCK_WASM_OK');
