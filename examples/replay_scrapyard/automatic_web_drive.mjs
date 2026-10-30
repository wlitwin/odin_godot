import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,control,logs]=process.argv.slice(2);fs.mkdirSync(logs,{recursive:true});
const peers=[],events=[];let serial=0;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function open(mode,subject=true){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:`${logs}/${subject?'subject':mode}-profile`,headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});const peer={browser,page,mode,errors:[]};peers.push(peer);
 page.on('console',m=>{const text=m.text();fs.appendFileSync(`${logs}/${mode}.log`,text+'\n');if(/RSY_PROFILE_ERROR|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(text))peer.errors.push(text);});page.on('pageerror',e=>peer.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({ui_test:'1',role:subject?(mode==='reseated'?'client':'solo'):(mode==='helper'?'client':'host'),token:subject?'browser-room-2':mode==='helper'?'browser-room-3':'browser-room-1',persist:subject?'1':'0',profile_namespace:'scrapyard-auto-acceptance',name:subject?'Auto Subject':'Host',run:'0',mobs:'0',audio:'0'});
 if(mode==='reseated'||!subject){const member=subject?2:mode==='helper'?3:1;for(const [key,value] of Object.entries({member:String(member),incarnation:String(member+100),coord_key:(member+20).toString(16).padStart(2,'0')+'00'.repeat(31),coord_url:control}))url.searchParams.set(key,value);}
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 await until(peer,s=>s.ready&&s.chat_ready,'ready');return peer;
}
async function state(peer){
 assert.deepEqual(peer.errors,[]);
 const id=++serial;await peer.page.evaluate(id=>{globalThis.uiQuery=id;},id);
 await peer.page.waitForFunction(id=>globalThis.uiState?.query===id,{timeout:60000},id);
 const s=await peer.page.evaluate(()=>globalThis.uiState);assert.equal(s.muster.profile_error,0);return s;
}
async function until(peer,predicate,label){const end=Date.now()+45000;let s;while(Date.now()<end){s=await state(peer);if(predicate(s)){events.push({mode:peer.mode,label,state:s});return s;}await pause(60);}throw Error(`${peer.mode} ${label} ${JSON.stringify(s)}`);}
function saved(s,mask){return s.muster.profile_loaded&&s.muster.saved_automatic===mask&&!s.muster.profile_writing;}
async function pick(peer,path){
 const id=++serial;await peer.page.evaluate(command=>{globalThis.uiCommand=command;},{id,kind:'muster_focus',path});
 await peer.page.waitForFunction(id=>globalThis.uiAck?.id===id,{timeout:10000},id);
 const s=await state(peer),b=s.muster.buttons[path];assert.ok(b.visible&&!b.disabled);
 const box=await (await peer.page.$('canvas')).boundingBox(),[x,y,w,h]=b.box;
 await peer.page.mouse.click(box.x+(x+w/2)*box.width/s.viewport[0],box.y+(y+h/2)*box.height/s.viewport[1],{delay:100});
}
async function record(peer){return peer.page.evaluate(async()=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/scrapyard-auto-acceptance',1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 const rows=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),s=tx.objectStore('blobs'),k=s.getAllKeys(),v=s.getAll();tx.oncomplete=()=>resolve({keys:k.result,values:v.result});tx.onabort=()=>reject(tx.error);});
 const at=rows.keys.findIndex(k=>k.startsWith('profile-'));if(at<0)throw Error('profile missing');
 const value=rows.values[at],bytes=new Uint8Array(await value.bytes.arrayBuffer());db.close();
 return {key:rows.keys[at],revision:value.revision,automatic:bytes.at(-1),hash:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('')};
});}
const receipts={};
try{
 let subject=await open('created');
 const initial=await until(subject,s=>saved(s,15),'initial-auto');assert.equal(initial.seat,1);assert.equal(initial.players_state[0].look,1);assert.equal(initial.players_state[0].iron,0);
 for(const [field,next,prev] of [[0,'Picks/Look','Picks/LookPrev'],[1,'Picks/Iron','Picks/IronPrev'],[2,'Abilities/Left','Abilities/LeftPrev'],[3,'Abilities/Right','Abilities/RightPrev']]){
  await pick(subject,next);await until(subject,s=>saved(s,15&~(1<<field)),'explicit-commit');
  await pick(subject,prev);await until(subject,s=>saved(s,15),'auto-commit');
 }
 receipts.automatic=await record(subject);assert.equal(receipts.automatic.automatic,15);
 await subject.page.screenshot({path:`${logs}/automatic.png`});await subject.browser.close();
 const host=await open('host',false);subject=await open('reseated');
 const reseated=await until(subject,s=>s.seat===2&&s.players_state[1].look===2&&s.players_state[1].iron===1&&saved(s,15),'new-seat-defaults');
 assert.equal(reseated.muster.automatic,15);
 const helper=await open('helper',false);await until(helper,s=>s.players_state[1].look===2&&s.players_state[1].iron===1,'replicated-automatic');
 receipts.reseated=await record(subject);assert.equal(receipts.reseated.key,receipts.automatic.key);
 await pick(subject,'Picks/LookPrev');await until(subject,s=>saved(s,14),'explicit-skin');
 await pick(subject,'Picks/IronPrev');await pick(subject,'Picks/IronPrev');await until(subject,s=>s.players_state[1].iron===5&&saved(s,12),'explicit-iron');
 for(let i=0;i<5;i++)await pick(subject,'Abilities/Left');
 await until(subject,s=>s.players_state[1].ability0===5&&saved(s,8),'explicit-q');
 for(let i=0;i<6;i++)await pick(subject,'Abilities/Right');
 await until(subject,s=>s.players_state[1].ability1===6&&saved(s,0),'explicit-e');
 await until(helper,s=>s.players_state[1].look===2&&s.players_state[1].iron===5&&s.players_state[1].ability0===5&&s.players_state[1].ability1===6,'replicated-explicit');
 receipts.explicit=await record(subject);await subject.browser.close();
 subject=await open('explicit-reload');const loaded=await until(subject,s=>saved(s,0),'explicit-reloaded');
 assert.equal(loaded.seat,1);assert.equal(loaded.players_state[0].look,2);assert.equal(loaded.players_state[0].iron,5);assert.equal(loaded.players_state[0].ability0,5);assert.equal(loaded.players_state[0].ability1,6);
 receipts.reloaded=await record(subject);assert.deepEqual(receipts.reloaded,receipts.explicit);
 console.log('REPLAY_SCRAPYARD_AUTOMATIC_WEB_OK fresh_process=true new_seat=true explicit_fixed=true idb_commits=true');
}finally{
 fs.writeFileSync(`${logs}/events.json`,JSON.stringify(events,null,2));fs.writeFileSync(`${logs}/records.json`,JSON.stringify(receipts,null,2));
 await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));
}
process.exit(0);
