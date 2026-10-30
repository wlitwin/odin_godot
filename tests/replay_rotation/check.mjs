import fs from 'node:fs';import assert from 'node:assert/strict';
const module=new WebAssembly.Module(fs.readFileSync(process.argv[2]));
// This freestanding corpus needs the standard math imports emitted by Odin.
// The actual Godot adapter is separately checked in its engine/runtime gates.
const functions={sin:Math.sin,sinf:Math.sin,cos:Math.cos,cosf:Math.cos,pow:Math.pow,powf:Math.pow,exp2:x=>2**x,exp2f:x=>2**x};
for (const item of WebAssembly.Module.imports(module)) assert.ok(item.module==='env' && item.kind==='function' && Object.hasOwn(functions,item.name),JSON.stringify(item));
const exports=new WebAssembly.Instance(module,{env:functions}).exports;assert.equal(exports.run(),0);console.log('ROTATION_WASM_OK math=JavaScript');
