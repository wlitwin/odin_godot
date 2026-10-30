import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
const [wasm,native,...files]=process.argv.slice(2);
const module=new WebAssembly.Module(fs.readFileSync(wasm));assert.deepEqual(WebAssembly.Module.imports(module),[]);
const {exports:e}=new WebAssembly.Instance(module,{});
for(const file of files){
 const data=fs.readFileSync(file);assert.ok(data.length<=16*1024*1024);
 const run=spawnSync(native,[file],{encoding:'utf8',timeout:60000});assert.equal(run.status,0,run.stdout+run.stderr);
 const values=Object.fromEntries([...run.stdout.matchAll(/(\w+)=(\d+)/g)].map(m=>[m[1],m[2]]));
 new Uint8Array(e.memory.buffer,e.input_address(),data.length).set(data);
 const status=e.verify(data.length);assert.equal(status,0,`${file}: status=${status} frame=${e.field(0)} expected_changes=${e.field(6)} actual_changes=${e.field(7)}`);
 for(const [i,key] of ['frames','operations','world_tick','kicks','resyncs'].entries())assert.equal(e.field(i),BigInt(values[key]),key);
 const refreshes=e.field(5).toString();
 new Uint8Array(e.memory.buffer,e.input_address(),data.length)[data.length-1]^=1;
 assert.notEqual(e.verify(data.length),0,'corruption accepted');
 console.log(JSON.stringify({file,...values,refreshes,targets:'native+wasm',corruption_rejected:true}));
}
console.log('REPLAY_CLAIMBALL_TRACE_TARGETS_OK');
