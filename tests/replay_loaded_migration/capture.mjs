// Optional read-only diagnostic at RTC send admission, before fault injection.
// Captures at most three bounded outgoing checkpoint streams. Native analysis must
// still verify their raw SHA-256 and canonical checkpoint before using the data.
export function installArchiveCapture(){
 const original=RTCDataChannel.prototype.send;
 const records=globalThis.stressArchives=[];
 RTCDataChannel.prototype.send=function(payload){
  const b=payload instanceof ArrayBuffer?new Uint8Array(payload):ArrayBuffer.isView(payload)?new Uint8Array(payload.buffer,payload.byteOffset,payload.byteLength):null;
  if(b&&b.length>=88&&b[0]===82&&b[1]===80&&b[2]===67&&b[3]===1&&b[4]<=1&&b[5]===0&&b[16]===82&&b[17]===80&&b[18]===70&&b[19]===1&&b[32]===0&&b[33]===0&&b[34]===1&&b[35]===0&&b[36]===82&&b[37]===80&&b[38]===76&&b[39]===89){
   const v=new DataView(b.buffer,b.byteOffset,b.byteLength),kind=v.getUint16(42,true),epoch=v.getBigUint64(44,true).toString(),body=88;
   if((kind===0x5106&&b.length===204)||(kind===0x5107&&b.length===212)){
    const binding=v.getBigUint64(body+8,true).toString(),sequence=v.getBigUint64(body+20,true).toString(),key=epoch+':'+binding+':'+sequence;
    const raw_bytes=v.getUint32(body+36,true),wire_bytes=v.getUint32(body+112,true);
    if(raw_bytes>=52&&raw_bytes<=1048576&&wire_bytes>=6&&wire_bytes<raw_bytes&&!records.some(r=>r.key===key)){
     records.push({channel:b[4],layout:kind===0x5107?v.getBigUint64(204,true).toString():"0",key,epoch,binding,sequence,tick:v.getBigUint64(body+28,true).toString(),raw_bytes,wire_bytes,hash:Array.from(b.subarray(body+40,body+72)),offer:Array.from(b.subarray(36)),chunks:{},received:0,first_offer_ms:performance.now(),chunk_packets:0});
     while(records.length>3)records.shift();
    }
   }else if(kind===0x5102&&b.length>=114){
    const key=epoch+':'+v.getBigUint64(body+8,true)+':'+v.getBigUint64(body+16,true),r=records.find(r=>r.key===key),index=v.getUint16(body+24,true);
    if(r){r.chunk_packets++;r.last_chunk_ms=performance.now();}
    if(r&&!r.wire&&index<Math.ceil(r.wire_bytes/1024)&&b.length-114===Math.min(1024,r.wire_bytes-index*1024)&&!Object.hasOwn(r.chunks,index)){
     r.chunks[index]=Array.from(b.subarray(114));r.received+=b.length-114;
     if(r.received===r.wire_bytes){r.wire=[];for(let i=0;i<Math.ceil(r.wire_bytes/1024);i++)r.wire.push(...r.chunks[i]);delete r.chunks;r.complete_ms=performance.now();}
    }
   }
  }
  return original.call(this,payload);
 };
}
