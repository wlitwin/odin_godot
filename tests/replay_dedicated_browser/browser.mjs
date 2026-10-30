import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [base,control,mode,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const peers=[],shared={},events=[];const start=performance.now();let killed=false,returned=false;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const record=(event,detail={})=>events.push({event,ms:Math.round(performance.now()-start),...detail});
async function open(member,isReturn=false){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
 const page=await browser.newPage(),p={member,browser,page,killed:false,errors:[],lines:[],name:isReturn?'returned':String(member)};peers.push(p);record('open',{member,returned:isReturn,pid:browser.process().pid});
 await page.evaluateOnNewDocument(()=>{globalThis.dedLocal={};globalThis.dedShared={};const Native=globalThis.RTCPeerConnection;globalThis.dedRtc=[];globalThis.RTCPeerConnection=class extends Native{constructor(...args){super(...args);globalThis.dedRtc.push(this);}};});
 page.on('console',async m=>{const text=m.text();if(m.type()==='error'){for(const a of m.args()){const detail=await a.evaluate(v=>String(v?.stack||v?.message||v)).catch(()=>text);p.errors.push(detail);fs.appendFileSync(out+'/'+p.name+'.log',detail+'\n');}}p.lines.push(text);fs.appendFileSync(out+'/'+p.name+'.log',text+'\n');if(/DEDICATED_ROOM_FAIL|SCRIPT ERROR|ERROR:/.test(text))p.errors.push(text);if(/DEDICATED_ROOM_(RESTORED|TRIGGER|OK)/.test(text)){record('receipt',{member,text});console.log(member,text);}});page.on('pageerror',e=>p.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({member:String(member),control,mode});await page.goto(url.href,{waitUntil:'domcontentloaded'});return p;
}
async function pump(){
 for(const p of peers.filter(p=>!p.killed)){
  assert.equal(p.errors.length,0,p.errors.join('\n'));
  const marks=await p.page.evaluate(()=>globalThis.dedLocal||{});
  for(const [name,value] of Object.entries(marks))if(value&&!shared[name]){shared[name]=true;record('mark',{member:p.member,name});}
 }
 for(const p of peers.filter(p=>!p.killed))await p.page.evaluate(value=>{globalThis.dedShared=value;},shared);
}
async function until(check,label,ms=130000){const end=performance.now()+ms;while(performance.now()<end){await pump();if(check())return;await pause(50);}throw Error('Timeout '+label);}
try{
 assert.ok(['planned','crash','repeat'].includes(mode));
 for(let member=1;member<=4;member++){await open(member);await until(()=>shared['admitted-'+member],'admission '+member,60000);}
 const end=performance.now()+150000;
 while(performance.now()<end){
  await pump();
  if(mode==='crash'&&!killed&&shared['kill-owner']){
   const p=peers.find(p=>p.member===1);p.killed=true;killed=true;record('kill',{member:1});const process=p.browser.process();await new Promise(resolve=>{process.once('exit',resolve);process.kill('SIGKILL');});
  }
  if(killed&&!returned&&shared['ready-2-2']){returned=true;await open(1,true);}
  if([1,2,3,4].every(m=>shared['finished-'+m]))break;
  await pause(50);
 }
 assert.ok([1,2,3,4].every(m=>shared['finished-'+m]),'all final acknowledgements');
 const epoch=mode==='repeat'?3:2,authority=mode==='repeat'?1:2,rtc=[];
 for(const p of peers.filter(p=>!p.killed)){
  const expected=`DEDICATED_ROOM_OK member=${p.member} epoch=${epoch} seat=${p.member<=2?0:p.member-2} authority=${p.member===authority?'true':'false'} role=${p.member===authority?'Server':p.member<=2?'Observer':'Client'} avatars=2`;
  assert.ok(p.lines.includes(expected),expected);
  let observed;const deadline=performance.now()+10000;
  do{
   observed=await p.page.evaluate(async()=>{const rows=[],states=[];for(const pc of globalThis.dedRtc||[]){states.push({connection:pc.connectionState,ice:pc.iceConnectionState});if(pc.connectionState!=='connected')continue;const stats=await pc.getStats();for(const x of stats.values())if(x.type==='candidate-pair'&&x.state==='succeeded')rows.push({state:pc.connectionState,bytesSent:x.bytesSent,bytesReceived:x.bytesReceived});}return {rows,states};});
   record('rtc_observation',{member:p.member,...observed});
   if(observed.rows.some(x=>x.bytesSent>0&&x.bytesReceived>0))break;
   await pump();await pause(100);
  }while(performance.now()<deadline);
  assert.ok(observed.rows.some(x=>x.bytesSent>0&&x.bytesReceived>0),'real RTC traffic member '+p.member+' '+JSON.stringify(observed));rtc.push({member:p.member,...observed});
 }
 if(mode==='crash')assert.ok(killed&&returned);
 assert.ok(peers.filter(p=>!p.killed).some(p=>p.lines.some(x=>x.startsWith('DEDICATED_ROOM_RESTORED'))));
 await peers.find(p=>!p.killed&&p.member===authority).page.screenshot({path:out+'/authority.png'});
 shared['exit-all']=true;await pump();await pause(150);
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,mode,epoch,authority,returned,avatars:2,infrastructure_seats:[0,0],player_seats:[1,2],rtc},null,2));
 console.log('REPLAY_DEDICATED_BROWSER_OK',mode);
}finally{
 fs.writeFileSync(out+'/events.json',JSON.stringify(events,null,2));await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));
}

process.exit(0);
