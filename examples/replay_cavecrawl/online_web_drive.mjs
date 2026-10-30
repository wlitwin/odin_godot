import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {relayConfig,installRelayProbe,requireRelay,relayPairs} from '../../tests/replay_turn/probe.mjs';
const [base,service,logs]=process.argv.slice(2);fs.mkdirSync(logs,{recursive:true});const agents=[];const events=[];let command=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const ice=relayConfig(),relayObservations=[];
const checkpoints=process.env.CAVE_ONLINE_CHECKPOINTS==='1';
async function open(role,profile){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:logs+'/'+profile,headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage(),agent={role,browser,page,errors:[]};await page.setViewport({width:1200,height:900,deviceScaleFactor:1});agents.push(agent);
 await installRelayProbe(page,ice);
 page.on('console',m=>{const s=m.text();fs.appendFileSync(`${logs}/${role}.log`,s+'\n');if(/REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:/.test(s))agent.errors.push(s);});page.on('pageerror',e=>agent.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'0'});
 if(process.env.REPLAY_TURN_PROVIDER==='1')url.searchParams.set('room_relay','1');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(agent,s=>s.recent===1&&s.profile_ready===1,'menu');return agent;
}
async function until(a,test,label){
 const end=Date.now()+40000;let latest;
 while(Date.now()<end){assert.deepEqual(a.errors,[]);latest=await a.page.evaluate(()=>globalThis.onlineStatus||null);if(latest){assert.equal(latest.failed,0,`${a.role}: ${latest.notice}`);if(test(latest)){const safe={...latest};delete safe.invite;events.push({role:a.role,event:label,...safe});return latest;}}await pause(60);}
 if(latest)delete latest.invite;throw Error(`${a.role} ${label} timeout ${JSON.stringify(latest)}`);
}
async function send(a,kind,value,extra={}){const id=++command;await a.page.evaluate(x=>{globalThis.onlineCommand=x;},{id,kind,value,...extra});await until(a,s=>s.command===id,kind);}
try{
 let host=await open('host','host-profile');await send(host,'name','Host Scout');await send(host,'press','Host');
 const issued=await until(host,s=>s.invited===1&&s.ready,'created');assert.match(issued.invite,/^RP1\./);const invite=issued.invite;
 await send(host,'invite','Party invite hidden in this test screenshot');await host.page.screenshot({path:logs+'/created-party.png'});await send(host,'invite',invite);
 const guest=await open('guest','guest-profile');await send(guest,'name','Guest Scout');await send(guest,'invite',invite);await send(guest,'press','Join');
 await until(host,s=>s.players===2&&s.name1==='Host Scout'&&s.name2==='Guest Scout','joined');await until(guest,s=>s.players===2&&s.name1==='Host Scout'&&s.name2==='Guest Scout','joined');
 await requireRelay(host.page,relayObservations,'host-joined');await requireRelay(guest.page,relayObservations,'guest-joined');
 let originalCredentialExpires=0;
 if(process.env.REPLAY_TURN_PROVIDER==='1'){
  originalCredentialExpires=Math.max(...(await relayPairs(host.page)).map(r=>r.credentialExpires));assert.ok(originalCredentialExpires>0);
  await until(host,s=>s.relay_revision>=2,'relay-refreshed');await until(guest,s=>s.relay_revision>=2,'relay-refreshed');
  while(Date.now()/1000<=originalCredentialExpires+1)await pause(100);
 }
 const other=await open('other','other-profile');await send(other,'name','Other Scout');await send(other,'press','Host');
 const isolated=await until(other,s=>s.ready&&s.players===1&&s.name1==='Other Scout'&&s.invited===1,'second-room');assert.notEqual(isolated.invite,invite);
 await until(host,s=>s.players===2&&s.name1==='Host Scout'&&s.name2==='Guest Scout','rooms-isolated');await other.browser.close();
 await send(host,'press','Ready');await send(guest,'press','Ready');await until(host,s=>s.readiness===3,'all-ready');await send(host,'press','Start');
 await until(guest,s=>s.phase===1,'playing');await send(guest,'walk',null,{x:300,y:180});await until(guest,s=>s.near,'at-chest');await send(guest,'loot',0);
 await until(host,s=>s.gems===3&&s.prepared>0,'loot-backed-up');
 let hostPublication=0;
 if(checkpoints){
  await send(host,'save');const saved=await until(host,s=>s.save_completed>0&&s.save_epoch===1,'host-checkpoint');
  assert.equal(saved.save_error,0);assert.equal(saved.save_uncertain,0);assert.ok(saved.save_tick>0);hostPublication=saved.save_revision;
 }
 await send(host,'handoff');
 const migrated=await until(guest,s=>s.epoch===2&&s.steady&&s.gems===3,'migrated');assert.equal(migrated.lost,0);
 await requireRelay(guest.page,relayObservations,'guest-migrated');
 if(originalCredentialExpires)assert.ok((await relayPairs(guest.page)).every(r=>r.credentialExpires>originalCredentialExpires),'migration reused expired relay credentials');
 await until(host,s=>s.epoch===2&&s.steady,'departed');await host.browser.close();
 host=await open('returned','host-profile');await send(host,'name','Host Scout');await send(host,'press','Rejoin');
 const returned=await until(host,s=>s.epoch===2&&s.steady&&s.players===2&&s.incarnation>=3,'rejoined');assert.equal(returned.invite,invite);
 await send(host,'walk',null,{x:300,y:180});await until(host,s=>s.near,'returned-at-chest');await send(host,'loot',1);
 await until(guest,s=>s.torches>0&&s.gems===3,'returned-action-confirmed');
 if(checkpoints){
  await send(guest,'save');const saved=await until(guest,s=>s.save_completed>0&&s.save_epoch===2&&s.save_revision>hostPublication,'successor-checkpoint');
  assert.equal(saved.save_error,0);assert.equal(saved.save_uncertain,0);assert.ok(saved.save_tick>0);
  console.log(`REPLAY_CAVE_BROWSER_CHECKPOINT_OK host_revision=${hostPublication} successor_revision=${saved.save_revision} epoch=2 tick=${saved.save_tick}`);
 }
 await requireRelay(host.page,relayObservations,'host-returned');await requireRelay(guest.page,relayObservations,'guest-after-return');
 await host.page.screenshot({path:logs+'/returned-party.png'});
 console.log('REPLAY_CAVE_ONLINE_BROWSER_OK menu_create_join=true rooms_isolated=true rtc_migration=true lost_ticks=0 durable_rejoin=true invite_stable=true');
}finally{fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));fs.writeFileSync(logs+'/relay.json',JSON.stringify(relayObservations,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();}
// Chromium has exited; do not retain incidental Puppeteer process handles.
process.exit(0);
