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
 if(role.startsWith('return'))url.searchParams.set('contention_hold','1');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1&&s.profile_ready===1,'menu');return a;
}
async function send(a,kind,value,extra={}){const id=++sequence;await a.page.evaluate(x=>{globalThis.onlineCommand=x},{id,kind,value,...extra});await until(a,s=>s.command===id,kind);}
try{
 let one=await open('source1','member-one'),two=await open('source2','member-two');
 await send(one,'name','Contender 1');await send(one,'press','Host');const created=await until(one,s=>s.ready&&s.invited===1,'created');
 await send(two,'name','Contender 2');await send(two,'invite',created.invite);await send(two,'press','Join');
 for(const a of [one,two])await until(a,s=>s.players===2&&s.name1==='Contender 1'&&s.name2==='Contender 2','joined');
 await send(one,'press','Ready');await send(two,'press','Ready');await until(one,s=>s.readiness===3,'ready');await send(one,'press','Start');await until(one,s=>s.phase===1,'playing');
 await send(one,'save');const saved=await until(one,s=>s.save_completed===1,'saved');assert.equal(saved.save_error,0);
 await Promise.all([one.browser.close(),two.browser.close()]);fs.writeFileSync(work+'/source-stopped','done');
 const deadline=Date.now()+45000;while(!fs.existsSync(work+'/service-restarted')){if(Date.now()>deadline)throw Error('service restart timeout');await pause(60)}
 one=await open('return1','member-one');two=await open('return2','member-two');
 await Promise.all([send(one,'press','Rejoin'),send(two,'press','Rejoin')]);
 for(const a of [one,two]){const s=await until(a,s=>s.restore_held,'prepared');assert.equal(s.ready,false);assert.equal(s.restore_candidate_tick,saved.save_tick)}
 await Promise.all([send(one,'pause_control',false),send(two,'pause_control',false)]);
 const states=await Promise.all([until(one,s=>s.ready&&s.steady&&s.players===2,'settled'),until(two,s=>s.ready&&s.steady&&s.players===2,'settled')]);
 assert.equal(states[0].epoch,2);assert.equal(states[1].epoch,2);assert.equal(states[0].authority+states[1].authority,1);
 const winner=states[0].authority?one:two,loser=states[0].authority?two:one;
 const ws=states[0].authority?states[0]:states[1],ls=states[0].authority?states[1]:states[0];assert.equal(ws.restore_publication,1);assert.equal(ls.restore_publication,0);
 await send(loser,'walk',null,{x:300,y:180});await until(loser,s=>s.near,'follower-at-chest');await send(loser,'loot',0);
 await until(winner,s=>s.host_gems+s.gems===3,'follower-action');await send(winner,'save');const final=await until(winner,s=>s.save_completed===1&&s.save_revision===2,'republished');
 assert.equal(final.save_epoch,2);assert.equal(final.save_error,0);
 await winner.page.screenshot({path:logs+'/winner.png'});
 console.log(`REPLAY_RESTORE_CONTENTION_BROWSER_OK winner=${winner.role} epoch=2 publication=2 gems=3 both_prepared=true follower_continued=true`);
}finally{fs.writeFileSync(logs+'/events.json',JSON.stringify(events,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close()}
process.exit(0);
