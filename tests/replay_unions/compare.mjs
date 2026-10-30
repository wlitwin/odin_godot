import fs from 'node:fs';import assert from 'node:assert/strict';
const [file,reference]=process.argv.slice(2),lines=fs.readFileSync(reference,'utf8').trim().split('\n');
const [fingerprint,hash,count]=lines[0].split(' ');
const module=new WebAssembly.Module(fs.readFileSync(file));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const e=new WebAssembly.Instance(module,{}).exports;assert.equal(e.run(),1);
assert.equal(BigInt.asUintN(64,e.fingerprint()).toString(),fingerprint);assert.equal(BigInt.asUintN(64,e.hash()).toString(),hash);assert.equal(e.count(),Number(count));
let bytes='';for(let i=0;i<Number(count);i++)bytes+=e.byte_at(i).toString(16).padStart(2,'0');assert.equal(bytes,lines[1]);
console.log(`REPLAY_UNION_TARGETS_EQUAL fingerprint=${fingerprint} hash=${hash} bytes=${count}`);
