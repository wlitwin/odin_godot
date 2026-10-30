import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {relayConfig,installRelayProbe,requireRelay,relayPairs} from '../../tests/replay_turn/probe.mjs';
const [base,service,work,sprayPath]=process.argv.slice(2),logs=path.join(work,'browser');fs.mkdirSync(logs,{recursive:true});const agents=[],events=[];let sequence=0;
const namespace='scrapyard-durable-assets';const pause=ms=>new Promise(r=>setTimeout(r,ms));
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
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'1',profile_namespace:namespace,run:'0',encounter:'spray',mobs:'0',audio:'0'});
 if(process.env.REPLAY_TURN_PROVIDER==='1')url.searchParams.set('room_relay','1');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1,'menu');if(seedRole)await seed(a,seedRole);return a;
}
try{
 let host=await open('source','owner-profile','host');
 await send(host,'press','Doors/Host');await until(host,s=>s.ready&&s.cores1===7&&s.parts1===2,'joined');
 await send(host,'drive');await send(host,'press','Actions/Ready');await until(host,s=>s.marked_ready1,'ready');await send(host,'press','Actions/Start');
 await until(host,s=>s.stage===1&&s.spray_bytes1>0,'spray-loaded');await send(host,'stamp');await until(host,s=>s.spray_stamp1>0,'stamped');
 await send(host,'save');const saved=await until(host,s=>s.save_completed>0,'published');assert.equal(saved.save_error,0);
 const token=fs.readFileSync(path.join(work,'host/replay_identity')),hash=crypto.createHash('sha256').update(token).digest('hex');
 await host.page.evaluate(async ({namespace,key})=>{
  const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+namespace,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error)});
  try{await new Promise((r,j)=>{const tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').delete(key);tx.oncomplete=r;tx.onabort=()=>j(tx.error)})}finally{db.close()}
 },{namespace,key:'spray-'+hash});
 await host.browser.close();fs.writeFileSync(path.join(work,'source-stopped'),'done');
 const deadline=Date.now()+45000;while(!fs.existsSync(path.join(work,'service-restarted'))){if(Date.now()>deadline)throw Error('service restart timed out');await pause(60)}
 host=await open('restored','owner-profile');
 const empty=await until(host,s=>s.recent===1,'fresh-empty-cache');assert.equal(empty.asset_bytes,0);
 const localMissing=await host.page.evaluate(async ({namespace,key})=>{
  const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+namespace,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error)});
  try{return await new Promise((r,j)=>{const tx=db.transaction('blobs','readonly'),q=tx.objectStore('blobs').get(key);q.onsuccess=()=>r(q.result===undefined);q.onerror=()=>j(q.error)})}finally{db.close()}
 },{namespace,key:'spray-'+hash});assert.equal(localMissing,true);
 await send(host,'press','Doors/Rejoin');
 const restored=await until(host,s=>s.ready&&s.steady&&s.epoch===2&&s.restore_publication===1,'restored');
 assert.equal(restored.restore_error,0);assert.equal(restored.restore_tick,saved.save_tick);assert.ok(restored.incarnation>saved.incarnation);
 assert.equal(restored.spray_id,saved.spray_id);assert.equal(restored.spray_stamp1,saved.spray_stamp1);assert.equal(restored.spray_cached1,1);assert.equal(restored.asset_bytes,saved.spray_bytes1);
 assert.equal(restored.cores1,7);assert.equal(restored.parts1,2);assert.equal(restored.separate,1);
 await send(host,'drive');const shots=restored.shots1;await send(host,'aim',true);await until(host,s=>s.shots1>shots,'continued-fire');await send(host,'aim',false);
 await send(host,'save');const final=await until(host,s=>s.save_completed>0&&s.save_revision>=2,'republished');assert.equal(final.save_error,0);
 await host.page.screenshot({path:path.join(logs,'restored-spray.png')});
 console.log(`REPLAY_SCRAPYARD_DURABLE_ASSET_BROWSER_OK source_tick=${saved.save_tick} restored_tick=${restored.restore_tick} epoch=2 incarnation=${restored.incarnation} asset_bytes=${restored.asset_bytes} revision=${final.save_revision} local_spray_deleted=true cold_cache=true shots=${final.shots1}`);
}finally{
 fs.writeFileSync(path.join(logs,'events.json'),JSON.stringify(events,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();
}
process.exit(0);
async function identity(a){return a.page.evaluate(async namespace=>{const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+namespace,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});try{const value=await new Promise((r,j)=>{const q=db.transaction('blobs','readonly').objectStore('blobs').get('identity');q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});const hash=await crypto.subtle.digest('SHA-256',await value.bytes.arrayBuffer());return Array.from(new Uint8Array(hash),b=>b.toString(16).padStart(2,'0')).join('');}finally{db.close();}},namespace);}
