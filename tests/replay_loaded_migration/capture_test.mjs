import assert from 'node:assert/strict';import {installArchiveCapture} from './capture.mjs';
const sent=[];globalThis.RTCDataChannel=class{send(x){sent.push(x);}};installArchiveCapture();const channel=new RTCDataChannel();
function packet(kind,size){const b=new Uint8Array(size),v=new DataView(b.buffer);b.set([82,80,67,1,1,0]);b.set([82,80,70,1],16);b[34]=1;b.set([82,80,76,89],36);v.setUint16(42,kind,true);v.setBigUint64(44,1n,true);v.setBigUint64(96,3n,true);return b;}
function offer(sequence,raw=4096,layout=0n){const b=packet(layout?0x5107:0x5106,layout?212:204),v=new DataView(b.buffer);v.setBigUint64(108,BigInt(sequence),true);v.setBigUint64(116,60n,true);v.setUint32(124,raw,true);v.setUint32(200,1024,true);if(layout)v.setBigUint64(204,layout,true);return b;}
function chunk(sequence,index=0){const b=packet(0x5102,1138),v=new DataView(b.buffer);v.setBigUint64(104,BigInt(sequence),true);v.setUint16(112,index,true);b.fill(7,114);return b;}
const o=offer(1);channel.send(o);assert.equal(sent[0],o);assert.equal(stressArchives.length,1);
channel.send(chunk(1,1));assert.equal(stressArchives[0].received,0);
const c=chunk(1);channel.send(c);channel.send(c);c.fill(99,114);assert.equal(stressArchives[0].received,1024);assert.deepEqual(stressArchives[0].wire,Array(1024).fill(7));
channel.send(offer(2,1048577));assert.equal(stressArchives.length,1);
channel.send(offer(2));channel.send(offer(3));assert.equal(stressArchives.length,3);assert.deepEqual(stressArchives.map(x=>x.sequence),['1','2','3']);
const reliable=offer(4,4096,0x11223344n);reliable[4]=0;channel.send(reliable);channel.send(chunk(4));assert.equal(stressArchives[2].channel,0);assert.equal(stressArchives[2].layout,String(0x11223344n));assert.equal(stressArchives[2].wire.length,1024);
console.log('CHECKPOINT_CAPTURE_TEST_OK');
