import fs from 'node:fs';import assert from 'node:assert/strict';
const [wasm,reference]=process.argv.slice(2),module=new WebAssembly.Module(fs.readFileSync(wasm));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const e=new WebAssembly.Instance(module,{}).exports;
for(const row of fs.readFileSync(reference,'utf8').trim().split('\n')){
 const [seed,depth,sum,...positions]=row.split(' ').map(Number);assert.equal(e.run(seed,depth)>>>0,sum);
 for(let i=0;i<20;i++)assert.equal(e.coordinate(i),positions[i]);
}
console.log('REPLAY_CAVE_SCATTER_WASM_EQUAL');
