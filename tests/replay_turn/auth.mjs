import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {relayConfig,installRelayProbe,relayPairs,requireRelay} from './probe.mjs';
const [base,service,logs]=process.argv.slice(2),config=relayConfig();fs.mkdirSync(logs,{recursive:true});const agents=[],observations=[];let command=0;
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function open(role,ice,profile){const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:logs+'/'+profile,protocolTimeout:15000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});const page=await browser.newPage(),a={browser,page,role,errors:[]};agents.push(a);await installRelayProbe(page,ice);page.on('console',m=>{const text=m.text();fs.appendFileSync(logs+'/'+role+'.log',text+'\n');if(/SCRIPT ERROR|REPLAY_CAVE_FAIL/.test(text))a.errors.push(text);});page.on('pageerror',e=>a.errors.push(String(e)));const url=new URL(base);url.search=new URLSearchParams({online_test:role,room_service:service,room_local:'1',persist:'0'});await page.goto(url.href,{waitUntil:'domcontentloaded'});await until(a,s=>s.recent===1&&s.profile_ready===1,'menu');return a;}
async function until(a,predicate,label){const end=Date.now()+25000;let state;while(Date.now()<end){assert.deepEqual(a.errors,[]);state=await a.page.evaluate(()=>globalThis.onlineStatus||null);if(state){assert.equal(state.failed,0,state.notice);if(predicate(state))return state;}await pause(60);}throw Error(`${a.role}: ${label}`);}
async function send(a,kind,value){const id=++command;await a.page.evaluate(q=>{globalThis.onlineCommand=q;},{id,kind,value});return until(a,s=>s.command===id,kind);}
try{
 const host=await open('host',config,'host-profile');await send(host,'press','Host');const issued=await until(host,s=>s.invited===1&&s.ready,'created');
 const wrong=structuredClone(config);wrong.iceServers[0].credential='deliberately-wrong-fixture-password';let guest=await open('bad',wrong,'guest-profile');await send(guest,'invite',issued.invite);await send(guest,'press','Join');
 const deadline=Date.now()+15000;let failure=[];
 while(Date.now()<deadline){failure=await guest.page.evaluate(()=>globalThis.replayTestIceErrors||[]);if(failure.length)break;await pause(100);}
 assert.ok(failure.length,'no TURN authentication error observed');
 await pause(2000);
 const rejected=await guest.page.evaluate(()=>({state:globalThis.onlineStatus,peers:globalThis.replayTestPeers.map(p=>({state:p.connectionState,policy:p.getConfiguration().iceTransportPolicy})),errors:globalThis.replayTestIceErrors}));
 assert.equal(rejected.state.ready,false);assert.ok(!rejected.peers.some(p=>p.state==='connected'));assert.equal((await relayPairs(guest.page)).length,0);
 delete rejected.state.invite;observations.push({stage:'bad-credentials',...rejected});
 await guest.browser.close();
 guest=await open('corrected',config,'guest-profile');await send(guest,'press','Rejoin');await until(guest,s=>s.ready&&s.players===2&&s.incarnation>=3,'credential recovery');
 await requireRelay(guest.page,observations,'corrected-relay');await requireRelay(host.page,observations,'host-after-correction');
 console.log('REPLAY_TURN_AUTH_OK bad_password_no_direct_fallback=true stored_member_rejoined=true');
}finally{fs.writeFileSync(logs+'/auth.json',JSON.stringify(observations,null,2));for(const a of agents)if(a.browser.connected)await a.browser.close();}
process.exit(0);
