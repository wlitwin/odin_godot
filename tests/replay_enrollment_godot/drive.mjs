import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const base=process.argv[2],service=process.argv[3],logs=process.env.ENROLLMENT_BROWSER_LOGS;
fs.mkdirSync(logs,{recursive:true});const profile=path.join(logs,'chrome-profile');let browser;const results={};
async function launch(){browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:profile,headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});}
async function kill(){const proc=browser.process();const exited=new Promise(r=>proc.once('exit',r));proc.kill('SIGKILL');await exited;}
async function page(name,slot='active',stage=0,room=44,abort=false){
 const page=await browser.newPage();page.lines=[];page.errors=[];
 page.on('console',m=>{const text=m.text();page.lines.push(text);fs.appendFileSync(path.join(logs,`${name}.log`),text+'\n');if(/SCRIPT ERROR|ERROR:/.test(text))page.errors.push(text);});
 page.on('pageerror',e=>page.errors.push(String(e)));
 if(abort)await page.evaluateOnNewDocument(()=>{const put=IDBObjectStore.prototype.put;let done=false;IDBObjectStore.prototype.put=function(value,...args){const r=put.call(this,value,...args);if(!done&&this.name==='blobs'&&value.revision===2){done=true;this.transaction.abort();}return r;};});
 const url=new URL(base);for(const [k,v]of Object.entries({ENROLLMENT_URL:service,ENROLLMENT_SLOT:slot,ENROLLMENT_STAGE:stage,ENROLLMENT_ROOM:room}))url.searchParams.set(k,String(v));
 await page.goto(url.href,{waitUntil:'domcontentloaded'});return page;
}
async function until(page,marker){await page.bringToFront();const end=Date.now()+25000;while(Date.now()<end&&!page.lines.some(x=>x.includes(marker))&&!page.errors.length)await new Promise(r=>setTimeout(r,50));assert.deepEqual(page.errors,[]);assert.ok(page.lines.some(x=>x.includes(marker)),page.lines.join('\n'));return page.lines.find(x=>x.includes(marker));}
async function go(page){await page.bringToFront();await page.evaluate(()=>{globalThis.enrollmentGo=true;});}
function field(page,key){const line=page.lines.find(x=>x.includes(`${key}=`));assert.ok(line,page.lines.join('\n'));return line.slice(line.indexOf(`${key}=`)+key.length+1);}
async function stored(page,key){return await page.evaluate(async key=>{
 const value=await new Promise((resolve,reject)=>{const open=indexedDB.open('replay/replay-enrollment-fixture',1);open.onerror=()=>reject(open.error);open.onsuccess=()=>{const db=open.result,tx=db.transaction('blobs','readonly'),get=tx.objectStore('blobs').get(key);get.onsuccess=()=>resolve(get.result);get.onerror=()=>reject(get.error);tx.oncomplete=()=>db.close();};});
 if(!value)return null;
 const bytes=await value.bytes.arrayBuffer();const digest=await crypto.subtle.digest('SHA-256',bytes);
 return {revision:value.revision,size:bytes.byteLength,hash:Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('')};
},key);}
async function corrupt(page,key){await page.evaluate(async key=>{await new Promise((resolve,reject)=>{const open=indexedDB.open('replay/replay-enrollment-fixture',1);open.onsuccess=()=>{const db=open.result,tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').put({revision:1,bytes:new Blob([new Uint8Array(8)])},key);tx.oncomplete=()=>{db.close();resolve();};tx.onabort=()=>reject(tx.error);};open.onerror=()=>reject(open.error);});},key);}

try{
 await launch();let a=await page('pending','active',1);await until(a,'ENROLLMENT_REQUEST_STORED');
 results.request=field(a,'request');results.pending=await stored(a,'active');assert.equal(results.pending.revision,1);
 await kill();await launch();a=await page('after-request-kill');await until(a,'ENROLLMENT_OK revision=2 connected=true');
 results.fingerprint=field(a,'fingerprint');assert.equal(field(a,'request'),results.request);results.ready=await stored(a,'active');assert.equal(results.ready.revision,2);
 await kill();await launch();a=await page('after-ready-kill');await until(a,'ENROLLMENT_OK revision=2 connected=false');
 assert.equal(field(a,'fingerprint'),results.fingerprint);assert.deepEqual(await stored(a,'active'),results.ready);

 // A real aborted grant write retains the durable pending request. Two fresh
 // tabs then load that same revision before either completes its retry.
 const aborted=await page('aborted-grant','abort',0,45,true);await until(aborted,'ENROLLMENT_FAIL profile Store connected=true');
 results.aborted=await stored(aborted,'abort');assert.equal(results.aborted.revision,1);
 const first=await page('grant-winner','abort',1,45);await until(first,'ENROLLMENT_REQUEST_STORED');
 const second=await page('grant-loser','abort',1,45);await until(second,'ENROLLMENT_REQUEST_STORED');
 assert.equal(field(first,'request'),field(second,'request'));
 await go(first);await until(first,'ENROLLMENT_OK revision=2 connected=true');results.recovered=await stored(first,'abort');
 await go(second);await until(second,'ENROLLMENT_FAIL profile Conflict connected=true');assert.deepEqual(await stored(second,'abort'),results.recovered);

 // Both creators observed an absent slot; the loser never reaches networking.
 const ca=await page('create-winner','race',6),cb=await page('create-loser','race',6);
 await until(ca,'ENROLLMENT_EMPTY');await until(cb,'ENROLLMENT_EMPTY');
 await go(ca);await until(ca,'ENROLLMENT_REQUEST_STORED');results.race=await stored(ca,'race');
 await go(cb);await until(cb,'ENROLLMENT_FAIL profile Conflict connected=false');assert.deepEqual(await stored(cb,'race'),results.race);
 await corrupt(a,'corrupt');const before=await stored(a,'corrupt');
 const bad=await page('corrupt','corrupt');await until(bad,'ENROLLMENT_FAIL profile Corrupt connected=false');assert.deepEqual(await stored(bad,'corrupt'),before);
 console.log('REPLAY_ENROLLMENT_BROWSER_OK request_and_ready_survive_sigkill=true aborted_grant_preserves_pending=true stale_tabs_conflict=true corrupt_kept=true');
}finally{fs.writeFileSync(path.join(logs,'results.json'),JSON.stringify(results,null,2));if(browser?.connected)await browser.close();}
