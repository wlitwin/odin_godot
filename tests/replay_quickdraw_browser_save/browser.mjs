import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const namespace='replay-quickdraw',events=[],pages=[];let browser,command=0,index=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const paths={solo:'UI/Lobby/Column/Buttons/Solo',resume:'UI/Lobby/Column/Resume/Solo',leave:'UI/Leave'};
const safe=s=>{const result={...s};delete result.invite;return result;};
async function launch(){browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new',userDataDir:out+'/profile',protocolTimeout:30000,args:['--no-sandbox','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});}
async function status(a){assert.deepEqual(a.errors,[]);const s=await a.page.evaluate(()=>globalThis.quickdrawStatus||null);if(s&&!a.allowBad)assert.equal(s.profile_failed,0);return s;}
async function until(a,test,label,ms=45000){await a.page.bringToFront();const end=Date.now()+ms;let s;while(Date.now()<end){s=await status(a);if(s&&test(s)){events.push({role:a.role,event:label,...safe(s)});return s;}await pause(50);}throw Error(a.role+' '+label+' timeout '+JSON.stringify(s?safe(s):null));}
async function send(a,kind,value){await a.page.bringToFront();const id=++command;await a.page.evaluate(x=>globalThis.quickdrawCommand=x,{id,kind,value});const end=Date.now()+10000;while(Date.now()<end){const s=await status(a);if(s?.command===id)return s;await pause(20);}throw Error('command '+kind+' timed out');}
async function open(role,{bad=false,autoResume=false}={}){
 const page=await browser.newPage(),a={role,page,errors:[],allowBad:bad};pages.push(a);const id=++index;await page.setViewport({width:960,height:540});await page.evaluateOnNewDocument(installBufferTrace);
 page.on('console',m=>{const text=m.text();fs.appendFileSync(out+'/'+role+'-'+id+'.log',text+'\n');if(/REPLAY_QUICKDRAW_FAIL|SCRIPT ERROR|ERROR:|INVALID_OPERATION/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(e.stack));
 const url=new URL(base);const params={online_test:'1',save_slot:'duel',gold:'1'};if(autoResume){params.role='solo';params.resume='1';}url.search=new URLSearchParams(params);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});if(!bad)await until(a,s=>s.profile_ready===1&&s.slot_phase>=2,'slot ready',120000);return a;
}
async function save(a,{success=true,leave=false}={}){const before=await status(a),reply=await send(a,leave?'save_leave':'save');assert.equal(reply.result,true);if(leave)assert.equal(reply.leave_blocked,true);const done=await until(a,s=>s.slot_receipt>before.slot_receipt,'save receipt');assert.equal(done.slot_success,success?1:0);return done;}
async function records(a){return a.page.evaluate(async ns=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 try{const rows=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),store=tx.objectStore('blobs'),values=store.getAll(),keys=store.getAllKeys();tx.oncomplete=()=>resolve(values.result.map((v,i)=>({key:keys.result[i],revision:v.revision,blob:v.bytes})));tx.onerror=()=>reject(tx.error);});
  const result=[];for(const row of rows){const bytes=new Uint8Array(await row.blob.arrayBuffer()),hash=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));result.push({key:row.key,revision:row.revision,bytes:Array.from(bytes),hash:Array.from(hash,b=>b.toString(16).padStart(2,'0')).join('')});}return result;
 }finally{db.close();}
 },namespace);}
async function replace(a,key,bytes,revision){await a.page.evaluate(async ({ns,key,bytes,revision})=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 try{await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').put({revision,bytes:new Blob([new Uint8Array(bytes)])},key);tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);});}finally{db.close();}
 },{ns:namespace,key,bytes,revision});}try{
 await launch();const writer=await open('writer');await send(writer,'name','Saved Rider');await send(writer,'press',paths.solo);assert.equal((await send(writer,'buy')).result,true);await send(writer,'drive',[-1,1,5,0,1]);
 await until(writer,s=>s.ready&&s.boots1===1&&s.tick>40&&s.bullets>0&&s.fire_cd>0,'live save window');
 const first=await save(writer,{leave:true});assert.equal(first.slot_revision,1);const original=await records(writer),identity=original.find(r=>r.key==='identity');assert.equal(identity.bytes.length,16);await writer.page.screenshot({path:out+'/saved.png'});
 const process=browser.process();await new Promise(resolve=>{process.once('exit',resolve);assert.equal(process.kill('SIGKILL'),true);});
 await launch();const resumed=await open('resumed');let loaded=await status(resumed);assert.equal(loaded.name,'Saved Rider');assert.equal(loaded.profile_hash,first.profile_hash);assert.equal(loaded.slot_revision,1);assert.equal(loaded.resume_enabled,true);await resumed.page.screenshot({path:out+'/resume-menu.png'});
 await send(resumed,'press',paths.resume);const restored=await until(resumed,s=>s.ready&&s.exact===1,'exact restore');assert.equal(restored.restored_hash,first.saved_hash);assert.equal(restored.restored_tick,first.saved_tick);assert.equal(restored.epoch,2);assert.equal(restored.boots1,1);
 await send(resumed,'drive',[0,0,0,0,0]);await until(resumed,s=>s.bullets===0,'saved projectile completes');const count=(await status(resumed)).lobs;
 await send(resumed,'drive',[0,0,4,0,0]);await until(resumed,s=>s.lobs>count,'new lob');await send(resumed,'drive',[0,0,0,0,0]);await until(resumed,s=>s.bullets===0,'new projectile completes');
 const second=await save(resumed);assert.equal(second.slot_revision,2);await send(resumed,'freeze');await resumed.page.close();
 // Automatic resume must wait for both asynchronous identity and slot reads.
 const auto=await open('auto-resume',{autoResume:true});const automatic=await until(auto,s=>s.ready&&s.exact===1,'deep-link resume');assert.equal(automatic.restored_hash,second.saved_hash);assert.equal(automatic.epoch,3);await send(auto,'freeze');await auto.page.close();
 const a=await open('tab-a'),b=await open('tab-b');for(const tab of [a,b]){assert.equal((await status(tab)).slot_revision,2);await send(tab,'press',paths.resume);await until(tab,s=>s.ready&&s.exact===1&&s.epoch===3,'tab resumed');}
 const winner=await save(a);assert.equal(winner.slot_revision,3);const committed=(await records(a)).find(r=>r.key.startsWith('save/')&&r.key.endsWith('/duel'));
 const stale=await save(b,{success:false});assert.equal(stale.slot_store_error,2);assert.match(stale.save_notice,/Another tab changed/);let kept=(await records(b)).find(r=>r.key===committed.key);assert.equal(kept.hash,committed.hash);assert.equal(kept.revision,3);await b.page.screenshot({path:out+'/stale-tab.png'});await send(a,'freeze');await b.page.close();
 await replace(a,committed.key,[1,2,3,4],3);const corrupt=await open('corrupt-slot');assert.equal((await status(corrupt)).slot_phase,4);assert.equal((await status(corrupt)).resume_enabled,false);
 await send(corrupt,'press',paths.resume);assert.equal((await status(corrupt)).ready,false);await send(corrupt,'press',paths.solo);await until(corrupt,s=>s.ready,'new game preserves bad slot');assert.equal((await send(corrupt,'save')).result,false);assert.deepEqual((await records(corrupt)).find(r=>r.key===committed.key).bytes,[1,2,3,4]);
 await send(corrupt,'press',paths.leave);await send(corrupt,'slot','bad/slot');await until(corrupt,s=>s.notice.includes('1–48'),'invalid slot');assert.equal((await status(corrupt)).resume_enabled,false);
 await send(corrupt,'slot','alternate');await until(corrupt,s=>s.slot_phase===2&&s.slot_has===0,'alternate slot');await send(corrupt,'press',paths.solo);assert.equal((await save(corrupt)).slot_revision,1);assert.deepEqual((await records(corrupt)).find(r=>r.key===committed.key).bytes,[1,2,3,4]);await corrupt.page.close();
 await replace(a,committed.key,committed.bytes,3);await replace(a,'identity',Array(16).fill(0),identity.revision);
 const bad=await open('corrupt-identity',{bad:true});await until(bad,s=>s.profile_failed===1,'identity refused');await send(bad,'press',paths.solo);assert.equal((await status(bad)).ready,false);assert.deepEqual((await records(bad)).find(r=>r.key==='identity').bytes,Array(16).fill(0));await bad.page.close();
 await replace(a,'identity',identity.bytes,identity.revision);assert.equal((await records(a)).find(r=>r.key==='identity').hash,identity.hash);
 const graphics=await a.page.evaluate(()=>globalThis.bufferTrace);assert.equal(graphics.conflicts,0);
 fs.writeFileSync(out+'/summary.json',JSON.stringify({pass:true,hard_kill_after_receipt:true,exact_restore:true,identity_and_name_retained:true,leave_during_write_blocked:true,continued_lobs:true,deep_link_resume:true,stale_tab_preserved:true,corrupt_slot_preserved:true,alternate_slot_saved:true,corrupt_identity_preserved:true,initial:{tick:first.saved_tick,hash:first.saved_hash,revision:1},resumed:{tick:restored.restored_tick,hash:restored.restored_hash,epoch:2},latest_revision:3,graphics},null,2));console.log('REPLAY_QUICKDRAW_BROWSER_SAVE_OK');
}catch(error){for(const a of pages){if(!a.page.isClosed()){const s=await a.page.evaluate(()=>globalThis.quickdrawStatus).catch(()=>null);if(s)events.push({role:a.role,event:'failure',...safe(s)});}}throw error;}
finally{fs.writeFileSync(out+'/events.json',JSON.stringify(events,null,2));if(browser?.connected)await browser.close();}
process.exit(0);
