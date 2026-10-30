import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {relayConfig,installRelayProbe,relayPairs,requireRelay} from './probe.mjs';
const [base,service,logs]=process.argv.slice(2),ice=relayConfig();fs.mkdirSync(logs,{recursive:true});const agents=[],events=[],pairs=[];let sequence=0,restarted;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function state(a){return a.page.evaluate(()=>globalThis.onlineStatus||null);}
async function until(a,test,label,timeout=30000){const deadline=Date.now()+timeout;let value;while(Date.now()<deadline){assert.deepEqual(a.errors,[]);value=await state(a);if(value){assert.equal(value.failed,0,value.notice);if(test(value)){const safe={...value};delete safe.invite;events.push({role:a.role,event:label,...safe});return value;}}await pause(100);}if(value)delete value.invite;throw Error(`${a.role} ${label}: ${JSON.stringify(value)}`);}
async function send(a,kind,value,extra={}){const id=++sequence;await a.page.evaluate(q=>{globalThis.onlineCommand=q;},{id,kind,value,...extra});return until(a,s=>s.command===id,kind);}
async function open(role){const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});const page=await browser.newPage(),a={browser,page,role,errors:[]};agents.push(a);await installRelayProbe(page,ice);page.on('console',m=>{const text=m.text();fs.appendFileSync(logs+'/'+role+'.log',text+'\n');if(/SCRIPT ERROR/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(String(e)));const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'0'});await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1&&s.profile_ready===1,'menu');return a;}
async function stopRelay(pid){process.kill(pid,'SIGTERM');const deadline=Date.now()+5000;while(Date.now()<deadline){try{process.kill(pid,0);}catch{return;}await pause(50);}throw Error('relay did not exit');}
async function startRelay(){const log=fs.openSync(logs+'/relay-restarted.log','w');restarted=spawn(process.env.REPLAY_TURN_EXECUTABLE,['-c',process.env.REPLAY_TURN_CONFIG],{cwd:process.env.REPLAY_TURN_WORK,stdio:['ignore',log,log]});fs.closeSync(log);const deadline=Date.now()+8000;while(Date.now()<deadline){assert.equal(restarted.exitCode,null,'restarted relay exited');const text=fs.readFileSync(logs+'/relay-restarted.log','utf8');if(/Total auth threads/.test(text))return;await pause(100);}throw Error('relay restart not ready');}
try{
 const host=await open('host');await send(host,'press','Host');const issued=await until(host,s=>s.invited===1&&s.ready,'created');
 const guest=await open('guest');await send(guest,'invite',issued.invite);await send(guest,'press','Join');
 await until(host,s=>s.ready&&s.players===2,'joined');await until(guest,s=>s.ready&&s.players===2,'joined');
 await send(host,'press','Ready');await send(guest,'press','Ready');await until(host,s=>s.readiness===3,'all-ready');await send(host,'press','Start');await until(guest,s=>s.phase===1,'playing');
 await send(guest,'walk',null,{x:300,y:180});await until(guest,s=>s.near,'at-chest');await send(guest,'loot',0);await until(host,s=>s.gems===3,'loot-confirmed');
 await send(guest,'walk',null,{x:120,y:330});await until(guest,s=>s.safe,'safe-position');await pause(500);
 await requireRelay(host.page,pairs,'before-host');await requireRelay(guest.page,pairs,'before-guest');
 const hostIdentity=(await state(host)).incarnation,guestBefore=await state(guest),guestIdentity=guestBefore.incarnation;
 const downtime=Number(process.env.REPLAY_TURN_DOWNTIME_MS||5000);assert.ok(downtime>=1000&&downtime<=30000);
 const faultAt=Date.now();await stopRelay(Number(process.env.REPLAY_TURN_PID));events.push({event:'relay-stopped'});await pause(downtime);
 const during=await state(host);assert.equal(during.epoch,1);assert.equal(during.gems,3);
 await startRelay();const restartedAt=Date.now();events.push({event:'relay-restarted',down_ms:restartedAt-faultAt});
 await until(guest,s=>s.ready&&s.steady&&s.players===2&&s.epoch===1&&s.gems===3,'state-visible',60000);
 // State can be stale while ICE detects failure: require traffic on a newly
 // constructed selected relay pair, then a newly confirmed gameplay action.
 const deadline=Date.now()+60000;let after=[];
 const beforeIndex=pairs.find(x=>x.label==='before-guest').rows[0].index;
 while(Date.now()<deadline){after=await relayPairs(guest.page);if(after.some(r=>r.index>beforeIndex&&r.bytesReceived>0&&r.bytesSent>0))break;await pause(200);}
 assert.ok(after.some(r=>r.index>beforeIndex),'no new relay connection after outage');
 await until(guest,s=>s.ready&&s.steady&&s.players===2&&s.epoch===1&&s.gems===3,'new-connection-ready',30000);
 await send(guest,'walk',null,{x:300,y:180});await until(guest,s=>s.near,'returned-to-chest');await send(guest,'loot',1);await until(host,s=>s.guest_torches>0,'new-action-confirmed');
 assert.equal((await state(host)).incarnation,hostIdentity);assert.equal((await state(guest)).incarnation,guestIdentity);
 assert.equal((await state(guest)).rtc_id,guestBefore.rtc_id);assert.ok((await state(guest)).rtc_resumes>=1);
 await requireRelay(host.page,pairs,'after-host');await requireRelay(guest.page,pairs,'after-guest');
 events.push({event:'complete',fault_to_action_ms:Date.now()-faultAt,restart_to_action_ms:Date.now()-restartedAt,signals:await guest.page.evaluate(()=>globalThis.replayTestSignals||[])});
 console.log('REPLAY_TURN_OUTAGE_OK same_processes=true same_epoch=true identities_preserved=true loot_preserved=true new_action=true');
}finally{
 fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));fs.writeFileSync(logs+'/relay.json',JSON.stringify(pairs,null,2));
 for(const a of agents)if(a.browser.connected)await a.browser.close();
 if(restarted&&restarted.exitCode===null&&restarted.signalCode===null){const exited=new Promise(r=>restarted.once('exit',r));restarted.kill('SIGTERM');await exited;}
}
process.exit(0);
