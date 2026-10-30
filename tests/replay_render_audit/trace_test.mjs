import assert from 'node:assert/strict';import {installBufferTrace} from './trace.mjs';
const calls=[];globalThis.WebGLRenderingContext=class{bindBuffer(target,buffer){calls.push([this,target,buffer]);return 7;}getError(){throw new Error('must not consume errors');}};
globalThis.WebGL2RenderingContext=class extends WebGLRenderingContext{};
installBufferTrace();const gl=new WebGL2RenderingContext(),buffer={};
assert.equal(gl.bindBuffer(34963,buffer),7);gl.bindBuffer(34962,buffer);gl.bindBuffer(34962,buffer);
assert.equal(calls.length,3);assert.ok(calls.every(x=>x[0]===gl&&x[2]===buffer));assert.equal(bufferTrace.binds,3);assert.equal(bufferTrace.conflicts,2);assert.equal(bufferTrace.records.length,1);
for(let i=0;i<30;i++){const b={};gl.bindBuffer(34963,b);gl.bindBuffer(34962,b);}
assert.equal(bufferTrace.records.length,20);assert.equal(bufferTrace.conflicts,32);console.log('RENDER_TRACE_TEST_OK');
