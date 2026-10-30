import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const base=process.argv[2],logs=process.env.BROWSER_STORE_LOGS;fs.mkdirSync(logs,{recursive:true});
const profile=`${logs}/chrome-profile`;let browser,sequence=0;const receipts=[];
function expectedHash(size,pattern){let h=0xcbf29ce484222325n;for(let i=0;i<size;i++)h=BigInt.asUintN(64,(h^BigInt((i*31+pattern)%251))*0x100000001b3n);return String(h&0x7fffffffffffffffn);}
async function launch(){browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:profile,headless:true,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist']});return browser;}
async function page(name){const p=await browser.newPage();p.errors=[];p.on('console',m=>{fs.appendFileSync(`${logs}/${name}.log`,m.text()+'\n');if(/SCRIPT ERROR|ERROR:/.test(m.text()))p.errors.push(m.text());});p.on('pageerror',e=>p.errors.push(String(e)));await p.goto(base,{waitUntil:'domcontentloaded'});return p;}
async function request(p,options){await p.bringToFront();const id=++sequence;await p.evaluate(r=>{globalThis.storeRequest=r;},{id,reading:true,key:'record',expected:0,size:0,pattern:0,limit:1048576,...options});await p.waitForFunction(id=>globalThis.storeResult?.id===id&&globalThis.storeResult.phase===2,{timeout:15000},id);const r=await p.evaluate(()=>globalThis.storeResult);assert.deepEqual(p.errors,[]);receipts.push(r);return r;}
async function inject(p,key,value){await p.evaluate(async({key,value})=>{await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/acceptance',1);r.onsuccess=()=>{const db=r.result,tx=db.transaction('blobs','readwrite');tx.objectStore('blobs').put(value,key);tx.oncomplete=()=>{db.close();resolve();};tx.onabort=()=>reject(tx.error);};r.onerror=()=>reject(r.error);});},{key,value});}
try{
 await launch();let a=await page('first');
 assert.equal((await request(a,{})).error,1);
 let r=await request(a,{reading:false,size:1048576,pattern:7});assert.equal(r.error,0);assert.equal(r.revision,1);
 const original=await request(a,{});assert.equal(original.error,0);assert.equal(original.size,1048576);
 assert.equal(original.hash,expectedHash(1048576,7));
 // Close the whole browser after the completion receipt, then reopen its disk profile.
 await browser.close();await launch();a=await page('reopened');r=await request(a,{});assert.equal(r.hash,original.hash);assert.equal(r.revision,1);
 const b=await page('second-tab');
 assert.equal((await request(b,{})).revision,1);
 // Both tabs read revision 1. Focus each while its Godot loop submits/polls;
 // Chrome suspends animation frames in a hidden tab.
 const raced=[await request(a,{reading:false,expected:1,size:1048576,pattern:8}),await request(b,{reading:false,expected:1,size:1048576,pattern:9})];
 assert.deepEqual(raced.map(r=>r.error).sort(),[0,2]);r=await request(a,{});assert.equal(r.revision,2);assert.notEqual(r.hash,original.hash);const winner=r;
 assert.equal((await request(a,{reading:false,expected:1,size:64})).error,2);
 assert.equal((await request(a,{limit:16})).error,3);
 assert.equal((await request(a,{reading:false,expected:2,size:100,limit:16})).error,3);
 r=await request(a,{});assert.equal(r.revision,2);assert.equal(r.hash,winner.hash);
 await inject(a,'corrupt',{revision:0,bytes:'broken'});assert.equal((await request(a,{key:'corrupt'})).error,4);
 assert.equal((await request(a,{reading:false,key:'corrupt',size:16})).error,4);
 // An actual aborted IndexedDB write must retain the old complete record.
 await a.evaluate(()=>{globalThis.abortStoreWrite=true;const original=IDBObjectStore.prototype.put;IDBObjectStore.prototype.put=function(...args){const r=original.apply(this,args);if(globalThis.abortStoreWrite&&this.name==='blobs'){globalThis.abortStoreWrite=false;this.transaction.abort();}return r;};});
 assert.equal((await request(a,{reading:false,expected:2,size:1048576,pattern:10})).error,7);
 r=await request(a,{});assert.equal(r.revision,2);assert.equal(r.hash,winner.hash);
 // A synchronous API failure can leave an empty transaction to complete later.
 // Its completion must not turn the failed operation into a successful save.
 await a.evaluate(()=>{globalThis.failStoreGet=true;const get=IDBObjectStore.prototype.get;IDBObjectStore.prototype.get=function(...args){if(globalThis.failStoreGet&&this.name==='blobs'){globalThis.failStoreGet=false;throw new Error('injected get failure');}return get.apply(this,args);};});
 assert.equal((await request(a,{reading:false,expected:2,size:64})).error,7);
 r=await request(a,{});assert.equal(r.revision,2);assert.equal(r.hash,winner.hash);
 // Killing a browser after receipt must also preserve that committed record.
 browser.process().kill('SIGKILL');await new Promise(resolve=>browser.process().once('exit',resolve));await launch();a=await page('after-kill');r=await request(a,{});assert.equal(r.revision,2);assert.equal(r.hash,winner.hash);
 const maximum=16*1024*1024;
 r=await request(a,{reading:false,key:'maximum',size:maximum,pattern:17,limit:maximum});assert.equal(r.error,0);
 r=await request(a,{key:'maximum',limit:maximum});assert.equal(r.size,maximum);assert.equal(r.hash,expectedHash(maximum,17));
 console.log('REPLAY_BROWSER_STORE_OK');
}finally{fs.writeFileSync(`${logs}/receipts.json`,JSON.stringify(receipts,null,2));if(browser?.connected)await browser.close();}
