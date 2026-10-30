import puppeteer from '../../tests/web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,service,logs]=process.argv.slice(2);
fs.mkdirSync(logs,{recursive:true});
const agents=[],events=[];let command=0;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const paths={host:'UI/Lobby/Column/Buttons/Host',join:'UI/Lobby/Column/Buttons/Join',rejoin:'UI/Lobby/Column/Party/Choices/Rejoin',start:'UI/Lobby/Column/Start',leave:'UI/Leave'};
function safe(state){const result={...state};delete result.invite;return result;}
async function open(role,profile){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:logs+'/'+profile,headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage(),a={role,browser,page,errors:[]};agents.push(a);await page.setViewport({width:1280,height:720,deviceScaleFactor:1});
 await page.evaluateOnNewDocument(()=>{
  const Native=globalThis.RTCPeerConnection;globalThis.speedballRtc=[];
  globalThis.RTCPeerConnection=class extends Native{constructor(...args){super(...args);globalThis.speedballRtc.push(this);}};
 });
 page.on('console',message=>{const text=message.text();fs.appendFileSync(`${logs}/${role}.log`,text+'\n');if(/REPLAY_SPEEDBALL_FAIL|SCRIPT ERROR|ERROR:/.test(text))a.errors.push(text);});
 page.on('pageerror',error=>a.errors.push(String(error)));
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',players:'2',goals:'9',latency:'120'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.profile_ready===1&&s.recent===1,'menu');return a;
}
async function status(a){assert.deepEqual(a.errors,[]);const s=await a.page.evaluate(()=>globalThis.speedballStatus||null);if(s){assert.equal(s.profile_failed,0,`${a.role} profile failed`);assert.equal(s.failed,0,`${a.role} ${s.notice}`);}return s;}
async function until(a,predicate,label,timeout=45000){
 const end=Date.now()+timeout;let latest;
 while(Date.now()<end){latest=await status(a);if(latest&&predicate(latest)){events.push({role:a.role,event:label,...safe(latest)});return latest;}await pause(75);}
 throw Error(`${a.role} ${label} timeout: ${JSON.stringify(latest?safe(latest):null)}`);
}
async function send(a,kind,value){
 const id=++command;await a.page.evaluate(request=>{globalThis.speedballCommand=request;},{id,kind,value});
 // Ordinary command acknowledgments stay out of the event log (invites are secrets).
 const end=Date.now()+10000;
 while(Date.now()<end){const s=await status(a);if(s?.command===id)return s;await pause(30);}
 throw Error(`${a.role} command ${kind} timeout`);
}
async function rtc(a,label){
 const rows=await a.page.evaluate(async()=>{
  const rows=[];for(const peer of globalThis.speedballRtc||[]){if(peer.connectionState!=='connected')continue;const stats=await peer.getStats();for(const s of stats.values())if(s.type==='candidate-pair'&&s.nominated&&s.state==='succeeded')rows.push({sent:s.bytesSent,received:s.bytesReceived});}return rows;
 });
 assert.ok(rows.some(r=>r.sent>0&&r.received>0),`${a.role}: no real RTC traffic`);events.push({role:a.role,event:label,rtc:rows});
}
async function common(peers,after){
 for(let attempt=1;attempt<=128;attempt++){
  const head=await status(peers[0]);const tick=head.tick-30;if(tick<=after){await pause(100);continue;}
  // Every peer answers the same candidate before another is selected.
  const replies=await Promise.all(peers.map(a=>send(a,'hash',tick)));
  if(replies.every(s=>s.hash!=='-1')){
   for(const s of replies){assert.equal(s.hash_tick,tick);assert.equal(s.hash,replies[0].hash);}
   const result={tick,hash:replies[0].hash,attempts:attempt};events.push({event:'common-world',...result});return result;
  }
  await pause(80);
 }
 throw Error('No common retained snapshot');
}
try{
 for(const mode of (process.env.RSB_WEB_MODES||'planned crash').split(/\s+/)){
  assert.ok(['planned','crash'].includes(mode));let host=await open(`${mode}-host`,`${mode}-host-profile`);
  await send(host,'name','Captain');await host.page.screenshot({path:logs+`/${mode}-menu.png`});await send(host,'press',paths.host);
  const issued=await until(host,s=>s.ready&&s.steady===1&&s.invited===1&&s.profile_saved===1,'created');assert.match(issued.invite,/^RP1\./);
  const invite=issued.invite,profileHash=issued.profile_hash,firstIncarnation=issued.incarnation;
  const guest=await open(`${mode}-guest`,`${mode}-guest-profile`);await send(guest,'name','Striker');await send(guest,'invite','invalid');await send(guest,'press',paths.join);
  const invalid=await status(guest);assert.equal(invalid.ready,false);assert.match(invalid.notice,/complete party invite/);
  await send(guest,'invite',invite);await send(guest,'press',paths.join);await until(guest,s=>s.ready&&s.seat===2&&s.named,'guest-joined');
  const watcher=await open(`${mode}-watcher`,`${mode}-watcher-profile`);await send(watcher,'name','Spectator');await send(watcher,'watch',true);await send(watcher,'invite',invite);await send(watcher,'press',paths.join);
  await until(watcher,s=>s.ready&&s.steady===1&&s.observer===1&&s.seat===0&&s.backup===0,'observer-joined');
  for(const a of [host,guest,watcher]){await until(a,s=>s.players===2&&s.named&&s.separate===1,'party-ready');await rtc(a,'rtc-before');}
  await send(host,'press',paths.start);await send(host,'bot','striker');await until(watcher,s=>s.started===1,'watching');
  await watcher.page.screenshot({path:logs+`/${mode}-observer.png`});
  const backup=await until(guest,s=>s.moving_backup===1&&s.backup_committed===1,'moving-scored-backup',60000);
  await until(host,s=>s.moving===1&&s.sequence>=backup.sequence,'handoff-ready');
  if(mode==='planned'){const answer=await send(host,'handoff');assert.equal(answer.result,true);await until(host,s=>s.epoch===2&&s.steady===1,'former-host');await host.browser.close();}
  else await host.browser.close();
  const restored=await until(guest,s=>s.epoch===2&&s.authority===1&&s.steady===1&&s.exact===1&&s.restored_moving===1&&s.restored_score>0,'takeover');
  if(mode==='planned')assert.equal(restored.lost,0);
  await until(watcher,s=>s.epoch===2&&s.steady===1&&s.observer===1&&s.seat===0,'observer-migrated');
  await send(watcher,'press',paths.leave);await send(watcher,'press',paths.rejoin);
  await until(watcher,s=>s.epoch===2&&s.steady===1&&s.observer===1&&s.seat===0&&s.backup===0&&s.incarnation>=3,'observer-rejoined');
  host=await open(`${mode}-returned`,`${mode}-host-profile`);
  const loaded=await status(host);assert.equal(loaded.name,'Captain');assert.equal(loaded.profile_hash,profileHash);
  await send(host,'press',paths.rejoin);const returned=await until(host,s=>s.epoch===2&&s.steady===1&&s.seat===1&&s.incarnation>firstIncarnation&&s.invited===1,'returned');
  assert.ok(returned.invite===invite,"invite changed across rejoin");assert.equal(returned.profile_hash,profileHash);
  await send(guest,'bot','spiker');await until(guest,s=>s.spikes>=restored.restored_spikes+2,'new-spikes');await send(guest,'bot','idle');
  await send(watcher,'chat','after browser migration');
  for(const a of [guest,host,watcher])await until(a,s=>s.chat.includes('Observer: after browser migration')&&s.chat.includes('The pitch has a new host'),'new-chat');
  const after=(await status(guest)).tick,final=await common([guest,host,watcher],after);
  for(const a of [guest,host,watcher])await rtc(a,'rtc-after');
  await host.page.screenshot({path:logs+`/${mode}-returned.png`});
  fs.writeFileSync(`${logs}/${mode}-result.json`,JSON.stringify({mode,checkpoint:restored.checkpoint,known_lost_ticks:restored.lost,exact:true,moving:true,score:restored.restored_score,new_spikes:2,personal_identity_retained:true,name_retained:true,invite_stable:true,observer_rejoined:true,final},null,2));
  await Promise.all([guest,host,watcher].map(a=>send(a,'freeze')));await Promise.all([guest,host,watcher].map(a=>a.browser.close()));
  console.log(`REPLAY_SPEEDBALL_BROWSER_PHASE_OK ${mode}`);
 }
 console.log('REPLAY_SPEEDBALL_BROWSER_OK');
}finally{
 fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));
 await Promise.allSettled(agents.filter(a=>a.browser.connected).map(a=>a.browser.close()));
}
process.exit(0);
