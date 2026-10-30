import assert from 'node:assert/strict';import vm from 'node:vm';import {installReliableHold} from './reliable_hold.mjs';
function packet(id,reliable=true){const b=new Uint8Array(212);b.set([82,80,67,1,reliable?0:1,0]);b.set([82,80,70,1],16);b.set([82,80,76,89],36);const v=new DataView(b.buffer);v.setUint16(42,0x5102,true);v.setBigUint64(52,1000n,true);b[100]=id;return b;}
for(const milliseconds of [200,300,400]){
 const sent=[],timers=[];let now=100;const Channel=class{send(bytes){sent.push(Array.from(bytes));}};
 const context=vm.createContext({RTCDataChannel:Channel,performance:{now:()=>now},setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length;},config:{milliseconds},ArrayBuffer,Uint8Array,DataView});
 vm.runInContext('('+installReliableHold.toString()+')(config)',context);const channel=new Channel();
 const first=packet(1);channel.send(first);channel.send(packet(2));first[100]=99;channel.send(packet(3,false));assert.equal(sent.length,1);assert.equal(sent[0][100],3);assert.equal(context.reliableHold.held,2);assert.equal(timers.length,1);assert.equal(timers[0].ms,milliseconds);
 now+=milliseconds;timers[0].fn();assert.deepEqual(sent.map(p=>p[100]),[3,1,2]);assert.equal(context.reliableHold.queuedBytes,0);assert.equal(context.reliableHold.active,false);assert.equal(context.reliableHold.elapsedMs,milliseconds);channel.send(packet(4));assert.equal(timers.length,1);assert.equal(sent[3][100],4);assert.equal(context.reliableHold.errors.length,0);
}
for(const milliseconds of [0,-1,2001,NaN,Infinity,1.5]){
 const Channel=class{send(){}};const original=Channel.prototype.send;const context=vm.createContext({RTCDataChannel:Channel,config:{milliseconds}});
 assert.throws(()=>vm.runInContext('('+installReliableHold.toString()+')(config)',context),/Invalid reliable hold configuration/);assert.equal(Channel.prototype.send,original);
}
{
 const sent=[],timers=[];let now=10;const Channel=class{send(bytes){sent.push(Array.from(bytes));}};
 const context=vm.createContext({RTCDataChannel:Channel,performance:{now:()=>now},setTimeout:(fn,ms)=>{timers.push({fn,ms});},config:{milliseconds:2000,armed:false},ArrayBuffer,Uint8Array,DataView});
 vm.runInContext('('+installReliableHold.toString()+')(config)',context);const channel=new Channel();channel.send(packet(1));assert.equal(context.reliableHold.triggered,false);assert.equal(sent.length,1);
 assert.equal(context.reliableHoldArm(-1),false);assert.equal(context.reliableHoldArm(1001),true);channel.send(packet(2));assert.equal(sent.length,2);
 const late=packet(3);new DataView(late.buffer).setBigUint64(52,1002n,true);channel.send(late);assert.equal(context.reliableHold.active,true);assert.equal(context.reliableHold.held,1);assert.equal(context.reliableHoldArm(1003),false);
 now+=300;assert.equal(context.reliableHold.active,true);assert.ok(context.reliableHold.queuedBytes>0);assert.equal(timers[0].ms,2000);
}
console.log('RELIABLE_HOLD_TEST_OK');
