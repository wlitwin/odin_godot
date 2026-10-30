import assert from 'node:assert/strict';
import {attacks as admissionAttacks} from '../../tests/replay_p2p_admission/attacks.mjs';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [base,signal,mode='fault'] = process.argv.slice(2);
const logs = process.env.REPLAY_DUEL_WEB_LOGS;
fs.mkdirSync(logs,{recursive:true});
const peers=[];
const authenticated=process.env.RDP_WEB_AUTH==='1';
const rejoining=['rejoin','creator'].includes(mode),creator=mode==='creator';
if(creator)assert.ok(authenticated,'creator recovery requires the authenticated fixed room');
let survivorGame;
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const waitFor=async(predicate,label,timeout=90000)=>{
 const until=Date.now()+timeout;
 while(Date.now()<until){
  for(const peer of peers)assert.equal(peer.errors.length,0,`${peer.name}: ${peer.errors.join('\n')}`);
  if(predicate())return;
  await delay(100);
 }
 throw new Error(`Timeout ${label}`);
};
const ticks=mode==='watch'?1200:600;
async function open(name,room='',stage='',options={}){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
 const page=await browser.newPage();
 
 await page.setViewport({width:1280,height:720});
 const label=options.directory??stage;const directory=label?`${logs}/${label}`:logs;fs.mkdirSync(directory,{recursive:true});
 const peer={name,stage,browser,page,lines:[],errors:[],retired:false};peers.push(peer);
 if(stage==='save'||options.downloads){fs.mkdirSync(`${logs}/downloads/${name}`,{recursive:true});const cdp=await page.createCDPSession();await cdp.send('Page.setDownloadBehavior',{behavior:'allow',downloadPath:`${logs}/downloads/${name}`});}
 page.on('console',msg=>{const line=msg.text();peer.lines.push(line);fs.appendFileSync(`${directory}/${name}.log`,`${line}\n`);if(/^(RDP_|REPLAY_DUEL)/.test(line))console.log(name,line);if(/REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:|Aborted\(|memory access out of bounds/.test(line))peer.errors.push(line);});
 page.on('console',async msg=>{if(msg.type()!=='error')return;for(const arg of msg.args()){try{const error=await arg.evaluate(v=>v instanceof Error?v.stack:null);if(error){fs.appendFileSync(`${directory}/${name}.log`,String(error)+'\n');peer.errors.push(String(error));}}catch{}}});
 page.on('pageerror',error=>peer.errors.push(String(error)));
 const url=new URL(base);url.search=new URLSearchParams({role:name,room,url:signal,stage,auth:authenticated?'1':'0',test:mode==='interactive'?'0':'1',probe:mode==='interactive'||rejoining?'1':'0',live_rejoin:rejoining?'1':'0',until:String(ticks),latency:'120',jitter:'20',loss:'1000',duplicate:'1000',watch:mode==='watch'?'1':'0',blackout_ms:mode==='fault'?'3000':'0',watch_blackout_ms:mode==='watch'?'6000':'0'});
 if(authenticated){
  const member=name==='listen'?1:2,key=Buffer.alloc(32);key[0]=member+20;
  fs.mkdirSync(`${logs}/credentials`,{recursive:true});const credential=`${logs}/credentials/member-${member}.json`;
  fs.writeFileSync(credential,JSON.stringify({member,incarnation:member+100,key:key.toString('hex')}),{mode:0o600});
  await page.goto(new URL('lobby.html?auth=1',base).href,{waitUntil:'domcontentloaded'});
  await page.click('#host');
  await page.waitForFunction(()=>document.querySelector('#credential-note').textContent==='Import your participant credential to join this match.',{timeout:10000});
  assert.ok(await page.$eval('#role option[value=watch]',e=>e.disabled));
  const input=await page.$('#credential');await input.uploadFile(credential);
  await page.waitForFunction(()=>document.querySelector('#credential-note').textContent==='Participant credential imported',{timeout:15000});
 }
 if(stage==='resume'){
  await page.goto(new URL('lobby.html',base).href,{waitUntil:'domcontentloaded'});
  const input=await page.$('#archive');await input.uploadFile(`${logs}/downloads/${name}/duel-seat-${name==='listen'?0:1}.rply`);
  await page.waitForFunction(()=>document.querySelector('#archive-note').textContent==='Participant file imported',{timeout:15000});
 }
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});return peer;
}
try{
 if(mode==='resume'){
  const savedHost=await open('listen','','save');await waitFor(()=>savedHost.lines.some(x=>/^RDP_ROOM /.test(x)),'save room');
  await open('dial',savedHost.lines.find(x=>/^RDP_ROOM /.test(x)).split(' ')[1],'save');
  await waitFor(()=>peers.every(p=>p.lines.some(x=>/^RDP_SAVED /.test(x)))&&['listen','dial'].every((name,i)=>fs.existsSync(`${logs}/downloads/${name}/duel-seat-${i}.rply`)),'downloaded participant archives');
  for(const p of peers){const file=`${logs}/downloads/${p.name}/duel-seat-${p.name==='listen'?0:1}.rply`;const expected=Number(p.lines.find(x=>/^RDP_SAVED /.test(x)).match(/bytes=(\d+)/)[1]);assert.equal(fs.statSync(file).size,expected);}
  await Promise.all(peers.map(p=>p.browser.close()));
  assert.ok(peers.every(p=>p.browser.process().exitCode!==null||p.browser.process().signalCode!==null));
  fs.writeFileSync(`${logs}/closed-processes.json`,JSON.stringify(peers.map(p=>({role:p.name,pid:p.browser.process().pid,exit:p.browser.process().exitCode,signal:p.browser.process().signalCode})),null,2));
  console.log('RDP_BROWSER_PROCESSES_CLOSED');
 }
 let host=await open('listen','',mode==='resume'?'resume':'',creator?{directory:'save',downloads:true}:{});await waitFor(()=>host.lines.some(x=>/^RDP_ROOM /.test(x)),'host room');
 const room=host.lines.find(x=>/^RDP_ROOM /.test(x)).split(' ')[1];
 if(authenticated)await admissionAttacks(signal,room);
 let client=await open('dial',room,mode==='resume'?'resume':'',rejoining&&!creator?{directory:'save',downloads:true}:{});
 if(rejoining){
  const savedGame=creator?host:client;survivorGame=creator?client:host;
  await savedGame.page.waitForFunction(()=>globalThis.replayDuelState?.tick>=240,{timeout:60000});
  await savedGame.page.mouse.click(creator?365:135,150);
  const role=creator?'listen':'dial',file=`${logs}/downloads/${role}/duel-seat-${creator?0:1}.rply`;
  await waitFor(()=>savedGame.lines.some(x=>/^RDP_SAVED /.test(x))&&fs.existsSync(file),'saved participant download');
  const receipt=savedGame.lines.find(x=>/^RDP_SAVED /.test(x));
  assert.equal(fs.statSync(file).size,Number(receipt.match(/bytes=(\d+)/)[1]));
  const paused=await savedGame.page.evaluate(()=>globalThis.replayDuelState);await delay(1000);
  const settled=await savedGame.page.evaluate(()=>globalThis.replayDuelState);
  assert.equal(settled.saved,1);assert.equal(settled.tick,paused.tick);assert.equal(settled.sampled,paused.sampled);
  await savedGame.page.screenshot({path:`${logs}/saved.png`});
  const original=savedGame.browser.process(),survivor=survivorGame.browser.process();
  original.kill('SIGKILL');
  await waitFor(()=>original.exitCode!==null||original.signalCode!==null,'killed participant process',15000);
  assert.equal(original.signalCode,'SIGKILL');savedGame.retired=true;
  await waitFor(()=>survivorGame.lines.some(x=>/^RDP_REJOIN_WAIT /.test(x)),'survivor transport timeout',15000);
  assert.equal(survivor.exitCode,null);assert.equal(survivor.signalCode,null);
  const waiting=await survivorGame.page.evaluate(()=>globalThis.replayDuelState);
  const returned=await open(role,room,'resume',{directory:''});if(creator)host=returned;else client=returned;
  await waitFor(()=>survivorGame.lines.some(x=>/^RDP_LIVE_REBOUND count=1 /.test(x))&&returned.lines.some(x=>/^RDP_RESTORED /.test(x)),'live browser rejoin');
  const rebound=survivorGame.lines.find(x=>/^RDP_LIVE_REBOUND count=1 /.test(x));
  if(authenticated){
   const newPhysical=rebound.match(/new=(\d+)/)[1];
   const expectedRemote=savedGame.lines.find(x=>/^RDP_ADMITTED /.test(x)).match(/physical=(\d+)/)[1];
   const verified=survivorGame.lines.filter(x=>new RegExp(`^RDP_ADMITTED physical=${newPhysical} member=${creator?1:2} incarnation=${creator?101:102}$`).test(x));
   assert.ok(verified.length>=(creator?2:1));
   assert.ok(returned.lines.some(x=>new RegExp(`^RDP_ADMITTED physical=${expectedRemote} member=${creator?2:1} incarnation=${creator?102:101}$`).test(x)));
  }
  assert.match(rebound,/retained=true/);assert.equal(Number(rebound.match(/head=(\d+)/)[1]),waiting.tick);
  const old=rebound.match(/old=(\d+)/)[1],fresh=rebound.match(/new=(\d+)/)[1];
  if(creator){assert.equal(old,'1');assert.equal(fresh,'1');assert.ok(Number(rebound.match(/ generation=(\d+)/)[1])>Number(rebound.match(/old_generation=(\d+)/)[1]));}
  else assert.notEqual(old,fresh);
  assert.notEqual(returned.browser.process().pid,original.pid);
  fs.writeFileSync(`${logs}/rejoin.json`,JSON.stringify({role,room,saved:receipt,paused,settled,waiting,rebound,retired:{pid:original.pid,exit:original.exitCode,signal:original.signalCode},survivor:{pid:survivor.pid,exit:survivor.exitCode,signal:survivor.signalCode},returned_pid:returned.browser.process().pid},null,2));
 }

 if(mode==='interactive'){
  await Promise.all([host,client].map(p=>p.page.waitForFunction(()=>globalThis.replayDuelState?.tick>10,{timeout:60000})));
  await host.browser.defaultBrowserContext().overridePermissions(new URL(base).origin,['clipboard-read','clipboard-write','clipboard-sanitized-write']);
  await host.page.bringToFront();
  await host.page.mouse.click(145,150);
  await host.page.waitForFunction(async()=> (await navigator.clipboard.readText()).includes('room='),{timeout:10000});
  const link=new URL(await host.page.evaluate(()=>navigator.clipboard.readText()));
  assert.ok(link.pathname.endsWith('/lobby.html'));assert.equal(link.searchParams.get('room'),room);assert.equal(link.searchParams.get('role'),'dial');
  await host.page.mouse.click(850,500);await host.page.keyboard.down('KeyA');await delay(220);await host.page.keyboard.up('KeyA');
  await Promise.all([host,client].map(p=>p.page.waitForFunction(()=>globalThis.replayDuelState?.x<250*256,{timeout:10000})));
  await host.page.keyboard.down('Space');await delay(100);await host.page.keyboard.up('Space');
  await host.page.waitForFunction(()=>globalThis.replayDuelState?.y<295*256,{timeout:10000});
  await host.page.keyboard.down('KeyJ');await delay(220);await host.page.keyboard.up('KeyJ');
  await Promise.all([host,client].map(p=>p.page.waitForFunction(()=>globalThis.replayDuelState?.shots>0,{timeout:10000})));
  fs.writeFileSync(`${logs}/input.json`,JSON.stringify(await Promise.all([host,client].map(p=>p.page.evaluate(()=>globalThis.replayDuelState))),null,2));
  await host.page.screenshot({path:`${logs}/match.png`});console.log('REPLAY_DUEL_WEB_INTERACTIVE_OK');
 } else {
 if(mode==='watch'){
  await waitFor(()=>host.lines.some(x=>/^RDP_WATCH_JOIN_READY /.test(x))&&host.lines.some(x=>/^RDP_WATCH_ROOM /.test(x)),'late spectator');
  await open('watch',host.lines.find(x=>/^RDP_WATCH_ROOM /.test(x)).split(' ')[1]);
 }
 await waitFor(()=>peers.filter(p=>!p.retired&&p.stage!=='save').every(p=>p.lines.some(x=>x===(p.name==='watch'?'REPLAY_DUEL_WATCH_OK':'REPLAY_DUEL_PEER_OK'))),'reference and confirmed hashes');
 execFileSync(process.execPath,[fileURLToPath(new URL('./check.mjs',import.meta.url)),mode==='resume'?`${logs}/resume`:logs,String(ticks)],{stdio:'inherit'});
 if(mode==='watch')execFileSync(process.execPath,[fileURLToPath(new URL('./watch_check.mjs',import.meta.url)),logs,'6000'],{stdio:'inherit'});
 else if(mode==='resume'){
  assert.ok(host.lines.some(x=>/^RDP_RESTORED /.test(x)));assert.ok(client.lines.some(x=>/^RDP_RESTORED /.test(x)));
 } else if(!rejoining){
  assert.ok(host.lines.some(x=>/^RDP_PLAYER_STALL /.test(x)));
  const restored=host.lines.find(x=>/^RDP_PLAYER_RESTORED /.test(x));assert.ok(restored);assert.ok(Number(restored.match(/elapsed_ms=(\d+)/)[1])>=3000);
 }
 if(rejoining){
  const process=survivorGame.browser.process();assert.equal(process.exitCode,null);assert.equal(process.signalCode,null);
  const path=`${logs}/rejoin.json`,receipt=JSON.parse(fs.readFileSync(path,'utf8'));
  assert.equal(process.pid,receipt.survivor.pid);
  receipt.final={listen:host.lines.find(x=>/^RDP_RESULT /.test(x)),dial:client.lines.find(x=>/^RDP_RESULT /.test(x)),survivor_pid:process.pid};
  fs.writeFileSync(path,JSON.stringify(receipt,null,2));
 }
 await host.page.screenshot({path:`${logs}/match.png`});
 console.log(`REPLAY_DUEL_WEB_${mode.toUpperCase()}_OK`);
 }
 for(const p of peers)assert.equal(p.errors.length,0,p.errors.join('\n'));
}finally{
 await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));
}
process.exit(0);
