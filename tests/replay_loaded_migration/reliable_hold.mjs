// Diagnostic only: one bounded FIFO pause before the normal message-fault layer.
// Trigger at a checkpoint offer tick so startup is not part of this fault.
export function installReliableHold({milliseconds=200,firstTick=1000,phase="chunk",armed=true}={}){
 if(!Number.isInteger(milliseconds)||milliseconds<1||milliseconds>2000||!Number.isSafeInteger(firstTick)||firstTick<0||!["chunk","offer"].includes(phase)||typeof armed!=="boolean")throw new Error("Invalid reliable hold configuration");
 const original=RTCDataChannel.prototype.send;const queue=[];
 const state=globalThis.reliableHold={triggered:false,active:false,held:0,queuedBytes:0,peakBytes:0,errors:[],milliseconds,firstTick,phase,armed};
 globalThis.reliableHoldArm=tick=>{if(state.triggered||!Number.isSafeInteger(tick)||tick<0)return false;state.firstTick=tick;state.armed=true;return true;};
 const flush=()=>{
  state.releasedAt=performance.now();state.elapsedMs=state.releasedAt-state.startedAt;
  while(queue.length){const item=queue.shift();state.queuedBytes-=item.bytes.length;try{original.call(item.channel,item.bytes);}catch(error){state.errors.push(String(error));}}
  state.active=false;
 };
 RTCDataChannel.prototype.send=function(payload){
  const b=payload instanceof ArrayBuffer?new Uint8Array(payload):ArrayBuffer.isView(payload)?new Uint8Array(payload.buffer,payload.byteOffset,payload.byteLength):null;
  if(!b||b.length<16||b[0]!==82||b[1]!==80||b[2]!==67||b[3]!==1)return original.call(this,payload);
  const physicalReliable=b[4]===0||b[5]!==0;
  if(state.armed&&!state.triggered&&b[4]===0&&b[5]===0&&b.length>=88&&b[16]===82&&b[17]===80&&b[18]===70&&b[32]===0&&b[33]===0&&b[36]===82&&b[37]===80&&b[38]===76&&b[39]===89){
   const view=new DataView(b.buffer,b.byteOffset,b.byteLength),kind=view.getUint16(42,true),tick=view.getBigUint64(52,true);
   if((phase==="chunk"?kind===0x5102:[0x5101,0x5106,0x5107].includes(kind))&&tick>=BigInt(state.firstTick)){state.triggered=true;state.active=true;state.triggerTick=String(tick);state.startedAt=performance.now();setTimeout(flush,milliseconds);}
  }
  if(physicalReliable&&state.active){
   if(queue.length>=128||state.queuedBytes+b.length>65536){state.errors.push('reliable hold capacity exceeded');throw new Error(state.errors.at(-1));}
   const bytes=Uint8Array.from(b);queue.push({channel:this,bytes});state.held++;state.queuedBytes+=bytes.length;state.peakBytes=Math.max(state.peakBytes,state.queuedBytes);return;
  }
  return original.call(this,payload);
 };
}
