import {WebSocket} from 'ws';
import {createHmac} from 'node:crypto';
import assert from 'node:assert/strict';
const wait=ms=>new Promise(r=>setTimeout(r,ms));
export async function raw(url){
 const ws=new WebSocket(url),queue=[];ws.on('message',bytes=>queue.push(JSON.parse(bytes.toString())));
 await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
 return {ws,queue,next:async(type)=>{const end=Date.now()+7000;while(Date.now()<end){const i=queue.findIndex(x=>!type||x.type===type);if(i>=0)return queue.splice(i,1)[0];await wait(20);}throw new Error(`signaling timeout ${type}`);}};
}
export function proof(room,challenge,member=1,create=true,keyDelta=0){
 const out=Buffer.alloc(116);out[0]=2;out[1]=create?1:2;
 [123n,1n,BigInt(member),BigInt(member+100)].forEach((n,i)=>out.writeBigUInt64LE(n,4+i*8));
 Buffer.from(room,'hex').copy(out,36);Buffer.from(challenge,'hex').copy(out,68);
 const key=Buffer.alloc(32);key[0]=member+20+keyDelta;
 createHmac('sha256',key).update('replay-p2p-admission-v1').update(out.subarray(0,84)).digest().copy(out,84);return out.toString('hex');
}
export async function attacks(url,room){
 const sockets=[];let saved,nonce;
 try{
  for(const kind of ['duplicate','wrong-key','wrong-role','unknown-member','replay']){
   const p=await raw(url);sockets.push(p.ws);p.ws.send(JSON.stringify({type:'create',room}));const c=await p.next('auth_challenge');
   let token=proof(room,c.challenge,kind==='wrong-role'?2:kind==='unknown-member'?8:1,true,kind==='wrong-key'?1:0);
   if(kind==='duplicate'){saved=token;nonce=c.challenge;}
   if(kind==='replay'){assert.notEqual(c.challenge,nonce);token=saved;}
   p.ws.send(JSON.stringify({type:'create',room,auth:token}));const error=await p.next('error');
   assert.equal(error.reason,kind==='duplicate'?'duplicate':'auth',kind);p.ws.close();
   console.log(`P2P_ADMISSION_REJECTED ${kind}`);
  }
 }finally{for(const ws of sockets)ws.close();}
}
