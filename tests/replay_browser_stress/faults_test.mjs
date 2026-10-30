import assert from 'node:assert/strict';import {installFaults} from './faults.mjs';
let now=0,timers=[];globalThis.performance={now:()=>now};globalThis.setTimeout=(fn,delay)=>timers.push({fn,at:now+delay});
class Channel{readyState='open';sent=[];send(data){this.sent.push(Uint8Array.from(data));}}
globalThis.RTCDataChannel=Channel;
installFaults({seed:7,delay:40,jitter:10,loss:10000,duplicate:0,queueBytes:1024,queuePackets:32});
const packet=(channel,kind,sequence)=>{const b=new Uint8Array(20);b.set([82,80,67,1,channel,kind,0,0,sequence]);return b;};
const r=new Channel(),u=new Channel();stressFault.enabled=true;
u.send(packet(1,0,1));assert.equal(stressFault.loss,1);assert.equal(timers.length,0);
r.send(packet(0,0,1));r.send(packet(1,2,2));r.send(packet(1,1,3));assert.equal(timers.length,1);
assert.equal(stressFault.fences,1);
now=.7;const b=packet(0,0,4);r.send(b);b[8]=99;
while(timers.length){timers.sort((a,b)=>a.at-b.at);const t=timers.shift();now=t.at;t.fn();}assert.deepEqual(r.sent.map(x=>x[8]),[1,2,3,4]);
assert.equal(stressFault.queuedBytes,0);assert.equal(stressFault.queuedPackets,0);assert.equal(stressFault.errors.length,0);
stressFault.enabled=false;stressFault.blockUntil=400;u.send(packet(1,0,5));assert.equal(stressFault.blackout,1);
console.log('BROWSER_MESSAGE_FAULTS_OK');
