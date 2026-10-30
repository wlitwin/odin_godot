import fs from 'node:fs';
import assert from 'node:assert/strict';
const m=new WebAssembly.Module(fs.readFileSync(process.argv[2]));
assert.deepEqual(WebAssembly.Module.imports(m),[]);
const {exports:e}=new WebAssembly.Instance(m,{});
assert.equal(e.run(),1);
console.log('REPLAY_CAVE_IMPACT_WASM_EXECUTION_OK');
