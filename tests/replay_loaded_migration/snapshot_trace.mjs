// Observe native snapshot/ACK delivery without changing payloads or scheduling.
export function installSnapshotTrace(){
 const rows=[],limit=32768,stats=globalThis.replaySnapshotTrace={version:2,rows,limit,overflow:0,unreadable:0,by_kind:{}};
 const indexes=new WeakMap();let next=0;
 function note(dc,event,payload){
  const b=payload instanceof ArrayBuffer?new Uint8Array(payload):ArrayBuffer.isView(payload)?new Uint8Array(payload.buffer,payload.byteOffset,payload.byteLength):null;
  if(!b){stats.unreadable++;return;}
  if(b.length<112||b[0]!==82||b[1]!==80||b[2]!==67||b[3]!==1||b[5]!==0||b[16]!==82||b[17]!==80||b[18]!==70||b[19]!==1)return;
  const v=new DataView(b.buffer,b.byteOffset,b.byteLength);
  if(v.getUint16(32,true)!==0||v.getUint16(34,true)!==1||b[36]!==82||b[37]!==80||b[38]!==76||b[39]!==89)return;
  const kind=v.getUint16(42,true),key=event+':'+b[4]+':'+kind;
  if(!(key in stats.by_kind)){if(Object.keys(stats.by_kind).length===64){stats.overflow++;return;}stats.by_kind[key]={packets:0,bytes:0,max_buffered:0};}
  const count=stats.by_kind[key];count.packets++;count.bytes+=b.length;count.max_buffered=Math.max(count.max_buffered,dc.bufferedAmount);
  if(![7,10,11,17,18,23,24,0x5102].includes(kind))return;
  const part=kind===17||kind===23,delta=[10,18,24].includes(kind);
  if((part&&b.length<128)||(delta&&b.length<136))return;
  if(rows.length===limit){stats.overflow++;return;}
  const id=v.getBigUint64(part||kind===11||kind===0x5102?104:delta?120:88,true).toString();
  rows.push({event,connection:indexes.get(dc),channel:b[4],kind,id,generation:kind===0x5102?'0':v.getBigUint64(kind===7?96:88,true).toString(),serial:kind===0x5102?'0':v.getBigUint64(kind===7?104:96,true).toString(),tick:Number(v.getBigUint64(52,true)),epoch:Number(v.getBigUint64(44,true)),index:part?v.getUint16(124,true):kind===0x5102?v.getUint16(112,true):0,total:part?v.getUint32(120,true):b.length-36,part_bytes:part?v.getUint16(126,true):0,bytes:b.length,at_ms:performance.timeOrigin+performance.now(),buffered_bytes:dc.bufferedAmount});
 }
 const create=RTCPeerConnection.prototype.createDataChannel;
 RTCPeerConnection.prototype.createDataChannel=function(...args){const dc=create.apply(this,args);if(!indexes.has(this))indexes.set(this,next++);indexes.set(dc,indexes.get(this));dc.addEventListener('message',event=>note(dc,'receive',event.data));return dc;};
 const send=RTCDataChannel.prototype.send;
 RTCDataChannel.prototype.send=function(payload){const result=send.call(this,payload);note(this,'send',payload);return result;};
}
