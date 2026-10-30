import assert from 'node:assert/strict';
import {installCreditTrace} from './credit_trace.mjs';
class Channel{
 constructor(){this.bufferedAmount=0;this.messages=[];this.listeners=[];}
 addEventListener(name,callback){assert.equal(name,'message');this.listeners.push(callback);}
 send(value){if(this.reject)throw Error('native rejection');this.messages.push(value);return 77;}
 receive(value){for(const f of this.listeners)f({data:value});}
}
globalThis.RTCDataChannel=Channel;globalThis.RTCPeerConnection=class{createDataChannel(){return new Channel();}};
installCreditTrace();const peer=new RTCPeerConnection(),a=peer.createDataChannel('a'),b=peer.createDataChannel('b');
const bytes=new Uint8Array(16);bytes.set([82,80,67,1,1,1]);new DataView(bytes.buffer).setBigUint64(8,123n,true);
assert.equal(a.send(bytes),77);assert.equal(a.messages[0],bytes);b.receive(bytes);
assert.equal(replayCreditTrace.rows.length,2);assert.equal(replayCreditTrace.rows[0].connection,replayCreditTrace.rows[1].connection);
assert.equal(replayCreditTrace.rows[0].sequence,'123');assert.equal(replayCreditTrace.rows[1].event,'receive');
a.send(new Uint8Array(100));assert.equal(replayCreditTrace.rows.length,2);
a.reject=true;assert.throws(()=>a.send(bytes),/native rejection/);assert.equal(replayCreditTrace.rows.length,2);a.reject=false;
for(let i=0;i<32768;i++)a.send(bytes);assert.equal(replayCreditTrace.rows.length,32768);assert.equal(replayCreditTrace.overflow,2);
console.log('REPLAY_CREDIT_TRACE_OK');
