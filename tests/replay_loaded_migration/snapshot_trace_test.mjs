import assert from 'node:assert/strict';
import {installSnapshotTrace} from './snapshot_trace.mjs';
class Channel{constructor(){this.bufferedAmount=100;this.sent=[];this.listeners=[];}addEventListener(name,f){assert.equal(name,'message');this.listeners.push(f);}send(value){if(this.reject)throw Error('native rejection');this.sent.push(value);return 19;}receive(value){for(const f of this.listeners)f({data:value});}}
globalThis.RTCDataChannel=Channel;globalThis.RTCPeerConnection=class{createDataChannel(){return new Channel();}};
installSnapshotTrace();const peer=new RTCPeerConnection(),a=peer.createDataChannel(),b=peer.createDataChannel();
function packet(kind){const bytes=new Uint8Array(160),v=new DataView(bytes.buffer);bytes.set([82,80,67,1,1,0]);bytes.set([82,80,70,1],16);v.setUint16(34,1,true);bytes.set([82,80,76,89],36);v.setUint16(42,kind,true);v.setBigUint64(44,1n,true);v.setBigUint64(52,900n,true);return {bytes,v};}
const p=packet(17);p.v.setBigUint64(88,12345n,true);p.v.setBigUint64(96,7n,true);p.v.setBigUint64(104,70n,true);p.v.setUint32(120,5000,true);p.v.setUint16(124,2,true);p.v.setUint16(126,1024,true);
assert.equal(a.send(p.bytes),19);assert.equal(a.sent[0],p.bytes);b.receive(p.bytes);
assert.equal(replaySnapshotTrace.rows.length,2);assert.equal(replaySnapshotTrace.rows[0].id,'70');assert.equal(replaySnapshotTrace.rows[1].connection,replaySnapshotTrace.rows[0].connection);assert.equal(replaySnapshotTrace.rows[0].generation,'12345');assert.equal(replaySnapshotTrace.rows[0].serial,'7');assert.equal(replaySnapshotTrace.version,2);assert.equal(replaySnapshotTrace.rows[0].tick,900);assert.equal(replaySnapshotTrace.rows[0].index,2);
const d=packet(24);d.v.setBigUint64(120,71n,true);a.send(d.bytes);assert.equal(replaySnapshotTrace.rows[2].id,'71');
const ack=packet(11);ack.v.setBigUint64(104,70n,true);b.send(ack.bytes);assert.equal(replaySnapshotTrace.rows[3].id,'70');
a.send(p.bytes.subarray(0,100));a.send(packet(6).bytes);p.v.setUint16(34,2,true);a.send(p.bytes);assert.equal(replaySnapshotTrace.rows.length,4);p.v.setUint16(34,1,true);
a.reject=true;assert.throws(()=>a.send(p.bytes),/native rejection/);assert.equal(replaySnapshotTrace.rows.length,4);a.reject=false;
for(let i=0;i<32768;i++)a.send(p.bytes);assert.equal(replaySnapshotTrace.rows.length,32768);assert.equal(replaySnapshotTrace.overflow,4);
console.log('REPLAY_SNAPSHOT_TRACE_OK');
