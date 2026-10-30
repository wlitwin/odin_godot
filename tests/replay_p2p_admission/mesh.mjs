import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {raw,proof,attacks} from './attacks.mjs';
const [url,log,output]=process.argv.slice(2),text=readFileSync(log,'utf8');
const content=BigInt(text.match(/content=(\d+)/)[1]),room=text.match(/code=([0-9a-f]{64})/)[1];
const scope=Buffer.alloc(89);scope.writeBigUInt64LE(123n,0);scope.writeBigUInt64LE(content,8);scope.writeBigUInt64LE(1n,16);scope[24]=3;
for(let i=0;i<3;i++)scope.writeBigUInt64LE(BigInt(i+1),25+8*i);
assert.equal(createHash('sha256').update(scope).digest('hex'),room);
const peers=[];
async function admit(member){const p=await raw(url);peers.push(p);const type=member===1?'create':'join';p.ws.send(JSON.stringify({type,room}));const nonce=await p.next('auth_challenge');p.ws.send(JSON.stringify({type,room,auth:proof(room,nonce.challenge,member,member===1)}));const accepted=await p.next(member===1?'created':'joined');assert.equal(accepted.id,member);return p;}
function identity(notice,member){assert.equal(notice.id,member);assert.equal(Buffer.from(notice.member,'hex').readBigUInt64LE(),BigInt(member));assert.equal(Buffer.from(notice.incarnation,'hex').readBigUInt64LE(),BigInt(member+100));}
try{
 const a=await admit(1);await attacks(url,room);const b=await admit(2);
 identity(await a.next('peer'),2);identity(await b.next('peer'),1);
 const c=await admit(3);identity(await a.next('peer'),3);identity(await b.next('peer'),3);
 const introductions=[await c.next('peer'),await c.next('peer')].sort((a,b)=>a.id-b.id);identity(introductions[0],1);identity(introductions[1],2);
 b.ws.send(JSON.stringify({type:'signal',to:3,from:1,data:{probe:'client-to-client'}}));const forwarded=await c.next('signal');assert.equal(forwarded.from,2);assert.equal(forwarded.data.probe,'client-to-client');
 c.ws.send(JSON.stringify({type:'signal',to:2,data:{probe:'mesh-reply'}}));assert.equal((await b.next('signal')).from,3);
 writeFileSync(output,JSON.stringify({players:3,code:room,introductions,forwarded,checks:['scope digest oracle','challenged credentials','five rejection cases','member/incarnation introductions','client-to-client relay','sender spoof overwritten']},null,2));
 console.log('REPLAY_P2P_ADMISSION_MESH_OK');
}finally{for(const p of peers){p.ws.send(JSON.stringify({type:'leave'}));p.ws.close();}}
