import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const [base,service,out,mode='guest']=process.argv.slice(2);
assert.ok(['guest','creator'].includes(mode));
fs.mkdirSync(out,{recursive:true});
const peers=[];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,label,timeout=90000){
  const end=Date.now()+timeout;
  while(Date.now()<end){
    for(const p of peers) assert.equal(p.errors.length,0,`${p.name}: ${p.errors.join('\n')}`);
    if(await predicate())return;
    await sleep(100);
  }
  throw Error(`Timeout ${label}`);
}
async function open(name,profile){
  const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:path.join(out,profile),headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--password-store=basic','--use-mock-keychain']});
  await browser.defaultBrowserContext().overridePermissions(new URL(base).origin,['clipboard-read','clipboard-write','clipboard-sanitized-write']);
  const page=await browser.newPage();await page.setViewport({width:1280,height:720});
  const p={name,browser,page,lines:[],errors:[],noRoom:0};peers.push(p);
  page.on('console',msg=>{
    const text=msg.text();p.lines.push(text);
    // Console contains runner/session receipts, never credentials or invitations.
    fs.appendFileSync(path.join(out,`${name}.log`),text+'\n');
    if(/REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:|Aborted\(|memory access out of bounds/.test(text))p.errors.push(text);
  });
  page.on('pageerror',error=>p.errors.push(String(error)));
  const downloads=path.join(out,'downloads');fs.mkdirSync(downloads,{recursive:true});
  const cdp=await page.createCDPSession();await cdp.send('Page.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
  await cdp.send('Network.enable');
  cdp.on('Network.webSocketFrameReceived',event=>{try{if(JSON.parse(event.response.payloadData).reason==='no_room')p.noRoom++;}catch{}});
  p.cdp=cdp;
  return p;
}
async function lobby(p,url,button,archive){
  await p.page.goto(url,{waitUntil:'domcontentloaded'});
  if(archive){
    const file=await p.page.$('#archive');await file.uploadFile(archive);
    await p.page.waitForFunction(()=>document.querySelector('#archive-note').textContent==='Participant file imported');
  }
  // Exercise the real form's target construction, then add fixture input/fault
  // flags before any engine/enrollment starts. No production source is rewritten.
  await p.page.setRequestInterception(true);
  let accept;
  const target=new Promise(resolve=>{accept=resolve;});
  const intercept=request=>{
    if(request.isNavigationRequest()&&new URL(request.url()).pathname.endsWith('/index.html')){accept(request.url());void request.abort();}
    else void request.continue();
  };
  p.page.on('request',intercept);await p.page.click(button);
  const href=await Promise.race([target,sleep(10000).then(()=>{throw Error('Lobby did not launch');})]);
  p.page.off('request',intercept);await p.page.setRequestInterception(false);
  const run=new URL(href);assert.equal(run.searchParams.get('service'),service);assert.equal(run.searchParams.get('watch'),'0');
  assert.equal(run.searchParams.has('key'),false);
  for(const [k,v] of Object.entries({test:'1',probe:'1',until:'900',latency:'100',jitter:'15',loss:'500',duplicate:'500'}))run.searchParams.set(k,v);
  await p.page.goto(run.href,{waitUntil:'domcontentloaded',timeout:60000});
}
try{
  const creator=await open('creator','profile-creator');
  const createURL=new URL('lobby.html',base);createURL.search=new URLSearchParams({service,local:'1'});
  await lobby(creator,createURL.href,'#party-create');
  await until(async()=>{
    await creator.page.mouse.click(110,145);
    return Boolean(await creator.page.$('#replay-duel-share-link'));
  },'copy invitation');
  await creator.browser.defaultBrowserContext().overridePermissions(new URL(base).origin,['clipboard-read','clipboard-write']);
  await creator.page.click('#replay-duel-share-copy');
  await creator.page.waitForFunction(()=>document.querySelector('#replay-duel-share [role=status]').textContent==='Select and copy the invitation above.',{timeout:10000});
  await creator.browser.defaultBrowserContext().overridePermissions(new URL(base).origin,['clipboard-read','clipboard-write','clipboard-sanitized-write']);
  await creator.page.click('#replay-duel-share-copy');
  await creator.page.waitForFunction(()=>document.querySelector('#replay-duel-share [role=status]').textContent==='Invitation copied.',{timeout:10000});
  const invitation=await Promise.race([creator.page.evaluate(()=>navigator.clipboard.readText()),sleep(10000).then(()=>{throw Error('Clipboard read timed out');})]);
  assert.equal(invitation,await creator.page.$eval('#replay-duel-share-link',input=>input.value));
  await creator.page.evaluate(()=>document.querySelector('#replay-duel-share').close());
  const inviteURL=new URL(invitation);
  assert.ok(inviteURL.searchParams.get('invite'));assert.equal(inviteURL.searchParams.get('service'),service);
  assert.equal(inviteURL.searchParams.has('key'),false);
  await creator.cdp.send('Debugger.enable');await creator.cdp.send('Debugger.pause');
  const guest=await open('guest','profile-guest');
  await lobby(guest,invitation,'#party-join');
  await until(()=>guest.noRoom>0,'guest waits for creator signaling',15000);
  await creator.cdp.send('Debugger.resume');await creator.cdp.send('Debugger.disable');
  await until(()=>creator.lines.some(x=>x.startsWith('RDP_PROVISIONED '))&&guest.lines.some(x=>x.startsWith('RDP_PROVISIONED ')),'provisioned participants');
  const receipt=p=>p.lines.find(x=>x.startsWith('RDP_PROVISIONED ')).match(/session=(\d+) member=(\d+) incarnation=(\d+)/).slice(1);
  const host=receipt(creator),joined=receipt(guest);
  assert.equal(host[0],joined[0]);assert.notEqual(host[0],'123');assert.equal(host[1],'1');assert.equal(joined[1],'2');assert.equal(joined[2],'2');
  const leaving=mode==='creator'?creator:guest,survivor=mode==='creator'?guest:creator;
  await leaving.page.waitForFunction(()=>globalThis.replayDuelState?.tick>=240,{timeout:90000});
  await leaving.page.mouse.click(mode==='creator'?350:110,145);
  const archive=path.join(out,'downloads',`duel-seat-${mode==='creator'?0:1}.rply`);
  await until(()=>leaving.lines.some(x=>x.startsWith('RDP_SAVED '))&&fs.existsSync(archive),'participant download');
  const saved=leaving.lines.find(x=>x.startsWith('RDP_SAVED '));
  assert.equal(fs.statSync(archive).size,Number(saved.match(/bytes=(\d+)/)[1]));
  const pid=leaving.browser.process().pid;leaving.browser.process().kill('SIGKILL');
  await until(()=>leaving.browser.process().exitCode!==null||leaving.browser.process().signalCode!==null,'participant process stopped',15000);
  const returning=await open('returning',mode==='creator'?'profile-creator':'profile-guest');
  await lobby(returning,createURL.href,'#party-rejoin',archive);
  await until(()=>returning.lines.some(x=>x.startsWith('RDP_PROVISIONED ')),'durable rejoin');
  const resumed=receipt(returning);assert.equal(resumed[0],host[0]);assert.equal(resumed[1],mode==='creator'?'1':'2');assert.equal(resumed[2],'3');
  await until(()=>survivor.lines.some(x=>x.startsWith('RDP_LIVE_REBOUND '))&&returning.lines.some(x=>x.startsWith('RDP_RESTORED ')),'runner reconnect');
  await until(()=>[survivor,returning].every(p=>p.lines.some(x=>x.startsWith('RDP_RESULT '))),'converged result');
  const results=[survivor,returning].map(p=>p.lines.find(x=>x.startsWith('RDP_RESULT ')));
  assert.equal(results[0].match(/hash=(\d+)/)[1],results[1].match(/hash=(\d+)/)[1]);
  await survivor.page.screenshot({path:path.join(out,'survivor.png')});await returning.page.screenshot({path:path.join(out,'returning.png')});
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({pass:true,mode,session:host[0],members:[host[1],joined[1]],incarnations:['2',resumed[2]],initial_no_room:guest.noRoom,killed_pid:pid,results,checks:['real create/join/rejoin menu targets','clipboard fallback and permitted copy','copied invitation without credential URL','separate persistent browser profiles','guest-before-creator signaling retry','dynamic room scope','fresh-process IndexedDB enrollment reuse','new registration incarnation','participant archive restore','surviving runner rebind','faulted corpus convergence']},null,2));
  console.log('REPLAY_P2P_PARTY_BROWSER_OK');
}finally{
  for(const p of peers)try{await p.browser.close();}catch{}
}
