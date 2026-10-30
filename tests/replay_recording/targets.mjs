import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
import os from 'node:os';
import path from 'node:path';

const [wasm,verifier,...files]=process.argv.slice(2);
const module=new WebAssembly.Module(fs.readFileSync(wasm));
assert.deepEqual(WebAssembly.Module.imports(module),[]);
const {exports:e}=new WebAssembly.Instance(module,{});
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'replay-recording-corruption-'));
try {for(const file of files){
 const bytes=fs.readFileSync(file),native=spawnSync(verifier,[file],{encoding:'utf8',timeout:10000});
 assert.equal(native.status,0,native.stderr);
 const fields=Object.fromEntries([...native.stdout.matchAll(/(first|head|steps|events|epoch|shots|x)=([0-9.]+)/g)].map(m=>[m[1],m[2]]));
 new Uint8Array(e.memory.buffer,e.input_address(),bytes.length).set(bytes);
 assert.equal(e.verify(bytes.length),0,file);
 ['first','head','steps','events','epoch','shots'].forEach((name,i)=>assert.equal(BigInt.asUintN(64,e.field(i)),BigInt(fields[name]),file+' '+name));
 assert.ok(Math.abs(e.position()-Number(fields.x))<.001);
 const view=new Uint8Array(e.memory.buffer,e.input_address(),bytes.length);view[bytes.length-1]^=1;
 assert.notEqual(e.verify(bytes.length),0,'corrupted file accepted in WASM');
 const corrupted=Buffer.from(bytes);corrupted[corrupted.length-1]^=1;
 const invalid=path.join(scratch,'corrupt.rplrec');fs.writeFileSync(invalid,corrupted);
 const rejected=spawnSync(verifier,[invalid],{encoding:'utf8',timeout:10000});
 assert.equal(rejected.status,2,'corrupted file accepted by native verifier');
 assert.match(rejected.stderr,/Recording rejected:/);
 console.log(JSON.stringify({file,bytes:bytes.length,...fields,targets:'native+wasm',corruption_rejected:true}));
}} finally {fs.rmSync(scratch,{recursive:true,force:true});}
console.log('REPLAY_RECORDING_TARGETS_OK');
