import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,control,mode]=process.argv.slice(2),logs=process.env.RCB_LOGS;fs.mkdirSync(logs,{recursive:true});const peers=[],events=[];
const started=performance.now(),wait=ms=>new Promise(r=>setTimeout(r,ms));
const record=(event,details={})=>events.push({event,ms:Math.round(performance.now()-started),...details});
async function until(fn,label){const end=performance.now()+160000;while(performance.now()<end){for(const p of peers)if(!p.killed)assert.equal(p.errors.length,0,p.errors.join('\n'));if(fn())return;await wait(50);}throw new Error(`Timeout ${label}`);}
async function command(peer,command){await peer.page.evaluate(value=>{globalThis.rcbCommand=value;},command);record('command',{member:peer.member,command});}
async function kill(peer){peer.killed=true;record('kill',{member:peer.member,pid:peer.browser.process().pid});peer.browser.process().kill('SIGKILL');await until(()=>peer.browser.process().signalCode!==null,'killed browser exit');}
const has=(peer,prefix)=>peer.lines.some(x=>x.startsWith(prefix));
async function socialUntil(check,label){
 const end=performance.now()+20000;
 while(performance.now()<end){
  for(const p of peers)if(!p.killed)assert.equal(p.errors.length,0,p.errors.join('\n'));
  const states=await Promise.all(peers.filter(p=>!p.killed).map(p=>p.page.evaluate(()=>globalThis.caveSocial)));
  if(check(states))return states;
  await wait(50);
 }
 record('social_timeout',{label,states:await Promise.all(peers.filter(p=>!p.killed).map(p=>p.page.evaluate(()=>globalThis.caveSocial)))});
 throw new Error('Social timeout '+label);
}
async function open(member,returned=false,profileOnly=false){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:process.env.RCB_PROFILE_ROOT?`${process.env.RCB_PROFILE_ROOT}/member-${member}`:undefined,protocolTimeout:15000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
 const page=await browser.newPage(),p={member,browser,page,lines:[],errors:[],killed:false};peers.push(p);record('open',{member,returned,pid:browser.process().pid});
 page.on('console',msg=>{const line=msg.text();p.lines.push(line);fs.appendFileSync(`${logs}/${profileOnly?`profile-${member}`:returned?'returned':`member-${member}`}.log`,line+'\n');if(/^RCB_|REPLAY_CAVE_FAIL/.test(line)){console.log(member,line);record('receipt',{member,returned,line});}if(/RCB_FAIL|REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:/.test(line))p.errors.push(line);});page.on('pageerror',e=>p.errors.push(String(e)));
 const key=(member+20).toString(16).padStart(2,'0')+'00'.repeat(31);
 const url=new URL(base);url.search=new URLSearchParams({member:String(member),incarnation:String(member+100),coord_key:key,coord_url:control,token:`browser-room-${member}`,role:member===1?'host':'client',latency:'120',migration:mode,returned:returned?'1':'0',social:process.env.RCB_SOCIAL==='1'?'1':'0',lobby:process.env.RCB_LOBBY==='1'?'1':'0',name:process.env.RCB_LOBBY==='1'?`Browser ${member}`:'',persist:process.env.RCB_LOBBY==='1'?'1':'0',profile_namespace:'cave-lobby-regression'});
 if(profileOnly)url.search=new URLSearchParams({persist:'1',profile_namespace:'cave-lobby-regression',profile_check:`Browser ${member}`});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});return p;
}
try{
 assert.ok(['planned','crash','repeat','partition','successor_loss','return','signaling'].includes(mode));
 const host=await open(1);await until(()=>host.lines.includes('REPLAY_CAVE_READY'),'host boot');
 const successor=await open(2),guest=await open(3);
 await until(()=>[host,successor,guest].every(p=>has(p,'RCB_LOBBY_STARTED')),'lobby start');
 for(const p of [host,successor,guest])await p.page.evaluate(()=>globalThis.caveSocialShowScore=true);
 const before=await socialUntil(states=>states.length===3&&states.every(s=>s?.epoch===1&&s.scope===1&&s.steady&&s.rows[0].text==='0'&&s.rows.slice(1).every(r=>r.known&&Number(r.text)>=200&&Number(r.text)<2000)),'initial measurements');
 record('social_before',{states:before});
 await host.page.waitForFunction(()=>globalThis.caveSocialHandoffReady,{timeout:40000});
 await command(guest,'presentation_ping');
 await socialUntil(states=>states.every(s=>s?.marks.includes('Browser 3')),'stamped ping before migration');
 await host.page.evaluate(()=>globalThis.caveSocialAllowHandoff=true);
 await until(()=>has(host,'RCB_DURABLE'),'durable gameplay');
 if(mode==='signaling'){
  for(const p of [host,successor]){await command(p,'drop_signaling');await until(()=>has(p,'RCB_SIGNAL_RESUMED'),'signaling continuation');}
  await command(guest,'signal_action');await until(()=>has(guest,'RCB_GUEST_OK epoch=1'),'same-epoch game action');
  await guest.page.screenshot({path:`${logs}/recovered.png`});record('complete');console.log('REPLAY_CAVE_WEB_SIGNALING_OK');
 } else {
 if(['crash','return'].includes(mode))await kill(host);
 if(mode==='successor_loss'){
  await command(successor,'pause_candidate');await until(()=>has(successor,'RCB_CANDIDATE_PAUSED'),'candidate pause');
  await command(host,'handoff');await until(()=>has(host,'RCB_SUCCESSOR_WINDOW'),'handoff crash window');await kill(successor);
 }
 if(['repeat','partition','return'].includes(mode)){
  await until(()=>has(guest,'RCB_GUEST_STAGE'),'first continued guest action');
  if(mode==='repeat')await command(successor,'handoff_again');
  if(mode==='partition'){
   await until(()=>has(host,'RCB_FENCED_STABLE'),'fenced old host');await command(host,'resume_control');
   await until(()=>has(host,'RCB_MEMBER_OK'),'partitioned owner rejoin');await command(guest,'complete');
  }
  if(mode==='return'){
   const returned=await open(1,true);await until(()=>has(returned,'RCB_RETURNED_OK'),'fresh process old-host return');await command(guest,'complete');
  }
 }
 const epoch=mode==='repeat'?3:2, survivor=mode==='successor_loss'?host:successor;
 await until(()=>has(guest,`RCB_GUEST_OK epoch=${epoch}`)&&has(survivor,`RCB_MEMBER_OK member=${survivor.member} epoch=${epoch}`),'surviving game clients');
 if(['planned','repeat','partition'].includes(mode))await until(()=>has(host,`RCB_MEMBER_OK member=1 epoch=${epoch}`),'old host rejoin');
 if(process.env.RCB_SOCIAL==='1'){await until(()=>has(guest,'RCB_SOCIAL_OK')&&has(survivor,'RCB_SOCIAL_OK'),'continued browser social traffic');}
 const after=await socialUntil(states=>states.length===3&&states.every(s=>s?.epoch===2&&s.scope===2&&s.steady&&s.rows[1].text==='0'&&s.rows[2].known&&Number(s.rows[2].text)>=200&&Number(s.rows[2].text)<2000),'new authority measurements');
 record('social_after',{states:after});
 const transitions=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.caveSocialTransitions)));
 record('social_transitions',{transitions});
 assert.ok(transitions.every(list=>list.some(t=>t.before.epoch===1&&t.after.epoch===2&&t.after.scope===2)),'telemetry scope transition');
 assert.ok(transitions.some(list=>list.some(t=>t.before.epoch===1&&t.after.epoch===2&&t.before.mark_ttl>t.after.at-t.before.at&&t.after.marks.length===0)),'old marker retired before expiry at migration');
 console.log('REPLAY_CAVE_SOCIAL_MIGRATION_DETAIL_OK');
 await guest.page.screenshot({path:`${logs}/recovered.png`});
 if(process.env.RCB_SOCIAL==='1'){await command(guest,'presentation_ping');await until(()=>has(guest,'RCB_SOCIAL_PING_DRAWN'),'visible social marker');await guest.page.screenshot({path:`${logs}/ping.png`});}
 if(process.env.RCB_LOBBY==='1'){assert.ok(has(guest,'RCB_LOBBY_STARTED'));}
 if(process.env.RCB_PROFILE_ROOT&&process.env.RCB_LOBBY==='1'){guest.killed=true;await guest.browser.close();const profile=await open(3,false,true);await until(()=>has(profile,'RCB_PROFILE_RELOAD_OK'),'fresh browser profile reload');await wait(100);await profile.page.screenshot({path:`${logs}/menu.png`});}
 record('complete');console.log(`REPLAY_CAVE_WEB_${mode.toUpperCase()}_OK`);
 }
}finally{
 fs.writeFileSync(`${logs}/events.json`,JSON.stringify(events,null,2));
 await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));
}
process.exit(0);
