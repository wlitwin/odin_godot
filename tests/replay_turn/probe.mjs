import fs from 'node:fs';
import assert from 'node:assert/strict';

export function relayConfig(){return process.env.REPLAY_ICE_CONFIG?JSON.parse(fs.readFileSync(process.env.REPLAY_ICE_CONFIG,'utf8')):null;}
export async function installRelayProbe(page,config){
 if(!config)return;
 await page.evaluateOnNewDocument(({config,provider})=>{
  if(!provider)globalThis.replayIceConfig=config;
  const Native=globalThis.RTCPeerConnection,peers=[];
  globalThis.replayTestPeers=peers;
  globalThis.replayTestIceErrors=[];
  globalThis.replayTestSignals=[];
  const Socket=globalThis.WebSocket;
  globalThis.WebSocket=class extends Socket {constructor(...args){super(...args);this.addEventListener('message',event=>{if(typeof event.data!=='string')return;try{const message=JSON.parse(event.data);if(['error','created','joined'].includes(message.type))globalThis.replayTestSignals.push({type:message.type,reason:message.type==='error'?message.reason:undefined,at:performance.now()});}catch{}});}};
  globalThis.RTCPeerConnection=class extends Native {constructor(...args){super(...args);const index=peers.length;peers.push(this);this.addEventListener('icecandidateerror',event=>globalThis.replayTestIceErrors.push({index,code:event.errorCode}));}};
 },{config,provider:process.env.REPLAY_TURN_PROVIDER==='1'});
}
export async function relayPairs(page){return page.evaluate(async()=>{
 const peers=globalThis.replayTestPeers||[],rows=[];
 for(let index=0;index<peers.length;index++){
  const peer=peers[index];if(peer.connectionState!=='connected')continue;
  const stats=await peer.getStats();let pairs=[];
  for(const value of stats.values())if(value.type==='transport'&&value.selectedCandidatePairId){const pair=stats.get(value.selectedCandidatePairId);if(pair)pairs.push(pair);}
  if(!pairs.length)for(const value of stats.values())if(value.type==='candidate-pair'&&value.nominated&&value.state==='succeeded')pairs.push(value);
  for(const pair of pairs){const local=stats.get(pair.localCandidateId),remote=stats.get(pair.remoteCandidateId),config=peer.getConfiguration();rows.push({index,policy:config.iceTransportPolicy,local:local?.candidateType,remote:remote?.candidateType,protocol:local?.protocol,relayProtocol:local?.relayProtocol,credentialExpires:Number(config.iceServers?.[0]?.username?.split(':')[0])||0,bytesSent:pair.bytesSent||0,bytesReceived:pair.bytesReceived||0});}
 }
 return rows;
});}
export async function requireRelay(page,observations,label){
 if(!process.env.REPLAY_ICE_CONFIG)return;
 const until=Date.now()+10000;let rows=[];
 while(Date.now()<until){rows=await relayPairs(page);if(rows.length&&rows.every(r=>r.bytesSent>0&&r.bytesReceived>0))break;await new Promise(r=>setTimeout(r,100));}
 assert.ok(rows.length,`${label}: no selected candidate pair`);
 for(const row of rows){assert.equal(row.policy,'relay');assert.equal(row.local,'relay');assert.equal(row.remote,'relay');assert.ok(row.bytesSent>0&&row.bytesReceived>0);if(process.env.REPLAY_TURN_PROTOCOL)assert.equal(row.relayProtocol,process.env.REPLAY_TURN_PROTOCOL);}
 observations.push({label,rows});
}
