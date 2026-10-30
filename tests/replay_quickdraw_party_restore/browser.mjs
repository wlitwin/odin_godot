import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,service,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const agents=[],events=[];let command=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const paths={host:'UI/Lobby/Column/Buttons/Host',join:'UI/Lobby/Column/Buttons/Join',start:'UI/Lobby/Column/Start',leave:'UI/Leave',rejoin:'UI/Lobby/Column/Party/Choices/Rejoin'};
const safe=s=>{const value={...s};delete value.invite;return value;};
async function status(a){assert.deepEqual(a.errors,[]);return a.page.evaluate(()=>globalThis.quickdrawStatus||null);}
async function until(a,predicate,label,timeout=45000){
 const end=Date.now()+timeout;let last;
 while(Date.now()<end){last=await status(a);if(last){assert.equal(last.failed,0,last.notice);assert.equal(last.profile_failed,0,'profile failure');if(predicate(last)){events.push({who:a.label,event:label,...safe(last)});return last;}}await pause(60);}
 throw Error(a.label+' '+label+' timeout '+JSON.stringify(last?safe(last):null));
}
async function send(a,kind,value){const id=++command;await a.page.evaluate(request=>globalThis.quickdrawCommand=request,{id,kind,value});const end=Date.now()+10000;while(Date.now()<end){const s=await status(a);if(s?.command===id)return s;await pause(25);}throw Error(kind+' command timeout');}
async function open(label,profile){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:out+'/'+profile,headless:'new',protocolTimeout:30000,args:['--no-sandbox','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage(),a={label,browser,page,errors:[]};agents.push(a);await page.setViewport({width:960,height:540});
 await page.evaluateOnNewDocument(installBufferTrace);
 await page.evaluateOnNewDocument(()=>{const Native=globalThis.RTCPeerConnection;globalThis.quickdrawRtc=[];globalThis.RTCPeerConnection=class extends Native{constructor(...args){super(...args);globalThis.quickdrawRtc.push(this);}};});
 page.on('console',m=>{const text=m.text();fs.appendFileSync(out+'/'+label+'.log',text+'\n');if(/REPLAY_QUICKDRAW_FAIL|SCRIPT ERROR|ERROR:|INVALID_OPERATION/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(e.stack));
 const url=new URL(base);url.search=new URLSearchParams({online_test:'1',probe:'1',room_service:service,room_local:'1',gold:'1',latency:'120'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.profile_ready===1&&s.recent===1,'menu',120000);return a;
}
async function rtc(a){
 const data=await a.page.evaluate(async()=>{const rows=[];for(const peer of globalThis.quickdrawRtc){if(peer.connectionState!=='connected')continue;for(const s of (await peer.getStats()).values()){if(s.type==='candidate-pair'&&s.nominated&&s.state==='succeeded')rows.push({sent:s.bytesSent,received:s.bytesReceived});}}return {rows,graphics:globalThis.bufferTrace};});
 assert.ok(data.rows.some(r=>r.sent>0&&r.received>0),'real RTC traffic');assert.equal(data.graphics.conflicts,0);events.push({who:a.label,event:'rtc',...data});
}
async function localSlots(a){
 const count=await a.page.evaluate(async()=>{
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/replay-quickdraw',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  try{return await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),r=tx.objectStore('blobs').getAllKeys();tx.oncomplete=()=>resolve(r.result.filter(key=>String(key).startsWith('save/')).length);tx.onerror=()=>reject(tx.error);});}finally{db.close();}
 });
 assert.equal(count,0,'Party publication must not create a browser-local save');events.push({who:a.label,event:'local-slot-separation',count});
}
async function common(peers){
 for(let i=0;i<100;i++){const tick=(await status(peers[0])).tick-30;if(tick<1){await pause(60);continue;}const replies=await Promise.all(peers.map(a=>send(a,'hash',tick)));if(replies.every(s=>s.hash!=='-1')){for(const s of replies)assert.equal(s.hash,replies[0].hash);return {tick,hash:replies[0].hash};}await pause(80);}throw Error('common world unavailable');
}
async function kill(a){const process=a.browser.process();await new Promise(resolve=>{if(process.exitCode!==null){resolve();return;}process.once('exit',resolve);process.kill('SIGKILL');});}try{
 let host=await open('source-host','host-profile');await send(host,'name','Marshal');await send(host,'press',paths.host);
 const created=await until(host,s=>s.ready&&s.invited===1&&s.profile_saved===1,'created');const invite=created.invite,profileHash=created.profile_hash;
 let deputy=await open('source-deputy','deputy-profile');await send(deputy,'name','Deputy');await send(deputy,'invite',invite);await send(deputy,'press',paths.join);await until(deputy,s=>s.ready&&s.seat===2,'deputy joined');
 let rider=await open('source-rider','rider-profile');await send(rider,'name','Rider');await send(rider,'invite',invite);await send(rider,'press',paths.join);await until(rider,s=>s.ready&&s.seat===3,'rider joined');
 let watch=await open('source-watch','watch-profile');await send(watch,'name','Watcher');await send(watch,'watch',true);await send(watch,'invite',invite);await send(watch,'press',paths.join);const watched=await until(watch,s=>s.ready&&s.observer===1&&s.seat===0&&s.backup===0,'observer joined');
 for(const a of [host,deputy,rider,watch])await until(a,s=>s.players===3&&s.named,'named party');
 await send(host,'press',paths.start);await until(watch,s=>s.started===1,'started');
 await send(deputy,'drive',[0,1,0,0,1]);assert.equal((await send(rider,'buy')).result,true);await send(rider,'drive',[0,0,5,2,-1]);
 await until(host,s=>s.hp2===0&&s.bullets>0&&s.boots3===1,'combat before publication');
 assert.equal((await send(host,'save')).result,true);const saved=await until(host,s=>s.party_save_completed===1&&s.party_save_epoch===1,'published');
 const savedHash=(await send(host,'hash',saved.party_save_tick)).hash;assert.notEqual(savedHash,'-1');
 fs.writeFileSync(out+'/saved.json',JSON.stringify({tick:saved.party_save_tick,hash:savedHash,revision:saved.party_save_revision,incarnation:saved.incarnation},null,2));
 await Promise.all([host,deputy,rider,watch].map(a=>send(a,'freeze')));await Promise.all([host,deputy,rider,watch].map(kill));fs.writeFileSync(out+'/source-stopped','done');
 const restartDeadline=Date.now()+45000;while(!fs.existsSync(out+'/service-restarted')){assert.ok(Date.now()<restartDeadline,'service restart deadline');await pause(60);}
 watch=await open('return-watch','watch-profile');await send(watch,'watch',true);await send(watch,'press',paths.rejoin);await until(watch,s=>s.member===4&&s.incarnation>watched.incarnation,'observer registered');
 assert.equal((await status(watch)).authority,0,'observer cannot restore an authority runtime');
 host=await open('return-host','host-profile');assert.equal((await status(host)).name,'Marshal');assert.equal((await status(host)).profile_hash,profileHash);await send(host,'press',paths.rejoin);
 const restored=await until(host,s=>s.ready&&s.steady===1&&s.epoch===2&&s.party_restore_publication===1,'published restore',60000);
 assert.equal(restored.party_restore_error,0);assert.equal(restored.party_restore_tick,saved.party_save_tick);assert.ok(restored.incarnation>saved.incarnation);assert.equal(restored.seat,1);assert.equal(restored.separate,1);assert.match(restored.recovery_notice,/Saved party restored/);
 const restoredHash=(await send(host,'hash',saved.party_save_tick)).hash;assert.equal(restoredHash,savedHash,'exact saved world');
 await until(watch,s=>s.ready&&s.steady===1&&s.epoch===2&&s.observer===1&&s.seat===0&&s.backup===0,'observer follows restored host');
 deputy=await open('return-deputy','deputy-profile');await send(deputy,'press',paths.rejoin);await until(deputy,s=>s.ready&&s.steady===1&&s.epoch===2&&s.seat===2,'deputy returned');
 rider=await open('return-rider','rider-profile');await send(rider,'press',paths.rejoin);await until(rider,s=>s.ready&&s.steady===1&&s.epoch===2&&s.seat===3&&s.boots3===1,'rider returned');
 for(const a of [host,deputy,rider,watch])await until(a,s=>s.players===3&&s.named&&s.separate===1,'restored named roster');
 const resumed=await status(host);await send(rider,'drive',[0,0,5,2,-1]);
 await until(host,s=>s.hits>resumed.hits&&s.lobs>resumed.lobs&&s.life2>resumed.life2,'continued restored combat',45000);
 await send(rider,'drive',[0,0,0,0,0]);await until(host,s=>s.bullets===0,'drained');
 await until(watch,s=>s.observer_named===1,'named observer ready');await send(watch,'chat','after the saved party returned');
 for(const a of [host,deputy,rider,watch])await until(a,s=>s.chat.includes('Watcher (observer): after the saved party returned'),'new chat');
 assert.equal((await send(rider,'save')).result,false,'guest publication denied');assert.equal((await send(host,'save')).result,true);
 const published=await until(host,s=>s.party_save_completed===1&&s.party_save_epoch===2&&s.party_save_revision===2,'republished');
 assert.equal(published.recovery_layout_clear,true,'recovery controls overlap');
 const final=await common([host,deputy,rider,watch]);for(const a of [host,deputy,rider,watch]){await rtc(a);await localSlots(a);}
 await host.page.screenshot({path:out+'/restored.png'});
 fs.writeFileSync(out+'/summary.json',JSON.stringify({pass:true,all_game_processes_killed:true,service_restarted:true,from_publication:true,saved:{tick:saved.party_save_tick,hash:savedHash,revision:1},restored:{tick:restored.party_restore_tick,hash:restoredHash,epoch:2,incarnation:restored.incarnation},identity_retained:true,returning_players:3,observer:true,continued_combat:true,publication_revision:published.party_save_revision,publication_tick:published.party_save_tick,final},null,2));
 await Promise.all([host,deputy,rider,watch].map(a=>send(a,'freeze')));console.log('REPLAY_QUICKDRAW_PARTY_RESTORE_WEB_OK');
}catch(error){for(const a of agents){if(a.browser.connected){const s=await a.page.evaluate(()=>globalThis.quickdrawStatus).catch(()=>null);if(s)events.push({who:a.label,event:'failure-state',...safe(s)});}}throw error;}
finally{fs.writeFileSync(out+'/events.json',JSON.stringify(events,null,2));await Promise.allSettled(agents.filter(a=>a.browser.connected).map(a=>a.browser.close()));}
process.exit(0);
