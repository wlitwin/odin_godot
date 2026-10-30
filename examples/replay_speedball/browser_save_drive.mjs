import puppeteer from '../../tests/web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,logs]=process.argv.slice(2);fs.mkdirSync(logs,{recursive:true});
const namespace='replay-speedball',events=[],pages=[];let browser,command=0,index=0;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const paths={solo:'UI/Lobby/Column/Buttons/Solo',resume:'UI/Lobby/Column/Resume/Solo',again:'UI/Again',leave:'UI/Leave'};
async function launch(){browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:logs+'/profile',protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});}
async function open(role,allowBad=false){
 const page=await browser.newPage(),a={role,page,errors:[],allowBad};pages.push(a);const id=++index;
 await page.setViewport({width:1280,height:720,deviceScaleFactor:1});
 page.on('console',message=>{const text=message.text();fs.appendFileSync(`${logs}/${role}-${id}.log`,text+'\n');if(/REPLAY_SPEEDBALL_FAIL|SCRIPT ERROR|ERROR:/.test(text))a.errors.push(text);});page.on('pageerror',error=>a.errors.push(String(error)));
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,save_slot:'pitch',goals:'2'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 if(!allowBad)await until(a,s=>s.profile_ready===1&&s.save_phase>=2,'menu');return a;
}
async function status(a){assert.deepEqual(a.errors,[]);const s=await a.page.evaluate(()=>globalThis.speedballStatus||null);if(s&&!a.allowBad)assert.equal(s.profile_failed,0,`${a.role} profile failure`);return s;}
function safe(s){const x={...s};delete x.invite;return x;}
async function until(a,test,label,ms=45000){await a.page.bringToFront();const end=Date.now()+ms;let s;while(Date.now()<end){s=await status(a);if(s&&test(s)){events.push({role:a.role,event:label,...safe(s)});return s;}await pause(60);}throw Error(`${a.role} ${label} timeout ${JSON.stringify(s?safe(s):null)}`);}
async function send(a,kind,value){await a.page.bringToFront();const id=++command;await a.page.evaluate(x=>{globalThis.speedballCommand=x;},{id,kind,value});const end=Date.now()+10000;while(Date.now()<end){const s=await status(a);if(s?.command===id)return s;await pause(25);}throw Error(`${a.role}: ${kind} command timeout`);}
async function save(a,success=true){const before=await status(a),submitted=await send(a,'save');assert.equal(submitted.result,true,'save must submit before completion');const done=await until(a,s=>s.save_receipt>before.save_receipt,'save-receipt');assert.equal(done.save_ok,success?1:0);return done;}
async function records(a){return a.page.evaluate(async ns=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 try{const rows=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),store=tx.objectStore('blobs'),values=store.getAll(),keys=store.getAllKeys();tx.oncomplete=()=>resolve(values.result.map((v,i)=>({key:keys.result[i],revision:v.revision,blob:v.bytes})));tx.onerror=()=>reject(tx.error);});
  const result=[];for(const row of rows){const bytes=new Uint8Array(await row.blob.arrayBuffer()),hash=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));result.push({key:row.key,revision:row.revision,bytes:Array.from(bytes),hash:Array.from(hash,b=>b.toString(16).padStart(2,'0')).join('')});}return result;
 }finally{db.close();}
 },namespace);}
async function replace(a,key,bytes,revision){await a.page.evaluate(async ({ns,key,bytes,revision})=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 try{await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').put({revision,bytes:new Blob([new Uint8Array(bytes)])},key);tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);});}finally{db.close();}
 },{ns:namespace,key,bytes,revision});}
try{
 await launch();let writer=await open('writer');await send(writer,'name','Saved Kicker');await send(writer,'press',paths.solo);await send(writer,'bot','striker');
 await until(writer,s=>s.ready&&s.moving===1&&s.left+s.right>0&&s.winner===0,'scored-moving-pitch',60000);
 const first=await save(writer);assert.equal(first.save_revision,1);const original=await records(writer),identity=original.find(r=>r.key==='identity');assert.equal(identity.bytes.length,16);
 await writer.page.screenshot({path:logs+'/saved.png'});
 // Stop the whole owned browser process after the IndexedDB completion receipt.
 const child=browser.process(),exited=new Promise(resolve=>child.once('exit',resolve));assert.equal(child.kill('SIGKILL'),true);await exited;await pause(300);
 await launch();const resumed=await open('resumed');const loaded=await status(resumed);assert.equal(loaded.name,'Saved Kicker');assert.equal(loaded.profile_hash,first.profile_hash);assert.equal(loaded.save_revision,1);assert.equal(loaded.resume_enabled,true);assert.ok(!loaded.notice.includes("Loading"));await resumed.page.screenshot({path:logs+"/resume-menu.png"});
 await send(resumed,'press',paths.resume);const restored=await until(resumed,s=>s.ready&&s.restored_exact===1,'restored');assert.equal(restored.restored_hash,first.saved_hash);assert.equal(restored.restored_tick,first.saved_tick);assert.equal(restored.epoch,2);
 await send(resumed,'bot','spiker');await until(resumed,s=>s.spikes>=first.spikes+2,'continued-spikes');await send(resumed,'bot','striker');await until(resumed,s=>s.winner>0,'finish-match',60000);
 await send(resumed,'bot','idle');await send(resumed,'press',paths.again);await until(resumed,s=>s.round===2&&s.winner===0,'restart');const second=await save(resumed);assert.equal(second.save_revision,2);assert.equal(second.round,2);await send(resumed,'freeze');await resumed.page.close();
 const a=await open('tab-a'),b=await open('tab-b');for(const tab of [a,b]){assert.equal((await status(tab)).save_revision,2);await send(tab,'press',paths.resume);await until(tab,s=>s.ready&&s.round===2&&s.epoch===3,'resumed-round-two');}
 const winner=await save(a);assert.equal(winner.save_revision,3);const committed=(await records(a)).find(r=>r.key.startsWith('save/')&&r.key.endsWith('/pitch'));
 const stale=await save(b,false);assert.equal(stale.store_error,2);assert.match(stale.save_notice,/Another tab changed/);const kept=(await records(b)).find(r=>r.key===committed.key);assert.equal(kept.hash,committed.hash);assert.equal(kept.revision,3);
 await b.page.screenshot({path:logs+'/stale-tab.png'});await send(a,'freeze');await b.page.close();
 await replace(a,committed.key,[1,2,3,4],3);const corrupt=await open('corrupt-slot');const failed=await status(corrupt);assert.equal(failed.save_phase,4);assert.equal(failed.save_error,2);assert.equal(failed.resume_enabled,false);
 await send(corrupt,'press',paths.resume);assert.equal((await status(corrupt)).ready,false);
 await send(corrupt,'press',paths.solo);await until(corrupt,s=>s.ready,'new-solo-with-bad-slot');assert.equal((await send(corrupt,'save')).result,false);assert.deepEqual((await records(corrupt)).find(r=>r.key===committed.key).bytes,[1,2,3,4]);
 await send(corrupt,'press',paths.leave);await send(corrupt,'slot','recovered');await until(corrupt,s=>s.save_phase===2&&s.save_has===0,'fresh-slot');await send(corrupt,'press',paths.solo);const recovered=await save(corrupt);assert.equal(recovered.save_revision,1);assert.deepEqual((await records(corrupt)).find(r=>r.key===committed.key).bytes,[1,2,3,4]);await corrupt.page.close();
 await replace(a,committed.key,committed.bytes,3);await replace(a,'identity',Array(16).fill(0),identity.revision);
 const bad=await open('corrupt-identity',true);await until(bad,s=>s.profile_failed===1,'identity-rejected');await send(bad,'press',paths.solo);assert.equal((await status(bad)).ready,false);assert.deepEqual((await records(bad)).find(r=>r.key==='identity').bytes,Array(16).fill(0));await bad.page.close();
 await replace(a,'identity',identity.bytes,identity.revision);assert.equal((await records(a)).find(r=>r.key==='identity').hash,identity.hash);
 const result={hard_kill_after_receipt:true,exact_restore:true,identity_and_name_retained:true,continued_spikes:true,restarted_round:2,stale_tab_preserved:true,corrupt_archive_preserved:true,alternate_slot_saved:true,corrupt_identity_preserved:true,initial:{tick:first.saved_tick,hash:first.saved_hash,revision:first.save_revision},resumed:{tick:restored.restored_tick,hash:restored.restored_hash,epoch:restored.epoch},latest_revision:3};
 fs.writeFileSync(logs+'/summary.json',JSON.stringify(result,null,2));console.log('REPLAY_SPEEDBALL_BROWSER_SAVE_CASES_OK');
}finally{fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));if(browser?.connected)await browser.close();}
