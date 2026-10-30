import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
const [wasm,verifier,...files]=process.argv.slice(2);
const legacyFlags=process.env.REPLAY_RECORDING_CONTENT48==='1'?['--content48']:[];
const module=new WebAssembly.Module(fs.readFileSync(wasm));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const {exports:e}=new WebAssembly.Instance(module,{});
for(const [fileIndex,file] of files.entries()){
 const bytes=fs.readFileSync(file),native=spawnSync(verifier,[file,...legacyFlags],{encoding:'utf8',timeout:30000});assert.equal(native.status,0,native.stderr);
 const values=Object.fromEntries([...native.stdout.matchAll(/(\w+)=(\d+)/g)].map(m=>[m[1],m[2]]));
 new Uint8Array(e.memory.buffer,e.input_address(),bytes.length).set(bytes);
 const started=performance.now(),status=e.verify(bytes.length),elapsed=performance.now()-started;
 const detail=new TextDecoder().decode(new Uint8Array(e.memory.buffer,e.failure_address(),e.failure_size()));
 assert.equal(status,0,file+' '+detail);
 ['head','first','epoch','steps','gameplay','verdicts','applied','rejected','historical','shots','casts','mobs'].forEach((key,index)=>assert.equal(BigInt.asUintN(64,e.field(index)),BigInt(values[key]),file+' '+key));
 new Uint8Array(e.memory.buffer,e.input_address(),bytes.length)[bytes.length-1]^=1;assert.notEqual(e.verify(bytes.length),0,'corruption accepted');
 const corrupt=path.join(path.dirname(wasm),'corrupt.rplrec'),mutated=Buffer.from(bytes);mutated[mutated.length-1]^=1;fs.writeFileSync(corrupt,mutated);
 try {assert.equal(spawnSync(verifier,[corrupt,...legacyFlags],{encoding:'utf8',timeout:30000}).status,2,'native corruption rejection');} finally {fs.unlinkSync(corrupt);}
 const prefix=path.join(path.dirname(wasm),'case-'+fileIndex);
 const changed=spawnSync(path.join(path.dirname(wasm),'mutate'),[file,prefix],{encoding:'utf8',timeout:30000});assert.equal(changed.status,0,changed.stderr);
 for(const kind of ['state','input']){
  const altered=prefix+'.'+kind+'.rplrec',payload=fs.readFileSync(altered),nativeBad=spawnSync(verifier,[altered,...legacyFlags],{encoding:'utf8',timeout:30000});
  assert.equal(nativeBad.status,1,nativeBad.stderr);
  new Uint8Array(e.memory.buffer,e.input_address(),payload.length).set(payload);assert.notEqual(e.verify(payload.length),0,'WASM forged '+kind+' accepted');
  const text=new TextDecoder().decode(new Uint8Array(e.memory.buffer,e.failure_address(),e.failure_size()));
  assert.equal(BigInt.asUintN(64,e.field(12)),BigInt(values.head),'failure tick');
  if(kind==='state'){assert.match(nativeBad.stderr,/Diverged_State/);assert.match(text,/\$\.players\[0\]\.shots/);}
  else {assert.match(nativeBad.stderr,/failed: Model/);assert.equal(e.field(3),0n,'preflight must execute no steps');}
  fs.writeFileSync(prefix+'.'+kind+'.log',nativeBad.stderr+'\nWASM: '+text);
 }
 console.log(JSON.stringify({file,bytes:bytes.length,wasm_ms:elapsed,...values,targets:'native+wasm',corruption_rejected:true,state_mismatch_reported:true,invalid_input_preflight:true}));
}
console.log('REPLAY_NETWORK_RECORDING_TARGETS_OK');
