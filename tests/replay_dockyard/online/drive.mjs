import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import {installRelayProbe, relayPairs} from '../../replay_turn/probe.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';

const [base, service, output, ticksText] = process.argv.slice(2), ticks=Number(ticksText);
const actors={}, errors=[], relay=process.env.REPLAY_ICE_CONFIG?JSON.parse(fs.readFileSync(process.env.REPLAY_ICE_CONFIG)):null;
const scenario=process.env.N1_CASE||'pair';
const production=process.env.N1_PRODUCTION_UI==='1';
const report={result:'FAIL',ticks,scope:'Actual Party enrollment and Room-owned complete physics through real menu buttons, independent local Chrome processes. Software GL with drawing disabled; no public Internet or rendering-budget claim.'};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const check=(ok,text)=>{if(!ok)throw Error(text);};
const sha=b=>createHash('sha256').update(b).digest('hex');
// Firefox BiDi does not implement Chromium clipboard permission names. On the
// declared macOS reference host, observe the real OS clipboard after the real
// Copy button, without replacing the page clipboard implementation.
async function readClipboard(a){return a.browser_name==='firefox'?execFileSync('/usr/bin/pbpaste',{encoding:'utf8'}):a.page.evaluate(()=>navigator.clipboard.readText());}
async function writeClipboard(a,value){if(a.browser_name==='firefox'){execFileSync('/usr/bin/pbcopy',{input:value});}else await a.page.evaluate(value=>navigator.clipboard.writeText(value),value);}
async function finishCopyDialog(actor){
 if(!await actor.page.$('#dockyard-room-entry input[readonly]'))return;
 await actor.page.click('#dockyard-room-entry button[type=submit]');
 if(await actor.page.$eval('#dockyard-room-entry p',p=>!p.textContent.includes('Copied.'))){
  await actor.page.focus('#dockyard-room-code');await actor.page.keyboard.down('Meta');await actor.page.keyboard.press('KeyC');await actor.page.keyboard.up('Meta');
 }
 await actor.page.click('#dockyard-room-entry button[type=button]');await delay(100);
}
const validInvite=code=>/^[A-HJ-NP-Z2-9]{5}$/.test(code)||/^RP1\.[0-9a-f]{16}\.[0-9a-f]{64}$/.test(code);
const invalidInviteMessage=text=>/complete invitation|5-character room code/.test(text||'');
async function restoreClipboard(){
 const original=Object.values(actors).find(a=>typeof a.previous_clipboard==='string')?.previous_clipboard;
 if(typeof original!=='string')return false;
 // Later actors captured the invitation. Restore the first original value
 // through any surviving browser, rather than restoring those later copies.
 for(const a of Object.values(actors))try{await writeClipboard(a,original);if(await readClipboard(a)===original)return true;}catch{}
 return false;
}
let sequence=0;
process.on('SIGTERM',async()=>{await Promise.all(Object.values(actors).map(a=>a.browser.close()));process.exit(124);});
async function request(actor,action='status',extra={}){
 const id=++sequence;
 await actor.page.evaluate(value=>{globalThis.dockyardRequest=value;},{id,action,...extra});
 await actor.page.waitForFunction(id=>globalThis.dockyardResponse?.id===id,{timeout:15000},id);
 return actor.page.evaluate(()=>globalThis.dockyardResponse);
}
async function open(role,{profileDir,rendered=false,headless=process.env.N1_HEADLESS!=='0',setup,browserName=process.env.N1_BROWSER||'chrome',query={}}={}){
 const directory=path.join(output,role);fs.mkdirSync(directory);
 const flags=['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding'];
 if(rendered)for(const flag of ['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist']){const i=flags.indexOf(flag);if(i>=0)flags.splice(i,1);}
 if(['frozen','hostfrozen'].includes(process.env.R1_FLOW))for(const flag of ['--disable-background-timer-throttling','--disable-renderer-backgrounding']){const i=flags.indexOf(flag);if(i>=0)flags.splice(i,1);}
 if(!relay)flags.push('--disable-features=WebRtcHideLocalIpsWithMdns');
 if(process.env.N1_TLS_SPKI)flags.push('--ignore-certificate-errors-spki-list='+process.env.N1_TLS_SPKI);
 const firefox=browserName==='firefox';
 const profile=profileDir||(firefox&&process.env.FIREFOX_PROFILE_DIR)||path.join(directory,'profile');
 const geckoProfile=firefox&&process.env.Q1_GECKO_PROFILE==='1'?{enabled:true,path:path.join(directory,'gecko-profile.json'),features:'js,stackwalk,cpu',filters:'GeckoMain,DOM Worker,pthread,Renderer,Compositor',entries:4000000,interval_ms:1}:null;
 const launchEnvironment={...process.env};
 if(geckoProfile)Object.assign(launchEnvironment,{MOZ_PROFILER_STARTUP:'1',MOZ_PROFILER_SHUTDOWN:geckoProfile.path,MOZ_PROFILER_STARTUP_FEATURES:geckoProfile.features,MOZ_PROFILER_STARTUP_FILTERS:geckoProfile.filters,MOZ_PROFILER_STARTUP_ENTRIES:String(geckoProfile.entries),MOZ_PROFILER_STARTUP_INTERVAL:String(geckoProfile.interval_ms)});
 const endpoint=firefox?process.env.FIREFOX_BIDI_ENDPOINT:null;
 const shared=process.env.N1_SAME_BROWSER==='1'?actors.host:null;
 const backgroundFlags=['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows'];
 if(process.env.N1_SAME_BROWSER==='1')for(const flag of backgroundFlags){let index;while((index=flags.indexOf(flag))>=0)flags.splice(index,1);}
 const browser=shared?shared.browser:endpoint?await puppeteer.connect({browserWSEndpoint:endpoint,protocol:'webDriverBiDi'}):await puppeteer.launch({browser:firefox?'firefox':'chrome',protocol:firefox?'webDriverBiDi':'cdp',executablePath:firefox?'/Applications/Firefox.app/Contents/MacOS/firefox':process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless,userDataDir:profile,args:firefox?['--no-remote']:flags,ignoreDefaultArgs:process.env.N1_SAME_BROWSER==='1'?backgroundFlags:undefined,env:launchEnvironment});
 const actor=actors[role]={role,browser,browser_name:browserName,shutdown:false,version:await browser.version(),profile_dir:shared?shared.profile_dir:profile};
 if(geckoProfile)actor.cpu_profiler=geckoProfile;
 fs.writeFileSync(path.join(directory,'process.json'),JSON.stringify({pid:browser.process()?.pid??null,argv:browser.process()?.spawnargs??null,owned_os_launch_endpoint:endpoint||null,profile_dir:profile},null,2));
 const page=actor.page=await browser.newPage();
 const viewport=process.env.N1_VIEWPORT?JSON.parse(process.env.N1_VIEWPORT):{width:1280,height:720,deviceScaleFactor:1};
 actor.viewport=viewport;await page.setViewport(viewport);
 if(!firefox)await browser.defaultBrowserContext().overridePermissions(new URL(base).origin,['clipboard-read','clipboard-write','clipboard-sanitized-write']);
 // The shared selected-pair probe does not modify protocol or payloads.
 await installRelayProbe(page,relay||{iceServers:[]});
 if(setup)await setup(page);
 page.on('console',msg=>{
  const text=msg.text();fs.appendFileSync(path.join(directory,'console.ndjson'),JSON.stringify({type:msg.type(),text,arrival_ms:performance.now()})+'\n');
  if(msg.type()==='error'&&text.includes('JSHandle@')){
   Promise.all(msg.args().map(arg=>arg.evaluate(value=>({name:String(value?.name||''),message:String(value?.message||value),stack:String(value?.stack||'')}))))
    .then(details=>{fs.appendFileSync(path.join(directory,'console-details.ndjson'),JSON.stringify({text,details,arrival_ms:performance.now()})+'\n');})
    .catch(error=>{fs.appendFileSync(path.join(directory,'console-details.ndjson'),JSON.stringify({text,detail_unavailable:String(error)})+'\n');});
  }
  if(text.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK'))actor.shutdown=true;
  if(text.startsWith('DOCKYARD_LOBBY ')&&actor.cold_lobby_ms===undefined)actor.cold_lobby_ms=performance.now()-actor.navigation_start_ms;
  if(text.startsWith('DOCKYARD_MENU_READY ')&&actor.cold_usable_menu_ms===undefined)actor.cold_usable_menu_ms=performance.now()-actor.navigation_start_ms;
  for(const tag of ['DOCKYARD_LOBBY','DOCKYARD_VISUALS_READY','DOCKYARD_MENU_READY','DOCKYARD_UI_LAYOUT','DOCKYARD_CONNECTION','SAMPLE_QUALIFICATION_TRANSFER','SAMPLE_HOST_LOST','SAMPLE_REHOST_FROM','SAMPLE_STATUS','SAMPLE_ROOM','SAMPLE_READY','SAMPLE_RTC','SAMPLE_NETWORK','SAMPLE_GAME','SAMPLE_WEB_FRAME','SAMPLE_INPUTS','SAMPLE_TAIL','SAMPLE_RESULT']){
   if(text.startsWith(tag+' ')){try{actor[tag]=JSON.parse(text.slice(tag.length+1));actor.event_counts??={};actor.event_counts[tag]=(actor.event_counts[tag]||0)+1;}catch(e){errors.push(role+' malformed '+tag);}}
  }
  const expectedFrozenSocket=['frozen','hostfrozen'].includes(process.env.R1_FLOW)&&text.includes('WebSocket connection')&&text.includes('Page entered Back-Forward Cache');
  if(expectedFrozenSocket){(actor.expected_lifecycle_events??=[]).push({text,arrival_ms:performance.now()});}
  else if(msg.type()==='error'||['SCRIPT ERROR','ODIN_SCRIPT_PANIC','SHUTDOWN_NOT_EMPTY','SHUTDOWN_LIVE','RuntimeError:'].some(v=>text.includes(v)))errors.push(role+': '+text);
  if(actor.SAMPLE_RESULT?.ok===false)errors.push(role+': actual failed result');
 });
 page.on('pageerror',e=>errors.push(role+': '+String(e.stack||e)));
 const url=new URL(base);for(const [k,v] of Object.entries({service,local:process.env.N1_EXTERNAL_SERVICE==='1'?'0':'1',scripted:'1',ticks:String(ticks),render:rendered?'1':'0',...query}))url.searchParams.set(k,v);
 if(process.env.REPLAY_TURN_PROVIDER==='1')url.searchParams.set('relay','1');
 if(production)url.searchParams.set('ui_layout','1');
 actor.url=url.toString();actor.navigation_start_ms=performance.now();await page.goto(actor.url,{waitUntil:'domcontentloaded',timeout:60000});
 actor.isolated=await page.evaluate(()=>crossOriginIsolated);
 actor.previous_clipboard=await readClipboard(actor);
 if(scenario==='no-isolation')return actor;
 let response,until=Date.now()+60000;
 while(Date.now()<until&&!errors.length){
  if(production){
   if(actor.DOCKYARD_LOBBY?.configured===true&&actor.DOCKYARD_MENU_READY){response={online:{can_start:true,cohort:actor.DOCKYARD_MENU_READY.cohort}};break;}
   await delay(100);continue;
  }
  try{response=await request(actor);if(response.online?.can_start)break;}catch{}
  await delay(100);
 }
 check(actor.isolated&&response?.online?.can_start,role+': actual initialized menu unavailable: '+JSON.stringify(response?.online));
 actor.cohort=response.online.cohort;
 if(production)await page.screenshot({path:path.join(directory,'initial-menu.png')});
 return actor;
}
async function typeAt(actor,x,y,text){
 await actor.page.bringToFront();await actor.page.mouse.click(x,y);
 await delay(100); // Let the engine's input frame assign focus before typing.
 const nativeEntry=Boolean(await actor.page.$('#dockyard-room-code:not([readonly])'));
 await actor.page.keyboard.down('Meta');await actor.page.keyboard.press('KeyA');await actor.page.keyboard.up('Meta');
 await actor.page.keyboard.type(text,{delay:40});await delay(100);
 if(nativeEntry){await actor.page.click('#dockyard-room-entry button[type=submit]');await delay(100);}
}
async function controlPoint(actor,key,x,y){
 const until=Date.now()+500;
 while(!actor.DOCKYARD_UI_LAYOUT&&Date.now()<until)await delay(25);
 const layout=actor.DOCKYARD_UI_LAYOUT,control=layout?.controls?.[key];
 if(!control)return {x,y}; // Earlier immutable candidates have no layout probe.
 return actor.page.evaluate(({layout,control})=>{
  const canvas=document.querySelector('canvas').getBoundingClientRect();
  const r=control.rect,p=layout.viewport;
  return {x:canvas.x+(r[0]+r[2]/2)*canvas.width/p[0],y:canvas.y+(r[1]+r[3]/2)*canvas.height/p[1]};
 },{layout,control});
}
async function clickControl(actor,key,x,y){
 await actor.page.bringToFront();const point=await controlPoint(actor,key,x,y);await actor.page.mouse.click(point.x,point.y);
}
async function typeControl(actor,key,x,y,text){
 const point=await controlPoint(actor,key,x,y);await typeAt(actor,point.x,point.y,text);
}
async function productionEnrollment(host,clientLabel='client',clientOptions={}){
 // Observe actual logical Control rectangles; earlier immutable candidates
 // retain the reference-coordinate fallback. No game state is edited here.
 await typeControl(host,'name',1000,452,'Mint');await clickControl(host,'host',855,530);
 await writeClipboard(host,'');
 let invitation='',deadline=Date.now()+20000;
 while(Date.now()<deadline&&!errors.length){
  await clickControl(host,'copy',1030,560);await delay(250);await finishCopyDialog(host);
  invitation=await readClipboard(host);if(invitation)break;
 }
 check(validInvite(invitation),'actual production Copy Invite did not provide a valid room code');report.copy_invite_verified=true;
 const client=process.env.N1_PREOPEN_CLIENT==='1'&&actors[clientLabel]?actors[clientLabel]:await open(clientLabel,clientOptions);if(clientLabel!=='client')client.expected_role='client';check(client.cohort===host.cohort,'different production cohorts');
 if(process.env.N1_SAME_BROWSER==='1'){
  await client.page.bringToFront();
  report.hidden_host_before_join=await host.page.evaluate(()=>({visibility:document.visibilityState,method:globalThis.dockyardWebRuntimeV2?.mode(),frames:engine.rtenv.MainLoop.currentFrameNumber}));
 }
 await typeControl(client,'name',1000,452,'Coral');await typeControl(client,'code',1000,488,'invalid');await clickControl(client,'join',906,530);
 deadline=Date.now()+5000;while(!invalidInviteMessage(client.DOCKYARD_CONNECTION?.message)&&Date.now()<deadline)await delay(50);
 check(invalidInviteMessage(client.DOCKYARD_CONNECTION?.message),'actual production invalid-invite rejection unavailable');report.invalid_invite_rejected=true;
 await typeControl(client,'code',1000,488,invitation);await clickControl(client,'join',906,530);invitation='';
 if(process.env.N1_SAME_BROWSER==='1'){
  report.hidden_host_after_join=await host.page.evaluate(()=>({visibility:document.visibilityState,method:globalThis.dockyardWebRuntimeV2?.mode(),frames:engine.rtenv.MainLoop.currentFrameNumber}));
  check(report.hidden_host_before_join.visibility==='hidden'&&report.hidden_host_after_join.visibility==='hidden'&&report.hidden_host_after_join.method==='worker'&&report.hidden_host_after_join.frames>report.hidden_host_before_join.frames,'hidden host did not keep its actual engine loop running');
 }
 return client;
}
function validate(a){
 const result=a.SAMPLE_RESULT,frame=a.SAMPLE_WEB_FRAME;
 const expectedRole=a.expected_role||a.role;
 check(a.isolated&&a.shutdown&&a.SAMPLE_READY?.backend_observed===true,a.role+': isolation/backend/shutdown unavailable');
 check(result?.ok===true&&result.target===ticks&&result.final_tick===ticks&&result.confirmed>=ticks&&!result.errors.length,a.role+': successful terminal state absent');
 check(result.role===expectedRole&&a.SAMPLE_READY.role===expectedRole,a.role+': actual producer role differs from selected case');
 check(result.cleanup.observed&&['native','wrapper','meter','owners'].every(k=>result.cleanup[k]===0),a.role+': real resource cleanup incomplete');
 check(a.SAMPLE_TAIL?.signature_match===true&&a.SAMPLE_TAIL.tick===ticks&&a.SAMPLE_TAIL.stage===(expectedRole==='host'?'final_accepted':'close_accepted'),a.role+': terminal acknowledgement absent');
 check(frame?.tick===ticks&&frame.parts.length===5,a.role+': complete frame absent');
 const parts={};for(const name of ['Solver','Game','Side','Observations','Occurrences']){
  const entry=frame.parts.find(p=>p.name===name);check(entry&&!parts[name],a.role+': missing '+name);
  const bytes=Buffer.from(entry.base64,'base64');check(bytes.length===entry.bytes&&sha(bytes)===entry.sha256,a.role+': incorrect '+name);
  parts[name]=bytes;fs.writeFileSync(path.join(output,a.role,name+'.bin'),bytes);
 }
 fs.writeFileSync(path.join(output,a.role,'signature.bin'),Buffer.from(frame.signature_base64,'base64'));
 return parts;
}
export async function run(){
try{
 if(scenario==='no-isolation'){
  const actor=await open('host');await delay(5000);
  const notice=await actor.page.evaluate(()=>document.body.innerText.slice(0,4096));
  check(actor.isolated===false&&!actor.SAMPLE_READY&&!actor.SAMPLE_RESULT,'missing isolation unexpectedly admitted the game');
  check(/SharedArrayBuffer|cross.origin|Cross.Origin|threads|Thread/.test(notice+' '+errors.join(' ')),'explicit missing-isolation feature rejection unavailable');
  report.expected_refusal={case:scenario,isolated:false,game_started:false,notice};report.result='PASS';
 }else{
 const host=await open('host');check(/^[0-9a-f]{16}$/.test(host.cohort),'actual cohort missing');
 if(process.env.N1_PREOPEN_CLIENT==='1'){await open('client');report.both_menus_ready_before_hosting=true;}
 console.log('N1_COHORT '+host.cohort);
 const until=Date.now()+45000;while(!fs.existsSync(path.join(output,'service.ready'))&&Date.now()<until)await delay(100);
 check(fs.existsSync(path.join(output,'service.ready')),'actual service startup not acknowledged');
 let client,deadline;
 if(production){client=await productionEnrollment(host);}else{
 check((await request(host,'host',{name:'Mint'})).button_pressed,'actual Host button unavailable');
 let invitation='',status;deadline=Date.now()+45000;
 while(Date.now()<deadline&&!errors.length){status=await request(host);invitation=status.online?.invite||'';if(invitation||status.online?.ended)break;await delay(100);}
 check(invitation&&status.online.connected,'actual durable invitation or Room open unavailable: '+JSON.stringify({...status.online,invite:undefined}));
 const copyButton=(await request(host)).copy_button;
 check(copyButton?.visible,'actual Copy Invite button unavailable');
 await host.page.bringToFront();await host.page.mouse.click(copyButton.x,copyButton.y);
 await delay(100);await finishCopyDialog(host);
 const clipboardDeadline=Date.now()+5000;let copied=false;
 while(Date.now()<clipboardDeadline){if(await host.page.evaluate(()=>navigator.clipboard.readText())===invitation){copied=true;break;}await delay(50);}
 check(copied,'actual clipboard did not receive the invitation');report.copy_invite_verified=true;
 client=await open('client');check(client.cohort===host.cohort,'different runtime cohorts');
 const invalid=await request(client,'join',{name:'Coral',invite:'invalid'});
 check(invalid.button_pressed&&invalid.online.can_start&&!invalid.online.connected&&invalidInviteMessage(invalid.online.message),'invalid invitation was not refused by the real menu');
 report.invalid_invite_rejected=true;
 check((await request(client,'join',{name:'Coral',invite:invitation})).button_pressed,'actual Join button unavailable');
 invitation='';
 }
 if(scenario==='bad-turn'){
  const until=Date.now()+20000;
  while(Date.now()<until){
   for(const a of [host,client]){
    if(production){check(a.SAMPLE_STATUS?.go!==true,'wrong TURN credentials unexpectedly started gameplay');}
    else{const sample=await request(a);check(sample.status?.go===false,'wrong TURN credentials unexpectedly started gameplay');}
    check(!a.SAMPLE_RESULT,'game unexpectedly exited before the checked negative-case close');
    const pairs=await relayPairs(a.page);check(!pairs.length,'wrong TURN credentials obtained a selected pair');
   }
   await delay(250);
  }
  for(const a of [host,client]){
   a.ice_errors=await a.page.evaluate(()=>globalThis.replayTestIceErrors);
   check(a.ice_errors.length>0,'actual ICE refusal evidence unavailable');
   if(production){
    check(a.SAMPLE_READY&&a.SAMPLE_STATUS?.go===false,'actual initialized waiting Session unavailable');
    // Closing the actual game window enters View's cooperative typed shutdown.
    // Lobby button positions differ between waiting Host and Joining states.
    a.negative_case_window_close=await a.page.evaluate(()=>{if(typeof engine==='undefined')return false;engine.requestQuit();return true;});
    check(a.negative_case_window_close,'actual negative-case window close unavailable');
   }else{check((await request(a,'close')).closed===true,'typed negative-case close declined');}
  }
  const closedUntil=Date.now()+15000;while((!host.shutdown||!client.shutdown)&&Date.now()<closedUntil)await delay(50);
  check(host.shutdown&&client.shutdown,'actual clean engine shutdown unavailable');
  for(const a of [host,client]){
   await a.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000});
   a.godot_runtime_exit_observed=true;
  }
  check(!errors.some(v=>/PANIC|SHUTDOWN_|CONTRACT_REJECTED|RuntimeError:/.test(v)),'unexpected runtime failure during credential rejection');
  report.expected_refusal={case:scenario,no_go:true,no_selected_pair:true,typed_close:true,shutdown:true};report.result='PASS';
 }else{
 deadline=Date.now()+90000;let lastStats=0;
 while((!host.shutdown||!client.shutdown)&&!errors.length&&Date.now()<deadline){
  if(Date.now()-lastStats>=500){
   for(const a of [host,client])if(!a.shutdown){
    const rows=await relayPairs(a.page);if(rows.length)a.selected_pairs=rows;
    if(!production){
     const snapshot=await request(a);const safe={...snapshot.online};delete safe.invite;delete safe.watch_invite;
     a.last_online=safe;fs.appendFileSync(path.join(output,a.role,'room-status.ndjson'),JSON.stringify({arrival_ms:performance.now(),online:safe,status:snapshot.status})+'\n');
     if(safe.ended)errors.push(a.role+': actual Room ended: '+safe.message);
    }
   }
   lastStats=Date.now();
  }
  await delay(50);
 }
 check(!errors.length,errors.join('\n'));
 const hp=validate(host),cp=validate(client);
 for(const name of Object.keys(hp))check(hp[name].equals(cp[name]),'five-part mismatch '+name);
 check(host.SAMPLE_WEB_FRAME.signature_base64===client.SAMPLE_WEB_FRAME.signature_base64,'complete signature mismatch');
 check(host.SAMPLE_INPUTS?.nonzero_by_seat?.length===2&&host.SAMPLE_INPUTS.nonzero_by_seat.every(v=>Number.isSafeInteger(v)&&v>0),'authority did not commit two nonzero seats');
 for(const a of [host,client]){
  check(a.selected_pairs?.length&&a.selected_pairs.every(v=>v.bytesSent>0&&v.bytesReceived>0),'actual selected candidate traffic missing');
  if(relay)check(a.selected_pairs.every(v=>v.policy==='relay'&&v.local==='relay'&&v.remote==='relay'),'selected route was not forced TURN');
  if(process.env.REPLAY_TURN_PROVIDER==='1')check(a.selected_pairs.every(v=>v.credentialExpires>0),'actual provider credential expiry unavailable');
 }
 report.all_five_byte_equal=true;
 if(process.env.N1_SAME_BROWSER==='1'){
  check(host.browser===client.browser&&host.page.browserContext()===client.page.browserContext(),'same-browser test did not share the default storage context');
  const hint=a=>a.page.evaluate(()=>Object.entries(sessionStorage).filter(([key])=>key.startsWith('replay-party-seat-v1/')));
  const [hh,ch]=await Promise.all([hint(host),hint(client)]);
  check(hh.length===1&&ch.length===1&&hh[0][0]===ch[0][0]&&hh[0][1]==='0'&&ch[0][1]==='1','tabs did not keep distinct storage seats');
  for(const a of [host,client]){
   await a.page.waitForFunction(()=>navigator.locks.query().then(q=>!q.held.some(l=>l.name.startsWith('replay-party-seat-v1/'))),{timeout:15000,polling:100});
   await a.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000,polling:100});
   a.godot_runtime_exit_observed=true;
  }
  report.same_browser_context=true;
  report.distinct_storage_seats=true;report.seat_locks_released=true;
  report.scope='Two tabs in one browser default context and profile, real production Host/Join through the selected Room/TURN service; complete five-part comparison and typed cleanup.';
 }
 report.result='PASS';
 }
 }
}catch(e){report.error=String(e.stack||e);}
finally{
 report.clipboard_restored=await restoreClipboard();
 for(const a of Object.values(actors)){
  if(production&&report.result!=='PASS')try{
   await a.page.screenshot({path:path.join(output,a.role,'failed-menu.png')});
   if(!a.shutdown){
    a.failure_shutdown_requested=await a.page.evaluate(()=>{if(typeof engine==='undefined')return false;engine.requestQuit();return true;});
    const until=Date.now()+15000;while(!a.shutdown&&Date.now()<until)await delay(50);
   }
   if(a.shutdown){await a.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000});a.godot_runtime_exit_observed=true;}
  }catch(e){errors.push(a.role+': failure cleanup '+String(e));}
  report[a.role]=Object.fromEntries(Object.entries(a).filter(([k])=>!['browser','page','previous_clipboard'].includes(k)));
 }
 for(const browser of new Set(Object.values(actors).map(a=>a.browser)))await browser.close();
 report.errors=errors;fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));
return report.result==='PASS'?0:1;
}
export {actors,errors,report,open,request,delay,check,validate,productionEnrollment,relayPairs,output,ticks,readClipboard,writeClipboard,restoreClipboard,finishCopyDialog,typeAt,controlPoint,clickControl,typeControl};
if(process.argv[1]===fileURLToPath(import.meta.url))process.exit(await run());
