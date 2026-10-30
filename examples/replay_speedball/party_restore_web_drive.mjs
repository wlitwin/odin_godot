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
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',players:'1',goals:'1',latency:'0'});
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
 let host=await open('source','owner-profile');await send(host,'name','Saved Captain');await send(host,'press',paths.host);
 const issued=await until(host,s=>s.ready&&s.steady===1&&s.invited===1&&s.profile_saved===1,'created'),invite=issued.invite;
 const profileHash=issued.profile_hash;assert.match(invite,/^RP1\./);
 await send(host,'press',paths.start);await send(host,'bot','striker');await until(host,s=>s.winner>0,'first-match-won',60000);await send(host,'bot','idle');
 const request=await send(host,'save');assert.equal(request.result,true);
 const saved=await until(host,s=>s.party_save_completed>0,'party-saved');assert.equal(saved.party_save_error,0);assert.equal(saved.round,1);assert.equal(saved.left+saved.right,1);
 await host.browser.close();fs.writeFileSync(logs+'/source-stopped','done');
 const deadline=Date.now()+45000;while(!fs.existsSync(logs+'/service-restarted')){if(Date.now()>deadline)throw Error('service restart timeout');await pause(60)}
 host=await open('restored','owner-profile');await send(host,'name','Saved Captain');await send(host,'press',paths.rejoin);
 const restored=await until(host,s=>s.ready&&s.steady===1&&s.epoch===2&&s.party_restore_publication===1,'restored');
 assert.equal(restored.party_restore_error,0);assert.equal(restored.party_restore_tick,saved.party_save_tick);assert.ok(restored.incarnation>saved.incarnation);
 for(const key of ['round','left','right','winner','kicks'])assert.equal(restored[key],saved[key],`restored ${key}`);
 assert.equal(restored.profile_hash,profileHash);assert.equal(restored.seat,1);assert.equal(restored.separate,1);
 const guest=await open('guest','guest-profile');await send(guest,'name','New Striker');await send(guest,'invite',invite);await send(guest,'press',paths.join);
 const joined=await until(guest,s=>s.ready&&s.named&&s.epoch===2,'joined-restored-match');assert.equal(joined.round,1);assert.ok(joined.winner>0);assert.equal(joined.seat,2);
 const denied=await send(guest,'save');assert.equal(denied.result,false);await rtc(guest,'rtc-after-restore');
 await until(host,s=>s.players===2&&s.named,'new-guest-visible');await send(host,'press','UI/Again');
 await until(guest,s=>s.round===2&&s.started===1,'round-two');await send(guest,'chat','restored match restarted');await send(host,'bot','striker');
 await until(host,s=>s.round===2&&s.winner>0&&s.chat.includes('New Striker: restored match restarted'),'second-match-won',60000);await send(host,'bot','idle');
 const next=await send(host,'save');assert.equal(next.result,true);
 const final=await until(host,s=>s.party_save_completed>0&&s.party_save_revision>=2&&s.party_save_epoch===2,'republished');assert.equal(final.party_save_error,0);
 assert.equal(final.party_layout_clear,true,`party save/recovery controls overlap: ${JSON.stringify(final.party_layout_conflicts)}`);
 await host.page.screenshot({path:logs+'/restored-round-two.png'});
 console.log(`REPLAY_SPEEDBALL_PARTY_RESTORE_BROWSER_OK saved_tick=${saved.party_save_tick} restored_tick=${restored.party_restore_tick} epoch=2 incarnation=${restored.incarnation} round=2 revision=${final.party_save_revision} left=${final.left} right=${final.right} kicks=${final.kicks} new_guest=true profile_preserved=true`);
}finally{fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();}
process.exit(0);
