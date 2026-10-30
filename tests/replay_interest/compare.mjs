import fs from 'node:fs';import assert from 'node:assert/strict';
const [path,reference]=process.argv.slice(2),module=new WebAssembly.Module(fs.readFileSync(path));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const e=new WebAssembly.Instance(module,{}).exports;assert.equal(e.run(),1);
const actual=`${BigInt.asUintN(64,e.fingerprint())} ${BigInt.asUintN(64,e.hash())} ${e.frames()}`;
assert.equal(actual,fs.readFileSync(reference,'utf8').trim());console.log('REPLAY_INTEREST_WASM_EQUAL '+actual);
