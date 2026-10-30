import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,logs]=process.argv.slice(2), namespace='cave-save-regression';
fs.mkdirSync(logs,{recursive:true});let browser;const pages=[];const events=[];
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function launch(){browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:logs+'/profile',protocolTimeout:20000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});}
async function open(mode,expected,ns=namespace){
 const page=await browser.newPage(),p={page,mode,namespace:ns,errors:[]};pages.push(p);const index=pages.length;
 page.on('console',m=>{const line=m.text();fs.appendFileSync(`${logs}/${mode}-${index}.log`,line+'\n');if(/^CAVE_BROWSER_SAVE_FAIL(?: |$)|SCRIPT ERROR|ERROR:/.test(line))p.errors.push(line);});page.on('pageerror',e=>p.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({save_test:mode,persist:mode==='identity'?'0':'1',profile_namespace:ns,...(mode==='create'?{name:'Vault Runner'}:{}),...(expected?{expected_tick:expected.tick,expected_hash:expected.hash}:{})});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});return p;
}
async function until(p,event){
 await p.page.bringToFront();const end=Date.now()+50000;
 while(Date.now()<end){assert.equal(p.errors.length,0,p.errors.join('\n'));const result=await p.page.evaluate(()=>globalThis.caveSaveResult||null);if(result?.event===event){events.push({mode:p.mode,...result});return result;}await pause(50);}
 throw Error(`timeout ${p.mode}/${event}`);
}
async function command(p,name){await p.page.bringToFront();await p.page.evaluate(command=>{globalThis.caveSaveResult=null;globalThis.caveSaveCommand=command;},name);}
async function records(p){return p.page.evaluate(async ns=>{
 const db=await new Promise((resolve,reject)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
 try {const list=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),store=tx.objectStore('blobs'),q=store.getAll(),keys=store.getAllKeys();tx.oncomplete=()=>resolve(q.result.map((v,i)=>({key:keys.result[i],revision:v.revision,blob:v.bytes})));tx.onerror=()=>reject(tx.error);});const result=[];for(const r of list){const data=new Uint8Array(await r.blob.arrayBuffer());const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',data));result.push({key:r.key,revision:r.revision,bytes:Array.from(data),hash:Array.from(digest,b=>b.toString(16).padStart(2,'0')).join('')});}return result;}finally{db.close();}
 },p.namespace||namespace);}
async function replace(p,key,bytes,revision){await p.page.evaluate(async ({ns,key,bytes,revision})=>{const db=await new Promise((r,j)=>{const q=indexedDB.open('replay/'+ns,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});try{await new Promise((r,j)=>{const tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').put({revision,bytes:new Blob([new Uint8Array(bytes)])},key);tx.oncomplete=r;tx.onabort=()=>j(tx.error);});}finally{db.close();}}, {ns:namespace,key,bytes,revision});}
try {
 await launch();
 const race=await Promise.all([open('identity',undefined,'cave-save-identity-race'),open('identity',undefined,'cave-save-identity-race')]);
 const identities=[];for(const p of race)identities.push(await until(p,'identity_ready'));assert.equal(identities[0].slot,identities[1].slot);assert.ok(identities[0].slot.startsWith('save/'));
 for(const p of race)await p.page.close();
 let created=await open('create');const initial=await until(created,'saved');assert.equal(initial.revision,'1');
 const original=(await records(created));const identity=original.find(r=>r.key==='identity');assert.equal(identity.bytes.length,16);assert.ok(identity.bytes.some(x=>x!==0));
 await created.page.screenshot({path:logs+'/saved.png'});
 // Kill after the actual IndexedDB completion receipt, not after submission.
 const process=browser.process();process.kill('SIGKILL');while(process.signalCode===null)await pause(20);await pause(250);
 await launch();const resumed=await open('resume',initial);const second=await until(resumed,'saved');assert.equal(second.restored_hash,initial.hash);assert.equal(second.restored_tick,initial.tick);assert.equal(second.revision,'2');assert.equal(second.epoch,2);
 assert.equal((await records(resumed)).find(r=>r.key==='identity').hash,identity.hash);await resumed.page.close();
 const a=await open('idle',second);await until(a,'resumed');const b=await open('idle',second);await until(b,'resumed');
 await command(a,'save');const winner=await until(a,'saved');assert.equal(winner.revision,'3');const committed=(await records(a)).find(r=>r.key.startsWith('save/'));
 await command(b,'save');const stale=await until(b,'write_failed');assert.equal(stale.store_error,2);const after=(await records(b)).find(r=>r.key===committed.key);assert.equal(after.hash,committed.hash);assert.equal(after.revision,committed.revision);
 await a.page.close();await b.page.close();
 const control=await browser.newPage();await control.goto(base+"?persist=0&token=fixture-control&profile_namespace="+namespace);const ctl={page:control};
 await replace(ctl,committed.key,[1,2,3,4],committed.revision);
 const corrupt=await open('bad_archive');const failed=await until(corrupt,'archive_failed');assert.equal(failed.slot_error,2);await command(corrupt,'solo');await pause(500);await command(corrupt,'save');await until(corrupt,'submit_refused');assert.deepEqual((await records(corrupt)).find(r=>r.key===committed.key).bytes,[1,2,3,4]);await corrupt.page.close();
 await replace(ctl,committed.key,committed.bytes,committed.revision);
 await replace(ctl,'identity',Array(16).fill(0),identity.revision);
 const badIdentity=await open('bad_identity');await until(badIdentity,'identity_failed');await command(badIdentity,'solo');await pause(500);await command(badIdentity,'status');const denied=await until(badIdentity,'status');assert.equal(denied.identity_error,4);assert.equal(denied.runner_ready,false);assert.deepEqual((await records(badIdentity)).find(r=>r.key==='identity').bytes,Array(16).fill(0));await badIdentity.page.close();
 await replace(ctl,'identity',identity.bytes,identity.revision);await control.close();
 fs.writeFileSync(logs+'/summary.json',JSON.stringify({events,identity_creation_agreed:true,identity_preserved:true,stale_writer_preserved_archive:true,corrupt_archive_preserved:true,corrupt_identity_preserved:true},null,2));console.log('REPLAY_CAVE_BROWSER_SAVE_OK');
} finally {if(browser?.connected)await browser.close();}
