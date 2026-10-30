import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {relayConfig,installRelayProbe,requireRelay,relayPairs} from '../../tests/replay_turn/probe.mjs';
const [base,service,work,sprayPath]=process.argv.slice(2),logs=path.join(work,'browser');fs.mkdirSync(logs,{recursive:true});const agents=[],events=[];let sequence=0;
const namespace='scrapyard-online-fixture';const pause=ms=>new Promise(r=>setTimeout(r,ms));
const ice=relayConfig(),relayObservations=[];
async function until(a,test,label){const end=Date.now()+45000;let value;while(Date.now()<end){assert.deepEqual(a.errors,[]);value=await a.page.evaluate(()=>globalThis.partyStatus||null);if(value){assert.equal(value.failed,0,value.notice);assert.equal(value.profile_error,0,'profile error');if(test(value)){const safe={...value};delete safe.invite;events.push({role:a.role,event:label,...safe});return value;}}await pause(60);}if(value)delete value.invite;throw Error(`${a.role} ${label} ${JSON.stringify(value)}`);}
async function send(a,kind,value,extra={}){const id=++sequence;await a.page.evaluate(q=>{globalThis.partyCommand=q;},{id,kind,value,...extra});return until(a,s=>s.command===id,kind);}
async function seed(a,role){
 const dir=path.join(work,role),token=fs.readFileSync(path.join(dir,'replay_identity')),hash=crypto.createHash('sha256').update(token).digest('hex');
 const profile=fs.readFileSync(path.join(dir,`replay_profile_${hash}`)),spray=role==='host'?fs.readFileSync(sprayPath):null;
 await a.page.evaluate(async ({namespace,token,hash,profile,spray})=>{
  const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+namespace,1);q.onupgradeneeded=()=>q.result.createObjectStore('blobs');q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});
  try{await new Promise((r,j)=>{const tx=db.transaction('blobs','readwrite'),store=tx.objectStore('blobs');store.put({revision:1,bytes:new Blob([new Uint8Array(token)])},'identity');store.put({revision:1,bytes:new Blob([new Uint8Array(profile)])},'profile-'+hash);if(spray)store.put({revision:1,bytes:new Blob([new Uint8Array(spray)])},'spray-'+hash);tx.oncomplete=r;tx.onabort=()=>j(tx.error);});}finally{db.close();}
 },{namespace,token:[...token],hash,profile:[...profile],spray:spray?[...spray]:null});
}
async function open(role,profile,seedRole){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:path.join(logs,profile),headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:900,deviceScaleFactor:1});const a={browser,page,role,errors:[]};agents.push(a);
 await installRelayProbe(page,ice);
 page.on('console',m=>{const text=m.text();fs.appendFileSync(path.join(logs,role+'.log'),text+'\n');if(/REPLAY_SCRAPYARD_FAIL|RSY_PROFILE_ERROR|SCRIPT ERROR|ERROR:/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'1',profile_namespace:namespace,run:'0',encounter:'migration',audio:'0'});
 if(process.env.REPLAY_TURN_PROVIDER==='1')url.searchParams.set('room_relay','1');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1,'menu');if(seedRole)await seed(a,seedRole);return a;
}
async function identity(a){return a.page.evaluate(async namespace=>{const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+namespace,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});try{const value=await new Promise((r,j)=>{const q=db.transaction('blobs','readonly').objectStore('blobs').get('identity');q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});const hash=await crypto.subtle.digest('SHA-256',await value.bytes.arrayBuffer());return Array.from(new Uint8Array(hash),b=>b.toString(16).padStart(2,'0')).join('');}finally{db.close();}},namespace);}
try{
 let host=await open('host','host-browser','host');const hostIdentity=await identity(host);await send(host,'press','Doors/Host');
 const issued=await until(host,s=>s.invited===1&&s.ready===1,'created'),invite=issued.invite;
 await send(host,'invite','Party invite hidden in this test screenshot');await host.page.screenshot({path:logs+'/party-created.png'});await send(host,'invite',invite);
 const guest=await open('guest','guest-browser','guest');const guestIdentity=await identity(guest);await send(guest,'invite',invite);await send(guest,'press','Doors/Join');
 for(const a of [host,guest]){const s=await until(a,s=>s.ready===1&&s.players===2&&s.cores1===7&&s.cores2===7&&s.parts1===2&&s.parts2===2&&s.ability01===5&&s.ability02===4,'profiles-loaded');assert.equal(s.separate,1);await send(a,'drive');}
 await requireRelay(host.page,relayObservations,'host-joined');await requireRelay(guest.page,relayObservations,'guest-joined');
 let originalCredentialExpires=0;
 if(process.env.REPLAY_TURN_PROVIDER==='1'){
  originalCredentialExpires=Math.max(...(await relayPairs(host.page)).map(r=>r.credentialExpires));assert.ok(originalCredentialExpires>0);
  await until(host,s=>s.relay_revision>=2,'relay-refreshed');await until(guest,s=>s.relay_revision>=2,'relay-refreshed');
  while(Date.now()/1000<=originalCredentialExpires+1)await pause(100);
 }
 await send(guest,'pause_assets',true);await send(host,'press','Actions/Ready');await send(guest,'press','Actions/Ready');await until(host,s=>s.marked_ready1===1&&s.marked_ready2===1,'all-ready');await send(host,'press','Actions/Start');
 await until(host,s=>s.stage===1&&s.spray_bytes1>0,'spray-loaded');await send(host,'stamp');
 const waiting=await until(guest,s=>s.asset_prepare_wait===1,'asset-barrier');assert.equal(waiting.backup_spray,0);await send(guest,'pause_assets',false);await until(guest,s=>s.spray_cached1===1,'asset-ready');
 await send(host,'cast',null,{slot:0,x:500,y:1040});await send(host,'cast',null,{slot:1,x:800,y:1040});await until(guest,s=>s.active_backup===1&&s.backup_spray===1,'active-backup');await send(host,'handoff');
 const restored=await until(guest,s=>s.epoch===2&&s.recovery_ready===1,'restored');assert.equal(restored.restored_exact,1);assert.equal(restored.restored_active,1);assert.equal(restored.lost_ticks,0);assert.equal(restored.spray_cached1,1);
 await requireRelay(guest.page,relayObservations,'guest-migrated');
 if(originalCredentialExpires)assert.ok((await relayPairs(guest.page)).every(r=>r.credentialExpires>originalCredentialExpires),'migration reused expired relay credentials');
 await until(host,s=>s.epoch===2&&s.steady===1&&!s.profile_writing,'departed');await host.browser.close();
 host=await open('returned','host-browser');await send(host,'press','Doors/Rejoin');
 const returned=await until(host,s=>s.epoch===2&&s.steady===1&&s.players===2&&s.incarnation>=3,'rejoined');assert.equal(returned.invite,invite);assert.equal(returned.separate,1);assert.equal(returned.look1,2);assert.equal(returned.iron1,1);assert.equal(returned.cores1,7);assert.equal(returned.parts1,2);
 assert.equal(await identity(host),hostIdentity);assert.equal(await identity(guest),guestIdentity);
 await send(host,'aim',true);await until(guest,s=>s.shots1>0&&s.cores2===7&&s.parts2===2,'returned-action');await send(host,'aim',false);
 await requireRelay(host.page,relayObservations,'host-returned');await requireRelay(guest.page,relayObservations,'guest-after-return');
 await host.page.screenshot({path:logs+'/returned-combat.png'});
 console.log('REPLAY_SCRAPYARD_ONLINE_BROWSER_OK profiles_preserved=true identity_separate=true asset_barrier=true active_restore=true lost=0 durable_rejoin=true');
}finally{fs.writeFileSync(path.join(logs,'events.json'),JSON.stringify(events,null,2));fs.writeFileSync(path.join(logs,'relay.json'),JSON.stringify(relayObservations,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();}
process.exit(0);
