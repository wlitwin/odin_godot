// Installed before Godot starts. This is message-level injection at send(), after
// Replay has accepted/charged the RPC packet. It is not raw IP/SCTP packet loss.
export function installFaults(config) {
 const original=RTCDataChannel.prototype.send,states=new WeakMap();let rng=config.seed>>>0;
 const random=()=>{rng^=rng<<13;rng^=rng>>>17;rng^=rng<<5;return (rng>>>0)/4294967296;};
 const stats=globalThis.stressFault={enabled:false,blockUntil:0,queuedBytes:0,queuedPackets:0,maxQueuedBytes:0,maxQueuedPackets:0,data:0,forwarded:0,loss:0,blackout:0,duplicate:0,capacity:0,fences:0,acks:0,closed:0,errors:[],byKind:{},config};
 RTCDataChannel.prototype.send=function(payload){
  const view=payload instanceof ArrayBuffer ? new Uint8Array(payload) : ArrayBuffer.isView(payload) ? new Uint8Array(payload.buffer,payload.byteOffset,payload.byteLength) : null;
  if(!view || view.length<16 || view[0]!==82 || view[1]!==80 || view[2]!==67 || view[3]!==1)return original.call(this,payload);
  const channel=view[4],kind=view[5],unreliable=channel===1&&kind===0;
  if(kind===0 && view.length>=88 && view[16]===82 && view[17]===80 && view[18]===70 && view[32]===0 && view[33]===0 && view[36]===82 && view[37]===80 && view[38]===76 && view[39]===89){
   const k=(channel===0?'r:':'u:')+(view[42]|view[43]<<8);stats.byKind[k]=(stats.byKind[k]||0)+1;
  }
  if(kind===0)stats.data++;if(kind===1)stats.acks++;if(kind===2)stats.fences++;
  const now=performance.now();
  if(unreliable && now<stats.blockUntil){stats.blackout++;return;}
  if(unreliable && stats.enabled && random()*10000<config.loss){stats.loss++;return;}
  const copies=unreliable&&stats.enabled&&random()*10000<config.duplicate?2:1;
  if(copies===2)stats.duplicate++;
  let state=states.get(this);if(!state){state={due:0,queue:[],timer:false};states.set(this,state);}
  for(let copy=0;copy<copies;copy++){
   if(stats.queuedPackets>=config.queuePackets || stats.queuedBytes+view.length>config.queueBytes){
    if(unreliable){stats.capacity++;continue;}
    stats.errors.push('reliable queue capacity exceeded');throw new Error('stress reliable queue capacity exceeded');
   }
   const bytes=Uint8Array.from(view);let due=now+config.delay+(random()*2-1)*config.jitter;
   if(!unreliable){due=Math.max(due,state.due+.01);state.due=due;}
   stats.queuedBytes+=bytes.length;stats.queuedPackets++;
   stats.maxQueuedBytes=Math.max(stats.maxQueuedBytes,stats.queuedBytes);stats.maxQueuedPackets=Math.max(stats.maxQueuedPackets,stats.queuedPackets);
   const dc=this;
   const deliver=()=>{
    stats.queuedBytes-=bytes.length;stats.queuedPackets--;
    if(dc.readyState!=='open'){stats.closed++;return;}
    try{original.call(dc,bytes);stats.forwarded++;}catch(error){stats.errors.push(String(error));}
   };
   if(unreliable){setTimeout(deliver,Math.max(0,due-performance.now()));}
   else {
    state.queue.push({due,deliver});
    const drain=()=>{
     state.timer=false;
     while(state.queue.length&&state.queue[0].due<=performance.now())state.queue.shift().deliver();
     if(state.queue.length){state.timer=true;setTimeout(drain,Math.max(1,Math.ceil(state.queue[0].due-performance.now())));}
    };
    if(!state.timer){state.timer=true;setTimeout(drain,Math.max(1,Math.ceil(state.queue[0].due-performance.now())));}
   }
  }
 };
}
