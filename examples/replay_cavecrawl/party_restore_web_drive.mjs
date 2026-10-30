import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,service,work]=process.argv.slice(2),logs=work+'/browser';fs.mkdirSync(logs,{recursive:true});
const agents=[],events=[];let sequence=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function until(a,test,label){
 const end=Date.now()+45000;let state;
 while(Date.now()<end){
  assert.deepEqual(a.errors,[]);state=await a.page.evaluate(()=>globalThis.onlineStatus||null);
  if(state){assert.equal(state.failed,0,`${a.role}: ${state.notice}`);assert.equal(state.restore_error,0,`${a.role}: ${state.notice}`);
   if(test(state)){const safe={...state};delete safe.invite;events.push({role:a.role,event:label,...safe});return state;}}
  await pause(60);
 }
 if(state)delete state.invite;throw Error(`${a.role} ${label} timeout ${JSON.stringify(state)}`);
}
async function open(role,profile){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:logs+'/'+profile,headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage(),a={role,browser,page,errors:[]};agents.push(a);await page.setViewport({width:1200,height:900,deviceScaleFactor:1});
 page.on('console',m=>{const s=m.text();fs.appendFileSync(`${logs}/${role}.log`,s+'\n');if(/REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:/.test(s))a.errors.push(s)});page.on('pageerror',e=>a.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'0'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1&&s.profile_ready===1,'menu');return a;
}
async function send(a,kind,value,extra={}){const id=++sequence;await a.page.evaluate(x=>{globalThis.onlineCommand=x},{id,kind,value,...extra});await until(a,s=>s.command===id,kind);}
try{
 let host=await open('source','owner-profile');await send(host,'name','Saved Scout');await send(host,'press','Host');
 const created=await until(host,s=>s.ready&&s.invited===1,'created'),invite=created.invite;assert.match(invite,/^RP1\./);
 await send(host,'press','Ready');await until(host,s=>s.readiness===1,'ready');await send(host,'press','Start');await until(host,s=>s.phase===1,'playing');
 await send(host,'walk',null,{x:300,y:180});await until(host,s=>s.near,'chest');await send(host,'loot',0);await until(host,s=>s.host_gems===3,'looted');
 await send(host,'save');const saved=await until(host,s=>s.save_completed>0&&s.save_epoch===1,'saved');
 assert.equal(saved.save_error,0);await host.browser.close();
 fs.writeFileSync(work+'/saved.json',JSON.stringify({tick:saved.save_tick,revision:saved.save_revision,incarnation:saved.incarnation}));
 fs.writeFileSync(work+'/source-stopped','done');
 const deadline=Date.now()+45000;while(!fs.existsSync(work+'/service-restarted')){if(Date.now()>deadline)throw Error('service restart timeout');await pause(60)}
 host=await open('restored','owner-profile');await send(host,'name','Saved Scout');await send(host,'press','Rejoin');
 const restored=await until(host,s=>s.ready&&s.steady&&s.epoch===2&&s.restore_publication===1,'restored');
 assert.equal(restored.restore_tick,saved.save_tick);assert.ok(restored.incarnation>saved.incarnation);assert.equal(restored.host_gems,3);assert.equal(restored.phase,1);
 const guest=await open('guest','guest-profile');await send(guest,'name','New Scout');await send(guest,'invite',invite);await send(guest,'press','Join');
 await until(guest,s=>s.ready&&s.players===2&&s.epoch===2&&s.host_gems===3,'joined-restored-game');
 await send(guest,'walk',null,{x:300,y:180});await until(guest,s=>s.near,'guest-chest');await send(guest,'loot',1);
 await until(host,s=>s.guest_torches>0&&s.host_gems===3,'new-action');
 await send(host,'save');const final=await until(host,s=>s.save_completed>0&&s.save_epoch===2&&s.save_revision>saved.save_revision,'saved-again');assert.equal(final.save_error,0);
 await host.page.screenshot({path:logs+'/restored-game.png'});
 console.log(`REPLAY_CAVE_PARTY_RESTORE_BROWSER_OK source_tick=${saved.save_tick} restored_tick=${restored.restore_tick} epoch=2 incarnation=${restored.incarnation} gems=3 torches=${final.guest_torches} revision=${final.save_revision} new_guest=true`);
}finally{
 fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();
}
process.exit(0);
