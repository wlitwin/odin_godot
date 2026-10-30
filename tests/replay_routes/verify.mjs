import fs from 'node:fs';import assert from 'node:assert/strict';
const module=new WebAssembly.Module(fs.readFileSync(process.argv[2]));
assert.deepEqual(WebAssembly.Module.imports(module),[]);
const instance=new WebAssembly.Instance(module,{});
assert.equal(instance.exports.verify(),0);
console.log('REPLAY_ROUTES_WASM_OK');
