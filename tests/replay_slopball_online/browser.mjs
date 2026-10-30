import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
import {relayConfig,installRelayProbe,requireRelay} from '../replay_turn/probe.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,service,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const agents=[],events=[];let command=0;
const relayObservations=[];
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const paths={host:'UI/Lobby/Column/Buttons/Host',join:'UI/Lobby/Column/Buttons/Join',start:'UI/Lobby/Column/Start',leave:'UI/Leave',rejoin:'UI/Lobby/Column/Party/Choices/Rejoin'};
const safe=s=>{const value={...s};delete value.invite;return value;};
async function status(a){assert.deepEqual(a.errors,[]);return a.page.evaluate(()=>globalThis.slopballStatus||null);}
async function until(a,predicate,label,timeout=45000){
 const end=Date.now()+timeout;let last;
 while(Date.now()<end){last=await status(a);if(last){assert.equal(last.failed,0,last.notice);assert.equal(last.profile_failed,0,'profile failure');if(predicate(last)){events.push({who:a.label,event:label,...safe(last)});return last;}}await pause(60);}
 throw Error(a.label+' '+label+' timeout '+JSON.stringify(last?safe(last):null));
}
async function send(a,kind,value){const id=++command;await a.page.evaluate(request=>globalThis.slopballCommand=request,{id,kind,value});const end=Date.now()+10000;while(Date.now()<end){const s=await status(a);if(s?.command===id)return s;await pause(25);}throw Error(kind+' command timeout');}
async function open(label,profile){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:out+'/'+profile,headless:'new',protocolTimeout:30000,args:['--no-sandbox','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage(),a={label,browser,page,errors:[]};agents.push(a);await page.setViewport({width:960,height:540});
 await page.evaluateOnNewDocument(installBufferTrace);
 await installRelayProbe(page,relayConfig());
 await page.evaluateOnNewDocument(()=>{const Native=globalThis.RTCPeerConnection;globalThis.slopballRtc=[];globalThis.RTCPeerConnection=class extends Native{constructor(...args){super(...args);globalThis.slopballRtc.push(this);}};});
 page.on('console',m=>{const text=m.text();fs.appendFileSync(out+'/'+label+'.log',text+'\n');if(/REPLAY_SLOPBALL_FAIL|SCRIPT ERROR|ERROR:|INVALID_OPERATION/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(e.stack));
 const url=new URL(base);url.search=new URLSearchParams({online_test:'1',probe:'1',room_service:service,room_local:'1',goals:'9',players:'3',latency:process.env.RSL_ONLINE_LATENCY||'120'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.profile_ready===1&&s.recent===1,'menu',120000);return a;
}
async function rtc(a){
 await requireRelay(a.page,relayObservations,a.label);
 const data=await a.page.evaluate(async()=>{const rows=[];for(const peer of globalThis.slopballRtc){if(peer.connectionState!=='connected')continue;const stats=await peer.getStats();let pairs=[];for(const s of stats.values())if(s.type==='transport'&&s.selectedCandidatePairId){const pair=stats.get(s.selectedCandidatePairId);if(pair)pairs.push(pair);}if(!pairs.length)for(const s of stats.values())if(s.type==='candidate-pair'&&s.nominated&&s.state==='succeeded')pairs.push(s);for(const s of pairs)rows.push({sent:s.bytesSent,received:s.bytesReceived});}return {rows,graphics:globalThis.bufferTrace};});
 assert.ok(data.rows.some(r=>r.sent>0&&r.received>0),'real RTC traffic');assert.equal(data.graphics.conflicts,0);events.push({who:a.label,event:'rtc',...data});
}
async function localSlots(a){
 const count=await a.page.evaluate(async()=>{
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/replay-slopball',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  try{return await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),r=tx.objectStore('blobs').getAllKeys();tx.oncomplete=()=>resolve(r.result.filter(key=>String(key).startsWith('save/')).length);tx.onerror=()=>reject(tx.error);});}finally{db.close();}
 });
 assert.equal(count,0,'Party publication must not create a browser-local save');events.push({who:a.label,event:'local-slot-separation',count});
}
async function common(peers){
 for(let i=0;i<100;i++){const tick=(await status(peers[0])).tick-30;if(tick<1){await pause(60);continue;}const replies=await Promise.all(peers.map(a=>send(a,'hash',tick)));if(replies.every(s=>s.hash!=='-1')){for(const s of replies)assert.equal(s.hash,replies[0].hash);return {tick,hash:replies[0].hash};}await pause(80);}throw Error('common world unavailable');
}
async function kill(a){const process=a.browser.process();await new Promise(resolve=>{if(process.exitCode!==null){resolve();return;}process.once('exit',resolve);process.kill('SIGKILL');});}
function observer(s){assert.equal(s.observer,1);assert.equal(s.seat,0);assert.equal(s.backup,0);assert.equal(s.ball_solver,0,'observer solver must stay frozen');}
try{
 for(const mode of (process.env.RSL_ONLINE_MODES||'planned crash').split(/\s+/)){
  let host=await open(mode+'-host',mode+'-host-profile');await send(host,'name','Captain');await send(host,'press',paths.host);
  const created=await until(host,s=>s.ready&&s.steady===1&&s.invited===1&&s.profile_saved===1,'created');const invite=created.invite,identity=created.profile_hash;
  const striker=await open(mode+'-striker',mode+'-striker-profile');await send(striker,'name','Striker');await send(striker,'invite','invalid');await send(striker,'press',paths.join);assert.match((await status(striker)).notice,/complete party invite/);await send(striker,'invite',invite);await send(striker,'press',paths.join);await until(striker,s=>s.ready&&s.seat===2,'striker joined');
  const wing=await open(mode+'-wing',mode+'-wing-profile');await send(wing,'name','Wing');await send(wing,'invite',invite);await send(wing,'press',paths.join);await until(wing,s=>s.ready&&s.seat===3,'wing joined');
  const watch=await open(mode+'-watch',mode+'-watch-profile');await send(watch,'name','Watcher');await send(watch,'watch',true);await send(watch,'invite',invite);await send(watch,'press',paths.join);observer(await until(watch,s=>s.ready&&s.observer===1&&s.seat===0&&s.backup===0,'observer joined'));
  for(const a of [host,striker,wing,watch])await until(a,s=>s.players===3&&s.named&&s.separate===1,'named roster');
  await send(host,'chat','before host migration');for(const a of [host,striker,wing,watch])await until(a,s=>s.chat.includes('Captain: before host migration'),'initial chat');
  await send(host,'press',paths.start);await until(watch,s=>s.started===1,'started');await send(host,'bot','striker');
  if(process.env.REPLAY_TURN_ENABLE_FILE){
   for(const a of [host,striker,wing,watch])await rtc(a);
   fs.writeFileSync(process.env.REPLAY_TURN_ENABLE_FILE,'enable\n');
   events.push({event:'raw-turn-faults-enabled'});await pause(5000);
  }
  const backup=await until(striker,s=>s.moving_backup===1&&s.complete_backup===1&&s.backup_tick>0,'complete moving backup',60000);
  await until(host,s=>s.moving===1&&s.prepared_tick>=backup.backup_tick,'trigger ready');
  for(const a of [host,striker,wing,watch])await rtc(a);
  assert.equal((await send(host,'save')).result,true);const firstSave=await until(host,s=>s.party_save_completed>=1&&s.party_save_epoch===1,'first publication');
  await send(host,'bot','idle');await until(striker,s=>s.moving_backup===1,'moving handoff backup');
  if(mode==='planned'){assert.equal((await send(host,'handoff')).result,true);await until(host,s=>s.epoch===2&&s.steady===1,'former host');await host.browser.close();}else await kill(host);
  const restored=await until(striker,s=>s.epoch===2&&s.authority===1&&s.steady===1&&s.exact===1&&s.restored_moving===1&&s.seeded===1,'restored solver',60000);if(mode==='planned')assert.equal(restored.lost,0);
  await send(striker,'bot','striker');await until(striker,s=>s.kicks>0&&s.right>restored.restored_right,'new kicks and goal',60000);await send(striker,'bot','idle');
  observer(await until(watch,s=>s.epoch===2&&s.observer===1&&s.steady===1,'observer recovered'));
  await send(watch,'press',paths.leave);await send(watch,'press',paths.rejoin);observer(await until(watch,s=>s.epoch===2&&s.observer===1&&s.incarnation>=3&&s.steady===1,'observer returned'));
  host=await open(mode+'-returned',mode+'-host-profile');assert.equal((await status(host)).name,'Captain');assert.equal((await status(host)).profile_hash,identity);await send(host,'press',paths.rejoin);await until(host,s=>s.epoch===2&&s.seat===1&&s.steady===1&&s.invited===1,'host returned');assert.equal((await status(host)).invite,invite);
  await until(watch,s=>s.observer_named===1,'observer name ready');await send(watch,'chat','after browser migration');
  for(const a of [host,striker,wing,watch])await until(a,s=>s.chat.includes('Watcher (observer): after browser migration')&&s.chat.includes('Captain: before host migration'),'retained and new chat');
  assert.equal((await send(striker,'save')).result,true);const published=await until(striker,s=>s.party_save_completed>=1&&s.party_save_epoch===2&&s.party_save_revision>firstSave.party_save_revision,'successor publication');
  const final=await common([striker,host,wing,watch]);assert.ok(final.tick>restored.checkpoint);
  await host.page.setViewport({width:800,height:600});await pause(300);
  for(const a of [host,striker,wing,watch]){assert.equal((await status(a)).layout_clear,true);await rtc(a);await localSlots(a);}observer(await status(watch));
  await host.page.screenshot({path:out+'/'+mode+'-returned.png'});
  fs.writeFileSync(out+'/'+mode+'-result.json',JSON.stringify({pass:true,mode,exact:true,moving:true,solver_seeded:true,checkpoint:restored.checkpoint,lost:restored.lost,observer_rejoined:true,host_returned:true,profile_retained:true,continued_kicks_and_goal:true,publication_revision:published.party_save_revision,publication_tick:published.party_save_tick,final},null,2));
  await Promise.all([host,striker,wing,watch].map(a=>send(a,'freeze')));await Promise.all([host,striker,wing,watch].map(a=>a.browser.close()));console.log('REPLAY_SLOPBALL_BROWSER_PHASE_OK '+mode);
 }
 console.log('REPLAY_SLOPBALL_ONLINE_WEB_OK');
}catch(error){for(const a of agents){if(a.browser.connected){const s=await a.page.evaluate(()=>({state:globalThis.slopballStatus,graphics:globalThis.bufferTrace})).catch(()=>null);if(s?.state)events.push({who:a.label,event:'failure-state',...safe(s.state),graphics:s.graphics});}}throw error;}
finally{fs.writeFileSync(out+'/events.json',JSON.stringify(events,null,2));fs.writeFileSync(out+'/relay.json',JSON.stringify(relayObservations,null,2));await Promise.allSettled(agents.filter(a=>a.browser.connected).map(a=>a.browser.close()));}
process.exit(0);
