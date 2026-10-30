import fs from 'node:fs';
import assert from 'node:assert/strict';
const module=new WebAssembly.Module(fs.readFileSync(process.argv[2]));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const {exports:e}=new WebAssembly.Instance(module,{});
for(let index=0;index<262;index++)assert.equal(e.compare(index),0,'director scenario '+index);
console.log('REPLAY_CAVE_DIRECTOR_WASM_OK cases=262');
