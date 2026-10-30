import puppeteer from 'puppeteer-core';
import {WebSocket} from 'ws';
import {createHmac} from 'node:crypto';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,signal]=process.argv.slice(2),logs=process.env.RWA_SIGNAL_LOGS;
fs.mkdirSync(logs,{recursive:true});const peers=[];
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function until(predicate,label,ms=60000){const end=Date.now()+ms;while(Date.now()<end){for(const p of peers)assert.equal(p.errors.length,0,p.errors.join('\n'));if(predicate())return;await wait(100);}throw new Error(`Timeout ${label}`);}
async function open(member){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
 const page=await browser.newPage(),peer={browser,page,member,lines:[],errors:[]};peers.push(peer);
 page.on('console',msg=>{const text=msg.text();peer.lines.push(text);fs.appendFileSync(`${logs}/member-${member}.log`,text+'\n');if(/^RZA_/.test(text))console.log(member,text);if(/RZA_FAIL|SCRIPT ERROR|ERROR:/.test(text))peer.errors.push(text);});
 page.on('pageerror',e=>peer.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({url:signal,mode:'signal',member:String(member)});await page.goto(url.href,{waitUntil:'domcontentloaded'});return peer;
}
async function raw(){
 const ws=new WebSocket(signal),queue=[];ws.on('message',bytes=>queue.push(JSON.parse(bytes.toString())));
 await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
 return {ws,queue,next:async()=>{const end=Date.now()+6000;while(Date.now()<end){if(queue.length)return queue.shift();await wait(20);}throw new Error('raw signaling timeout');}};
}
function proof(room,challenge,member=1,create=true){
 const out=Buffer.alloc(116);out[0]=1;out[1]=create?1:2;
 [44n,1n,BigInt(member),BigInt(member+100)].forEach((n,i)=>out.writeBigUInt64LE(n,4+i*8));
 Buffer.from(room,'hex').copy(out,36);Buffer.from(challenge,'hex').copy(out,68);
 const key=Buffer.alloc(32);key[0]=member+20;
 createHmac('sha256',key).update('replay-rendezvous-v1').update(out.subarray(0,84)).digest().copy(out,84);return out.toString('hex');
}
try{
 const host=await open(1);await until(()=>host.lines.some(l=>l.startsWith('RZA_ROOM ')),'approved room');
 const room=host.lines.find(l=>l.startsWith('RZA_ROOM ')).split(' ')[1];assert.equal(room.length,64);
 await open(2);await open(3);
 await until(()=>peers.every(p=>p.lines.some(l=>l.startsWith('RZA_DATA_OK'))),'authorized RTC data');
 assert.ok(peers[1].lines.includes('RZA_NONOWNER_REJECTED'));
 // The legitimate owner's proof cannot open a second live creator, and a proof
 // from that connection cannot authenticate against another connection's nonce.
 const a=await raw();a.ws.send(JSON.stringify({type:'create',room}));const c1=await a.next();assert.equal(c1.type,'auth_challenge');
 const saved=proof(room,c1.challenge);a.ws.send(JSON.stringify({type:'create',room,auth:saved}));assert.equal((await a.next()).reason,'duplicate');a.ws.close();
 const b=await raw();b.ws.send(JSON.stringify({type:'create',room}));const c2=await b.next();assert.notEqual(c1.challenge,c2.challenge);
 b.ws.send(JSON.stringify({type:'create',room,auth:saved}));assert.equal((await b.next()).reason,'auth');b.ws.close();
 console.log('RZA_REPLAY_AND_DUPLICATE_REJECTED');
 const reconnects=[];
 for(const peer of [host,peers[1]]){
  const before=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.rzaStats)));
  await peer.page.evaluate(()=>{globalThis.rzaCommand='drop_signal';});
  await peer.page.waitForFunction(previous=>globalThis.rzaStats?.resumes>previous,{timeout:15000},before[peer.member-1].resumes);
  await wait(500);
  const after=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.rzaStats)));
  for(let i=0;i<peers.length;i++){assert.equal(after[i].id,before[i].id);assert.deepEqual(after[i].connections,before[i].connections);assert.ok(after[i].packets>before[i].packets);}
  assert.ok(after[peer.member-1].during_loss>before[peer.member-1].during_loss);
  reconnects.push({member:peer.member,before,after});
  console.log(`RZA_SIGNAL_RESUMED member=${peer.member}`);
 }
 // A fresh valid MAC is still insufficient to steal a disconnected RTC ID.
 const held=peers[2],beforeHeld=await held.page.evaluate(()=>globalThis.rzaStats);
 await held.page.evaluate(()=>{globalThis.rzaCommand='hold_signal';});
 await held.page.waitForFunction(()=>globalThis.rzaStats?.lost===1,{timeout:5000});await wait(500);
 const wrong=await raw();wrong.ws.send(JSON.stringify({type:'join',room,resume:'00'.repeat(16),preserve:'yes'}));const challenge=await wrong.next();
 wrong.ws.send(JSON.stringify({type:'join',room,resume:'00'.repeat(16),preserve:'yes',auth:proof(room,challenge.challenge,3,false)}));assert.equal((await wrong.next()).reason,'resume');wrong.ws.close();
 await held.page.evaluate(()=>{globalThis.rzaCommand='resume_signal';});
 await held.page.waitForFunction(old=>globalThis.rzaStats?.resumes>old,{timeout:15000},beforeHeld.resumes);
 const afterHeld=await held.page.evaluate(()=>globalThis.rzaStats);assert.equal(afterHeld.id,beforeHeld.id);assert.deepEqual(afterHeld.connections,beforeHeld.connections);assert.ok(afterHeld.during_loss>beforeHeld.during_loss);
 reconnects.push({member:3,before:beforeHeld,after:afterHeld});
 console.log('RZA_WRONG_CONTINUATION_REJECTED');
 const late=await open(4);await until(()=>late.lines.some(x=>x.startsWith('RZA_DATA_OK')),'late join after signaling recovery');
 console.log('RZA_LATE_JOIN_AFTER_RESUME_OK');
 fs.writeFileSync(`${logs}/reconnects.json`,JSON.stringify(reconnects,null,2));
 const expired=await raw();expired.ws.send(JSON.stringify({type:'create',room}));assert.equal((await expired.next()).type,'auth_challenge');
 await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{expired.ws.terminate();reject(new Error('challenge did not expire'));},7000);expired.ws.once('close',()=>{clearTimeout(timer);resolve();});});
 console.log('RZA_UNUSED_CHALLENGE_EXPIRED');
 await wait(500);for(const p of peers)assert.equal(p.errors.length,0,p.errors.join('\n'));
 console.log('REPLAY_AUTHENTICATED_RTC_OK');
}finally{await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));}
process.exit(0);
