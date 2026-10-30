import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,control,mode,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});const peers=[],events=[];
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function open(member){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:out+'/profile-'+member,protocolTimeout:20000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--disable-background-timer-throttling']});
 const page=await browser.newPage(),p={member,browser,page,errors:[],dead:false};peers.push(p);
 page.on('console',m=>{const line=m.text();fs.appendFileSync(out+'/member-'+member+'.log',line+'\n');if(/REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:/.test(line))p.errors.push(line)});page.on('pageerror',e=>p.errors.push(String(e)));
 await page.evaluateOnNewDocument(()=>{globalThis.modRtc=[];const Base=globalThis.RTCPeerConnection;globalThis.RTCPeerConnection=class extends Base {constructor(...a){super(...a);globalThis.modRtc.push(this)}}});
 const url=new URL(base);url.search=new URLSearchParams({member:String(member),incarnation:String(100+member),coord_key:(20+member).toString(16).padStart(2,'0')+'00'.repeat(31),coord_url:control,token:'browser-room-'+member,role:member===1?'host':'client',persist:'0',latency:'120'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});return p;
}
async function state(p){assert.equal(p.errors.length,0,p.errors.join('\n'));return p.page.evaluate(()=>globalThis.moderationState||null)}
async function until(p,predicate,label){const end=Date.now()+35000;while(Date.now()<end){const s=await state(p);if(s&&predicate(s)){events.push({label,member:p.member,state:s});return s}await pause(50)}throw Error(label+': '+JSON.stringify(await state(p)))}
async function rtcStats(p){return p.page.evaluate(async()=>{const rows=[];for(const peer of globalThis.modRtc){const stats=await peer.getStats();for(const r of stats.values())if(r.type==='data-channel')rows.push({state:r.state,tx:r.bytesSent,rx:r.bytesReceived})}return rows})}
async function command(p,value){await p.page.evaluate(v=>globalThis.moderationCommand=v,value)}
try {
 const host=await open(1);await until(host,s=>s.ready,'host');
 const banned=await open(2);await until(banned,s=>s.ready&&s.players===2,'second');
 const successor=await open(3);await until(successor,s=>s.ready&&s.players===3,'third');
 await command(banned,'guest_remove');await pause(300);assert.equal((await state(host)).players,3);
 await until(host,s=>s.nominee===2&&s.prepared===1,'prepared target');
 const rtcBefore=await Promise.all(peers.map(async p=>({member:p.member,stats:await rtcStats(p)})));
 for(const p of rtcBefore)assert.ok(p.stats.some(r=>r.tx>0&&r.rx>0));events.push({label:'rtc-before',peers:rtcBefore});
 await command(host,'remove');
 await until(banned,s=>s.removed===1&&!s.ready,'removed');
 await until(host,s=>s.removal_phase===3&&s.enabled2===0&&s.players===2&&s.bans===1,'durable removal');
 await until(host,s=>s.nominee===3&&s.prepared===1,'replacement prepared');
 if(mode==='crash'){host.dead=true;host.browser.process().kill('SIGKILL')}else await command(host,'handoff');
 await until(successor,s=>s.ready&&s.epoch===2&&s.owner===3&&s.enabled2===0&&s.bans===1,'takeover');
 await command(successor,'walk');await until(successor,s=>s.near,'movement');await command(successor,'loot');await until(successor,s=>s.bag===3,'loot');
 if(mode==='planned')await until(host,s=>s.ready&&s.epoch===2&&s.owner===3,'old host returned');
 const rtc=await rtcStats(successor);if(mode==='planned')assert.ok(rtc.some(r=>r.tx>0&&r.rx>0));
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,mode,events,rtc},null,2)+'\n');console.log('REPLAY_CAVE_MODERATION_BROWSER_OK',mode);
} finally {for(const p of peers)if(!p.dead)await p.browser.close();fs.writeFileSync(out+'/events.json',JSON.stringify(events,null,2)+'\n')}
