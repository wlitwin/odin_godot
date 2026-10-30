// Native channel negotiation and traffic evidence; does not modify messages.
export function installControlProbe(){
 const peers=[];globalThis.replayControlPeers=peers;
 const create=RTCPeerConnection.prototype.createDataChannel;
 RTCPeerConnection.prototype.createDataChannel=function(...args){
  const dc=create.apply(this,args);let row=peers.find(r=>r.peer===this);if(!row){row={peer:this,channels:[]};peers.push(row);}row.channels.push(dc);return dc;
 };
}
export async function controlEvidence(page){return page.evaluate(async()=>{
 const result=[];
 for(const r of globalThis.replayControlPeers||[]){
  if(r.peer.connectionState!=='connected')continue;
  const stats=await r.peer.getStats(),channels=[];
  for(const c of r.channels){let sent=0,received=0;for(const s of stats.values())if(s.type==='data-channel'&&s.dataChannelIdentifier===c.id){sent=s.messagesSent;received=s.messagesReceived;}
   channels.push({id:c.id,label:c.label,ordered:c.ordered,maxRetransmits:c.maxRetransmits,maxPacketLifeTime:c.maxPacketLifeTime,state:c.readyState,sent,received});}
  result.push({channels});
 }
 return result;
});}
