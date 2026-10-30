import puppeteer from 'puppeteer-core';import fs from 'node:fs';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {installFaults} from './faults.mjs';
const [base,control,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});const peers=[],events=[],telemetry=[];let command=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
function rss(pid){const rows=execFileSync('ps',['-axo','pid,ppid,rss'],{encoding:'utf8'}).trim().split('\n').slice(1).map(x=>x.trim().split(/\s+/).map(Number));const ids=new Set([pid]);for(let changed=true;changed;){changed=false;for(const [id,parent]of rows)if(ids.has(parent)&&!ids.has(id)){ids.add(id);changed=true;}}return rows.filter(r=>ids.has(r[0])).reduce((sum,r)=>sum+r[2],0);}
async function state(p){const id=++command;await p.page.evaluate(id=>globalThis.stressQuery=id,id);await p.page.waitForFunction(id=>globalThis.stressState?.query===id,{timeout:10000},id);return p.page.evaluate(()=>globalThis.stressState);}
async function send(p,kind){const id=++command;await p.page.evaluate(c=>globalThis.stressCommand=c,{id,kind});await p.page.waitForFunction(id=>globalThis.stressAck===id,{timeout:10000},id);}
async function until(fn,label,timeout=30000){const end=Date.now()+timeout;while(Date.now()<end){for(const p of peers)assert.deepEqual(p.errors,[],p.errors.join('\n'));if(await fn())return;await pause(80);}throw new Error('Timeout '+label);}
async function open(member){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:30000,args:['--no-sandbox',...(process.env.REPLAY_STRESS_SOFTWARE==='1'?['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader']:[]),'--disable-features=WebRtcHideLocalIpsWithMdns','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});
 const p={browser,page,member,role:member===1?'host':'client',errors:[]};peers.push(p);
 if(process.env.REPLAY_STRESS_PROFILE==='1'){p.profiler=await page.createCDPSession();await p.profiler.send('Profiler.enable');await p.profiler.send('Profiler.start');}
 page.on('console',message=>{const text=message.text();fs.appendFileSync(`${out}/${p.role}.log`,text+'\n');if(/JAM_WORKLOAD_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(text))p.errors.push(text);});page.on('pageerror',e=>p.errors.push(String(e)));
 await page.evaluateOnNewDocument(installFaults,{seed:Number(process.env.REPLAY_STRESS_SEED||901)+member,delay:40,jitter:10,loss:500,duplicate:500,queueBytes:65536,queuePackets:128});
 const url=new URL(base);url.search=new URLSearchParams({member:String(member),incarnation:String(100+member),coord_key:(member+20).toString(16).padStart(2,'0')+'00'.repeat(31),coord_url:control,token:`browser-room-${member}`,name:p.role,role:p.role,persist:'0',dev:'1',run:'1',waves:'1',wave_base:'0',wave_growth:'0',barrels:'0',mobs:'0',audio:'0',snapshot_every:'3'});
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>globalThis.stressReceipts&&globalThis.stressBarriers,{timeout:90000});
 const renderer=await page.evaluate(()=>{const canvas=document.createElement('canvas'),gl=canvas.getContext('webgl2'),e=gl?.getExtension('WEBGL_debug_renderer_info');return gl?(e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)):'unavailable';});
 fs.writeFileSync(`${out}/renderer-${p.role}.json`,JSON.stringify({renderer,software_requested:process.env.REPLAY_STRESS_SOFTWARE==='1'}));return p;
}
try{
 await open(1);await open(2);fs.writeFileSync(`${out}/rss.csv`,'role,measuring,rss_kib\n');
 let faultsEnabled=false;const deadline=Date.now()+180000;
 while(Date.now()<deadline){
  for(const p of peers)assert.deepEqual(p.errors,[],p.errors.join('\n'));
  const info=await Promise.all(peers.map(p=>p.page.evaluate(()=>({keys:Object.keys(globalThis.stressReceipts||{}),exit:globalThis.stressExit??null,fault:globalThis.stressFault}))));
  for(const data of info)assert.deepEqual(data.fault.errors,[]);
  const barriers={};for(const key of info[0].keys)if(key.endsWith('-host')&&info[1].keys.includes(key.slice(0,-5)+'-client'))barriers[key.slice(0,-5)]=true;
  if(barriers.populated&&!faultsEnabled){await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.stressFault.enabled=true)));faultsEnabled=true;events.push({event:'faults-enabled'});}
  await Promise.all(peers.map(p=>p.page.evaluate(b=>Object.assign(globalThis.stressBarriers,b),barriers)));
  for(let i=0;i<peers.length;i++){
   const p=peers[i],measuring=info[i].keys.includes('measuring-'+p.role)&&!info[i].keys.includes('sampled-'+p.role);
   fs.appendFileSync(`${out}/rss.csv`,`${p.role},${measuring?1:0},${rss(p.browser.process().pid)}\n`);
   if(info[i].keys.includes('populated-'+p.role)){
    const value=await state(p);telemetry.push({role:p.role,...value});assert.ok(value.credit_r<=16&&value.credit_u<=16);assert.ok(value.assembly_bytes<=value.assembly_limit);assert.equal(value.rtc_failed,0);
   }
  }
  if(info.every(p=>p.exit!==null)){assert.ok(info.every(p=>p.exit===0));break;}
  await pause(100);
 }
 assert.ok(Date.now()<deadline,'workload completion');
 for(const p of peers){const receipts=await p.page.evaluate(()=>globalThis.stressReceipts);for(const [name,value]of Object.entries(receipts))fs.writeFileSync(`${out}/${name}.json`,JSON.stringify(value,null,2));}
 const initial=await Promise.all(peers.map(state));assert.ok(initial[0].shuffled_snapshots>0&&initial[1].shuffled_snapshots>0,'shuffled snapshots crossed RTC');
 assert.ok(initial[1].action_copy_batches>0);assert.ok(initial.every(x=>x.resyncs===0));
 await Promise.all(peers.map(p=>send(p,'resume')));
 const before=await state(peers[0]);const fenceBefore=await peers[0].page.evaluate(()=>stressFault.fences);
 await peers[0].page.evaluate(()=>stressFault.blockUntil=performance.now()+400);await send(peers[1],'dash');
 await until(async()=>{const rows=await Promise.all(peers.map(state));return rows.every(x=>x.dashes===before.dashes+1&&x.ready===1)&&rows[1].dash_pending===0;},'post-blackout action',5000);
 await send(peers[1],'stop');await Promise.all(peers.map(p=>send(p,'hashes')));
 let common=[],hashes=[];
 await until(async()=>{hashes=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.stressHashes)));common=Object.keys(hashes[0]).filter(k=>hashes.every(h=>k in h));for(const k of common)assert.ok(hashes.every(h=>h[k]===hashes[0][k]),'world '+k);return common.length>=10;},'common resumed worlds',15000);
 await until(async()=>{const rows=await Promise.all(peers.map(state));return rows[0].backup_tick>initial[0].backup_tick&&rows[1].backup_tick>=rows[0].backup_tick;},'checkpoint continuation',15000);
 const final=await Promise.all(peers.map(state)),faults=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.stressFault)));
 assert.ok(faults[0].blackout>0&&faults[0].fences>fenceBefore,'credit fence after blackout');
 for(const f of faults){assert.ok(f.loss>0&&f.duplicate>0);assert.equal(f.capacity,0);assert.ok(f.maxQueuedBytes<=65536&&f.maxQueuedPackets<=128);assert.deepEqual(f.errors,[]);}
 assert.ok(final.every(x=>x.resyncs===0&&x.rtc_failed===0));
 fs.writeFileSync(`${out}/recovery.json`,JSON.stringify({initial,before,final,faults,fenceBefore,common,hashes},null,2));
 await peers[1].page.screenshot({path:`${out}/client.png`});console.log('REPLAY_BROWSER_STRESS_RUNTIME_OK shuffled=true actions=true credit_recovery=true common='+common.length);
}finally{
 await Promise.allSettled(peers.map(async p=>{
  if(!p.browser.connected)return;
  if(p.profiler){const result=await p.profiler.send('Profiler.stop');fs.writeFileSync(`${out}/cpu-${p.role}.json`,JSON.stringify(result.profile));}
  const capture=await p.page.evaluate(()=>({receipts:globalThis.stressReceipts||{},fault:globalThis.stressFault,state:globalThis.stressState}));
  for(const [name,value]of Object.entries(capture.receipts))fs.writeFileSync(`${out}/${name}.json`,JSON.stringify(value,null,2));
  fs.writeFileSync(`${out}/terminal-${p.role}.json`,JSON.stringify({fault:capture.fault,state:capture.state},null,2));
 }));
 fs.writeFileSync(`${out}/events.json`,JSON.stringify(events,null,2));fs.writeFileSync(`${out}/telemetry.json`,JSON.stringify(telemetry,null,2));
 await Promise.allSettled(peers.map(p=>p.browser.close()));
}

process.exit(0);
