// Read-only metadata observation of real RPC credit/fence send and delivery.
export function installCreditTrace(){
 const limit=32768,rows=[],stats=globalThis.replayCreditTrace={limit,rows,overflow:0,unreadable:0};
 const indexes=new WeakMap(),owners=new WeakMap(),channels=new WeakMap();let next=0;
 function note(dc,event,payload){
  const b=payload instanceof ArrayBuffer?new Uint8Array(payload):ArrayBuffer.isView(payload)?new Uint8Array(payload.buffer,payload.byteOffset,payload.byteLength):null;
  if(!b){stats.unreadable++;return;}
  if(b.length!==16||b[0]!==82||b[1]!==80||b[2]!==67||b[3]!==1||b[4]>1||b[5]<1||b[5]>2)return;
  if(rows.length===limit){stats.overflow++;return;}
  rows.push({event,connection:indexes.get(dc),channel:b[4],kind:b[5],sequence:new DataView(b.buffer,b.byteOffset,b.byteLength).getBigUint64(8,true).toString(),at_ms:performance.timeOrigin+performance.now(),buffered_bytes:dc.bufferedAmount,unreliable_buffered_bytes:(channels.get(owners.get(dc))||[]).find(c=>c.id===1)?.bufferedAmount??0});
 }
 const create=RTCPeerConnection.prototype.createDataChannel;
 RTCPeerConnection.prototype.createDataChannel=function(...args){
  const dc=create.apply(this,args);if(!indexes.has(this))indexes.set(this,next++);indexes.set(dc,indexes.get(this));owners.set(dc,this);if(!channels.has(this))channels.set(this,[]);channels.get(this).push(dc);
  dc.addEventListener('message',event=>note(dc,'receive',event.data));return dc;
 };
 const send=RTCDataChannel.prototype.send;
 RTCDataChannel.prototype.send=function(payload){const result=send.call(this,payload);note(this,'send',payload);return result;};
}
