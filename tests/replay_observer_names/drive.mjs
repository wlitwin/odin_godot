import puppeteer from 'puppeteer-core';import fs from 'node:fs';import assert from 'node:assert/strict';
const [base,control,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});const peers=[],events=[];let serial=0;const mode=process.env.REPLAY_OBSERVER_MODE||"planned";assert.ok(["planned","crash"].includes(mode));
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function state(p){const id=++serial;await p.page.evaluate(id=>globalThis.observerQuery=id,id);await p.page.waitForFunction(id=>globalThis.observerState?.query===id,{timeout:10000},id);return p.page.evaluate(()=>globalThis.observerState);}
async function until(p,predicate,label,timeout=30000){const end=Date.now()+timeout;while(Date.now()<end){for(const peer of peers.filter(p=>!p.killed))assert.deepEqual(peer.errors,[]);const value=await state(p);if(predicate(value)){events.push({label,member:p.member,state:value});return value;}await pause(80);}throw new Error('Timeout '+label);}
async function command(p,kind,text=''){const id=++serial;await p.page.evaluate(c=>globalThis.observerCommand=c,{id,kind,text});await p.page.waitForFunction(id=>globalThis.observerAck?.id===id,{timeout:10000},id);return p.page.evaluate(()=>globalThis.observerAck.accepted);}
async function open(member,observer=false,returning=false){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--disable-background-timer-throttling','--disable-renderer-backgrounding']});const p={browser,member,page:null,errors:[],killed:false,returning};peers.push(p);const timer=setTimeout(()=>browser.process()?.kill('SIGKILL'),120000);
 try{const page=await browser.newPage();p.page=page;await page.setViewport({width:1280,height:704});page.on('console',m=>{const text=m.text();fs.appendFileSync(`${out}/member-${member}${returning?"-returned":""}.log`,text+'\n');if(/REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:|WebGL: INVALID_/.test(text))p.errors.push(text);});page.on('pageerror',e=>p.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({member:String(member),incarnation:String((returning?200:100)+member),coord_key:(member+20).toString(16).padStart(2,'0')+'00'.repeat(31),coord_url:control,token:'browser-room-'+member,name:observer?(returning?'Rhea':'Watcher Ω'):member===1?'host':'client',role:observer?'observer':member===1&&!returning?'host':'client',persist:'0',run:'0',mobs:'0',audio:'0'});
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>globalThis.observerState!==undefined,{timeout:60000});await until(p,s=>s.ready&&s.chat_ready,'admission');return p;
 }finally{clearTimeout(timer);}
}
try{
 const host=await open(1),client=await open(2);await command(client,'ready');await until(host,s=>s.ready2,'client ready');await command(host,'start');await until(client,s=>s.stage===1,'playing');
 await command(host,'say','before observer');await until(client,s=>s.history.includes('host: before observer'),'first history');
 const watcher=await open(3,true);const admitted=await until(watcher,s=>s.named_observer&&s.seat===0,'named observer');assert.equal(admitted.players,2);assert.match(admitted.status,/Observing/);assert.ok(!/Shift|mouse fire|hold F/.test(admitted.status));
 await until(watcher,s=>s.history.includes('host: before observer'),'late history');assert.equal(await command(watcher,'ping'),false);
 await command(watcher,'say','watching safely');for(const p of peers)await until(p,s=>s.history.includes('Watcher Ω (observer): watching safely')&&s.pending===0,'named message');
 await command(watcher,'rename','host');await pause(100);await command(watcher,'say','still an observer');for(const p of peers)await until(p,s=>s.history.includes('host (observer): still an observer'),'role label');
 if(mode==='crash'){host.killed=true;assert.ok(host.browser.process().kill('SIGKILL'));events.push({label:'host killed',member:1});}
 else assert.equal(await command(host,'handoff'),true);
 for(const p of peers.filter(p=>!p.killed))await until(p,s=>s.ready&&s.epoch===2&&s.chat_ready,'migrated',40000);
 let returnedHost=null;
 if(mode==='crash'){returnedHost=await open(1,false,true);await until(returnedHost,s=>s.ready&&s.epoch===2&&s.seat===1,'returned host');} 
 const promoted=await state(client);assert.equal(promoted.authority,1);assert.equal(promoted.restored_exact,1);
 await until(watcher,s=>s.named_observer&&s.seat===0,'renegotiated');await command(watcher,'say','after migration');for(const p of peers.filter(p=>!p.killed))await until(p,s=>s.history.includes('host (observer): after migration')&&s.pending===0,'continued observer');
 let returnedObserver=null;
 if(mode==='crash'){
  watcher.killed=true;assert.ok(watcher.browser.process().kill('SIGKILL'));events.push({label:'observer killed',member:3});
  returnedObserver=await open(3,true,true);await until(returnedObserver,s=>s.named_observer&&s.epoch===2&&s.seat===0,'returned observer');
  assert.equal(await command(returnedObserver,'ping'),false);await command(returnedObserver,'say','fresh observer');
  for(const p of peers.filter(p=>!p.killed))await until(p,s=>s.history.includes('Rhea (observer): fresh observer')&&s.pending===0,'fresh observer message');
 }
 const live=peers.filter(p=>!p.killed).sort((a,b)=>a.member-b.member);
 const final=await Promise.all(live.map(state));assert.ok(final.every(s=>s.players===2));assert.equal(final.filter(s=>s.authority).length,1);
 for(const s of final){for(const line of ['Watcher Ω (observer): watching safely','host (observer): still an observer','host (observer): after migration'])assert.equal(s.history.split(line).length-1,1);}
 await (returnedObserver||watcher).page.screenshot({path:`${out}/observer.png`});fs.writeFileSync(`${out}/result.json`,JSON.stringify({mode,promoted,final,returned_host:!!returnedHost,returned_observer:!!returnedObserver},null,2));console.log('REPLAY_OBSERVER_NAMES_OK');
}finally{fs.writeFileSync(`${out}/events.json`,JSON.stringify(events,null,2));await Promise.allSettled(peers.map(p=>{if(p.killed){p.browser.disconnect();return;}return p.browser.close();}));}
