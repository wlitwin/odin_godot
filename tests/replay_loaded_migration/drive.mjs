import {installSnapshotTrace} from './snapshot_trace.mjs';
import {installControlProbe,controlEvidence} from './control_probe.mjs';
import {installCreditTrace} from './credit_trace.mjs';
import {installReliableHold} from './reliable_hold.mjs';
import {relayConfig,installRelayProbe,requireRelay} from '../replay_turn/probe.mjs';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
import {installArchiveCapture} from './capture.mjs';
import puppeteer from 'puppeteer-core';import fs from 'node:fs';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {installFaults} from '../replay_browser_stress/faults.mjs';
const [base,control,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});const peers=[],events=[],telemetry=[];let command=0;const mode=process.env.REPLAY_LOADED_MODE||'planned';assert.ok(['planned','crash'].includes(mode));
const rawTurn=process.env.REPLAY_LOADED_RAW_TURN==='1',relayObservations=[];
assert.ok(!rawTurn||(process.env.REPLAY_ICE_CONFIG&&process.env.REPLAY_TURN_ENABLE_FILE&&process.env.REPLAY_RELIABLE_HOLD!=='1'));
const holdAtKill=process.env.REPLAY_RELIABLE_HOLD_AT_KILL==='1';
const holdMs=process.env.REPLAY_RELIABLE_HOLD==='1'?Number(process.env.REPLAY_RELIABLE_HOLD_MS||(holdAtKill?2000:200)):0;
assert.ok(!holdAtKill||(mode==='crash'&&holdMs>=1000));
assert.ok(Number.isInteger(holdMs)&&holdMs>=0&&holdMs<=2000);if(process.env.REPLAY_RELIABLE_HOLD==='1')assert.ok(holdMs>0);
fs.writeFileSync(`${out}/fault-plan.json`,JSON.stringify({transport_faults:rawTurn?'turn_udp':'messages',reliable_hold_ms:holdMs,hold_at_kill:holdAtKill,hold_before_kill_ms:holdAtKill?300:0}));
fs.writeFileSync(`${out}/timing.json`,JSON.stringify({node_time_origin:performance.timeOrigin}));
const pause=ms=>new Promise(r=>setTimeout(r,ms));
function rss(pid){const rows=execFileSync('ps',['-axo','pid,ppid,rss'],{encoding:'utf8'}).trim().split('\n').slice(1).map(x=>x.trim().split(/\s+/).map(Number));const ids=new Set([pid]);for(let changed=true;changed;){changed=false;for(const [id,parent]of rows)if(ids.has(parent)&&!ids.has(id)){ids.add(id);changed=true;}}return rows.filter(r=>ids.has(r[0])).reduce((sum,r)=>sum+r[2],0);}
async function state(p){const id=++command;await p.page.evaluate(id=>globalThis.stressQuery=id,id);await p.page.waitForFunction(id=>globalThis.stressState?.query===id,{timeout:10000},id);return p.page.evaluate(()=>globalThis.stressState);}
async function send(p,kind){const id=++command;await p.page.evaluate(c=>globalThis.stressCommand=c,{id,kind});await p.page.waitForFunction(id=>globalThis.stressAck===id,{timeout:10000},id);}
async function until(fn,label,timeout=30000){const end=Date.now()+timeout;while(Date.now()<end){for(const p of peers.filter(p=>!p.killed))assert.deepEqual(p.errors,[],p.errors.join('\n'));if(await fn())return;await pause(80);}throw new Error('Timeout '+label);}
async function open(member,returning=false){
 const first=peers.length;let timer;
 try{return await Promise.race([openPeer(member,returning),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Browser startup timeout member='+member)),120000);})]);}
 catch(error){
  fs.appendFileSync(`${out}/startup.log`,String(error)+'\n');
  for(const p of peers.slice(first)){p.killed=true;p.browser.process()?.kill('SIGKILL');p.browser.disconnect();}
  throw error;
 }finally{clearTimeout(timer);}
}
async function openPeer(member,returning=false){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:30000,args:['--no-sandbox',...(process.env.REPLAY_STRESS_SOFTWARE==='1'?['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader']:[]),'--disable-features=WebRtcHideLocalIpsWithMdns','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const p={browser,page:null,member,role:returning?'returned':member===1?'host':'client',errors:[],killed:false};peers.push(p);
 const page=await browser.newPage();p.page=page;await page.setViewport({width:1280,height:704});
 if(process.env.REPLAY_STRESS_PROFILE==='1'){p.profiler=await page.createCDPSession();await p.profiler.send('Profiler.enable');await p.profiler.send('Profiler.start');}
 page.on('console',message=>{const text=message.text();fs.appendFileSync(`${out}/${p.role}.log`,text+'\n');if(/JAM_WORKLOAD_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(text)||process.env.REPLAY_RENDER_TRACE==='1'&&text.includes('WebGL: INVALID_'))p.errors.push(text);});page.on('pageerror',e=>p.errors.push(String(e)));
 if(process.env.REPLAY_SNAPSHOT_APPLY_TRACE==='1')await page.evaluateOnNewDocument(()=>{globalThis.replaySnapshotApplyTrace={limit:8192,rows:[],overflow:0};});
 await installRelayProbe(page,relayConfig());
 await page.evaluateOnNewDocument(installControlProbe);
 if(rawTurn)await page.evaluateOnNewDocument(()=>{globalThis.stressFault={enabled:false,capacity:0,errors:[],maxQueuedBytes:0,maxQueuedPackets:0,loss:0,duplicate:0,config:{delay:0,jitter:0,loss:0,duplicate:0}};});
 else await page.evaluateOnNewDocument(installFaults,{seed:Number(process.env.REPLAY_STRESS_SEED||901)+member,delay:40,jitter:10,loss:500,duplicate:500,queueBytes:65536,queuePackets:128});
 if(process.env.REPLAY_SNAPSHOT_TRACE==='1')await page.evaluateOnNewDocument(installSnapshotTrace);
 if(process.env.REPLAY_RTC_CREDIT_TRACE==='1')await page.evaluateOnNewDocument(installCreditTrace);
 if(process.env.REPLAY_CAPTURE_ARCHIVES==='1')await page.evaluateOnNewDocument(installArchiveCapture);
 if(process.env.REPLAY_RENDER_TRACE==='1')await page.evaluateOnNewDocument(installBufferTrace);
 if(member===1&&process.env.REPLAY_RELIABLE_HOLD==='1')await page.evaluateOnNewDocument(installReliableHold,{milliseconds:holdMs,firstTick:1000,armed:!holdAtKill});
 const peerBase=process.env.REPLAY_LOADED_LEGACY_MEMBER===String(member)?process.env.REPLAY_LOADED_LEGACY_URL:base;assert.ok(peerBase);
 const url=new URL(peerBase);url.search=new URLSearchParams({member:String(member),incarnation:String((returning?200:100)+member),coord_key:(member+20).toString(16).padStart(2,'0')+'00'.repeat(31),coord_url:control,token:`browser-room-${member}`,name:p.role,role:p.role,persist:'0',dev:'1',run:'1',waves:'1',wave_base:'0',wave_growth:'0',barrels:'0',mobs:'0',audio:'0',snapshot_every:'3'});
 if(returning){url.searchParams.set('stress_return','1');url.searchParams.set('role','client');}
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>globalThis.stressReceipts&&globalThis.stressBarriers,{timeout:90000});
 const renderer=await page.evaluate(()=>{const canvas=document.createElement('canvas'),gl=canvas.getContext('webgl2'),e=gl?.getExtension('WEBGL_debug_renderer_info');return gl?(e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)):'unavailable';});
 fs.writeFileSync(`${out}/renderer-${p.role}.json`,JSON.stringify({renderer,software_requested:process.env.REPLAY_STRESS_SOFTWARE==='1'}));return p;
}
try{
 await open(1);await open(2);fs.writeFileSync(`${out}/rss.csv`,'role,measuring,rss_kib\n');
 let faultsEnabled=false;const deadline=Date.now()+180000;
 while(Date.now()<deadline){
  for(const p of peers.filter(p=>!p.killed))assert.deepEqual(p.errors,[],p.errors.join('\n'));
  const info=await Promise.all(peers.map(p=>p.page.evaluate(()=>({keys:Object.keys(globalThis.stressReceipts||{}),exit:globalThis.stressExit??null,fault:globalThis.stressFault}))));
  for(const data of info)assert.deepEqual(data.fault.errors,[]);
  const barriers={};for(const key of info[0].keys)if(key.endsWith('-host')&&info[1].keys.includes(key.slice(0,-5)+'-client'))barriers[key.slice(0,-5)]=true;
  if(barriers.populated&&!faultsEnabled){
   if(rawTurn){for(const p of peers)await requireRelay(p.page,relayObservations,p.role+'-populated');fs.writeFileSync(process.env.REPLAY_TURN_ENABLE_FILE,'enable\n');}
   else await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.stressFault.enabled=true)));
   faultsEnabled=true;events.push({event:'faults-enabled',transport:rawTurn?'turn_udp':'messages'});
  }
  await Promise.all(peers.map(p=>p.page.evaluate(b=>Object.assign(globalThis.stressBarriers,b),barriers)));
  for(let i=0;i<peers.length;i++){
   const p=peers[i],measuring=info[i].keys.includes('measuring-'+p.role)&&!info[i].keys.includes('sampled-'+p.role);
   fs.appendFileSync(`${out}/rss.csv`,`${p.role},${measuring?1:0},${rss(p.browser.process().pid)}\n`);
   if(info[i].keys.includes('populated-'+p.role)){
    const value=await state(p);telemetry.push({sampled_ms:performance.now(),role:p.role,...value});assert.ok(value.credit_r<=16&&value.credit_u<=16);assert.ok(value.assembly_bytes<=value.assembly_limit);assert.equal(value.rtc_failed,0);
   }
  }
  if(info.every(p=>p.exit!==null)){assert.ok(info.every(p=>p.exit===0));break;}
  await pause(100);
 }
 assert.ok(Date.now()<deadline,'workload completion');
 for(const p of peers){const receipts=await p.page.evaluate(()=>globalThis.stressReceipts);for(const [name,value]of Object.entries(receipts))fs.writeFileSync(`${out}/${name}.json`,JSON.stringify(value,null,2));}
 if(process.env.REPLAY_CAPTURE_ARCHIVES==='1')fs.writeFileSync(`${out}/archives-workload.json`,JSON.stringify(await peers[0].page.evaluate(()=>globalThis.stressArchives)));
 if(process.env.REPLAY_CAPTURE_SNAPSHOT_PAIR==='1'){
  await send(peers[0],'snapshot_capture');const pair=await peers[0].page.evaluate(()=>globalThis.replaySnapshotPair);assert.ok(pair?.base&&pair?.target&&pair?.meta);
  const meta=JSON.parse(pair.meta),baseBytes=Buffer.from(pair.base,'base64'),targetBytes=Buffer.from(pair.target,'base64');assert.equal(baseBytes.length,meta.bytes);assert.equal(targetBytes.length,meta.bytes);
  fs.writeFileSync(`${out}/snapshot-base.bin`,baseBytes);fs.writeFileSync(`${out}/snapshot-target.bin`,targetBytes);fs.writeFileSync(`${out}/snapshot-pair.json`,JSON.stringify(meta));
 }
 const initial=await Promise.all(peers.map(state));
 const privateHistory=initial.every(x=>x.public_excluded_fields>0);
 if(privateHistory){
  assert.ok(initial.every(x=>x.snapshot_shuffle_available===1&&x.deltasnaps>0&&x.public_snapshot_bytes>0));
  assert.equal(initial[0].public_snapshot_bytes,initial[1].public_snapshot_bytes);assert.ok(initial[0].public_snapshot_bytes*2<initial[0].raw_bytes,'public snapshot excludes rewind history');
 }else assert.ok(initial[0].shuffled_snapshots>0&&initial[1].shuffled_snapshots>0,'shuffled snapshots crossed RTC');
 fs.writeFileSync(`${out}/snapshot-contract.json`,JSON.stringify({private_history:privateHistory,initial}));
 assert.ok(initial[1].action_copy_batches>0);assert.ok(initial.every(x=>x.resyncs===0));
 await Promise.all(peers.map(p=>send(p,'resume')));const resumed=await Promise.all(peers.map(state));await Promise.all(peers.map(p=>send(p,'load')));
 await pause(5000);
 if(holdAtKill){
  const at=await state(peers[0]);assert.equal(await peers[0].page.evaluate(tick=>globalThis.reliableHoldArm(tick),at.head),true);
  const frontiers=[];
  await until(async()=>{
   const states=await Promise.all(peers.map(state));const hold=await peers[0].page.evaluate(()=>({active:globalThis.reliableHold.active,heldForMs:globalThis.reliableHold.startedAt===undefined?0:performance.now()-globalThis.reliableHold.startedAt}));
   frontiers.push({sampled_ms:performance.now(),hold,states});
   assert.ok(states.every(x=>x.ready===1&&x.epoch===1&&x.resyncs===0&&x.credit_r<=16&&x.credit_u<=16&&x.assembly_bytes<=x.assembly_limit&&x.queue_limit===8));
   assert.ok(states[1].facts-states[1].head>=0&&states[1].facts-states[1].head<=30,'freshness during held checkpoint');
   return hold.active&&hold.heldForMs>=300;
  },'checkpoint traffic held before kill',10000);
  fs.writeFileSync(`${out}/hold-frontiers.json`,JSON.stringify(frontiers,null,2));
 }
 const before=await Promise.all(peers.map(state));
 if(process.env.REPLAY_RELIABLE_HOLD==='1'){
  const hold=await peers[0].page.evaluate(()=>({...globalThis.reliableHold,heldForMs:performance.now()-globalThis.reliableHold.startedAt}));fs.writeFileSync(`${out}/reliable-hold.json`,JSON.stringify(hold,null,2));
  assert.ok(hold.milliseconds===holdMs&&hold.triggered&&hold.held>0&&hold.peakBytes<=65536&&hold.errors.length===0);
  if(holdAtKill)assert.ok(hold.active&&hold.queuedBytes>0&&hold.heldForMs>=300);
  else assert.ok(!hold.active&&hold.queuedBytes===0&&hold.elapsedMs>=holdMs-1);
 }
 assert.ok(before.every(x=>x.epoch===1&&x.ready===1&&x.rollback_limit===120));
 fs.writeFileSync(`${out}/migration-before.json`,JSON.stringify({mode,resumed,before},null,2));
 assert.ok(before.every((x,i)=>x.living>=32&&x.living<=44&&x.spent1>resumed[i].spent1&&x.spent2>resumed[i].spent2),'active population and fire at migration trigger');
 if(process.env.REPLAY_CAPTURE_ARCHIVES==='1')fs.writeFileSync(`${out}/archives.json`,JSON.stringify(await peers[0].page.evaluate(()=>globalThis.stressArchives)));
 if(process.env.REPLAY_RENDER_TRACE==='1'){const traces=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.bufferTrace)));fs.writeFileSync(`${out}/render-before.json`,JSON.stringify(traces,null,2));assert.ok(traces.every(t=>t.binds>0&&t.conflicts===0));}
 if(process.env.REPLAY_SNAPSHOT_APPLY_TRACE==='1')for(const p of peers)fs.writeFileSync(`${out}/applied-${p.role}-before.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replaySnapshotApplyTrace)));
 if(process.env.REPLAY_SNAPSHOT_TRACE==='1')for(const p of peers)fs.writeFileSync(`${out}/snapshots-${p.role}-before.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replaySnapshotTrace)));
 if(process.env.REPLAY_RTC_CREDIT_TRACE==='1')for(const p of peers)fs.writeFileSync(`${out}/credits-${p.role}-before.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replayCreditTrace)));
 for(const p of peers){await requireRelay(p.page,relayObservations,p.role+'-before-migration');fs.writeFileSync(`${out}/control-${p.role}-before.json`,JSON.stringify(await controlEvidence(p.page)));}
 const trigger=performance.now();
 if(mode==='planned')await send(peers[0],'handoff');
 else {peers[0].killed=true;assert.ok(peers[0].browser.process().kill('SIGKILL'));}
 await until(async()=>{const x=await state(peers[1]);telemetry.push({sampled_ms:performance.now(),role:'candidate',...x});return x.epoch===2&&x.authority===1&&x.recovery_ready===1;},'takeover',25000);
 const winner=await state(peers[1]);
 assert.equal(winner.restored_exact,1);assert.equal(winner.recovery_kind,mode==='planned'?1:2);assert.ok(winner.lost_ticks<=120);
 if(mode==='planned')assert.equal(winner.lost_ticks,0);
 if(mode==='crash')await open(1,true);
 const live=peers.filter(p=>!p.killed);
 await until(async()=>{const rows=await Promise.all(live.map(state));return rows.every(x=>x.epoch===2&&x.ready===1)&&rows.filter(x=>x.authority===1).length===1;},'followers',20000);
 await Promise.all(live.map(p=>send(p,'stopload')));
 const follower=live.find(p=>p.member===1),prior=await state(peers[1]);
 await pause(1500);await send(follower,'dash');
 await until(async()=>{const rows=await Promise.all(live.map(state));return rows.every(x=>x.dashes>prior.dashes)&&rows.every(x=>x.dash_pending===0);},'continued action',10000);
 await send(follower,'stop');await Promise.all(live.map(p=>send(p,'hashes')));
 let hashes=[],common=[];
 await until(async()=>{hashes=await Promise.all(live.map(p=>p.page.evaluate(()=>globalThis.stressHashes)));common=Object.keys(hashes[0]).filter(k=>hashes.every(h=>k in h));for(const k of common)assert.ok(hashes.every(h=>h[k]===hashes[0][k]),'world '+k);return common.length>=10;},'continued worlds',15000);
 for(const p of live){await requireRelay(p.page,relayObservations,p.role+'-recovered');fs.writeFileSync(`${out}/control-${p.role}-recovered.json`,JSON.stringify(await controlEvidence(p.page)));}
 const final=await Promise.all(live.map(state));
 fs.writeFileSync(`${out}/migration.json`,JSON.stringify({mode,resumed,before,winner,final,elapsed_ms:performance.now()-trigger,common,hashes},null,2));
 await follower.page.screenshot({path:`${out}/migrated.png`});console.log('REPLAY_LOADED_MIGRATION_RUNTIME_OK mode='+mode+' common='+common.length);

}finally{
 await Promise.allSettled(peers.map(async p=>{
  if(p.killed||!p.browser.connected)return;
  if(process.env.REPLAY_SNAPSHOT_APPLY_TRACE==='1')fs.writeFileSync(`${out}/applied-${p.role}.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replaySnapshotApplyTrace)));
  if(process.env.REPLAY_SNAPSHOT_TRACE==='1')fs.writeFileSync(`${out}/snapshots-${p.role}.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replaySnapshotTrace)));
  if(process.env.REPLAY_RTC_CREDIT_TRACE==='1')fs.writeFileSync(`${out}/credits-${p.role}.json`,JSON.stringify(await p.page.evaluate(()=>globalThis.replayCreditTrace)));
  if(p.profiler){const result=await p.profiler.send('Profiler.stop');fs.writeFileSync(`${out}/cpu-${p.role}.json`,JSON.stringify(result.profile));}
  const capture=await p.page.evaluate(()=>({receipts:globalThis.stressReceipts||{},fault:globalThis.stressFault,state:globalThis.stressState,render:globalThis.bufferTrace||null,archives:globalThis.stressArchives||null}));
  if(capture.archives)fs.writeFileSync(`${out}/archives-${p.role}.json`,JSON.stringify(capture.archives));
  for(const [name,value]of Object.entries(capture.receipts))fs.writeFileSync(`${out}/${name}.json`,JSON.stringify(value,null,2));
  fs.writeFileSync(`${out}/terminal-${p.role}.json`,JSON.stringify({fault:capture.fault,state:capture.state,render:capture.render},null,2));
 }));
 fs.writeFileSync(`${out}/relay.json`,JSON.stringify(relayObservations,null,2));
 fs.writeFileSync(`${out}/events.json`,JSON.stringify(events,null,2));fs.writeFileSync(`${out}/telemetry.json`,JSON.stringify(telemetry,null,2));
 await Promise.allSettled(peers.map(p=>{if(p.killed){p.browser.disconnect();return;}return p.browser.close();}));
}

process.exit(0);
