import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const base=process.argv[2],logs=process.env.RSB_SETTINGS_LOGS;fs.mkdirSync(logs,{recursive:true});let browser;const receipts=[];
async function open(mode){
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:`${logs}/chrome-profile`,headless:true,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});page.lines=[];page.errors=[];
 page.on('console',m=>{const line=m.text();page.lines.push(line);fs.appendFileSync(`${logs}/${mode}.log`,line+'\n');if(/RSY_BROWSER_SETTINGS/.test(line))console.log(line);if(/RSY_BROWSER_SETTINGS_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(line))page.errors.push(line);});page.on('pageerror',e=>page.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({role:'solo',persist:'1',profile_namespace:'scrapyard-settings-acceptance',settings_test:mode,mobs:'0',run:'0'});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await page.bringToFront();return page;
}
async function receipt(page,prefix){const end=performance.now()+65000;while(performance.now()<end){assert.deepEqual(page.errors,[]);const line=page.lines.find(x=>x.startsWith(prefix));if(line){receipts.push(line);return;}await new Promise(r=>setTimeout(r,50));}throw new Error(`timeout ${prefix}`);}
async function record(page,change=''){
 return page.evaluate(async change=>{
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/scrapyard-settings-acceptance',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const value=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),r=tx.objectStore('blobs').get('settings');tx.oncomplete=()=>resolve(r.result);tx.onabort=()=>reject(tx.error);});
  if(!value)throw new Error('no committed settings');const bytes=new Uint8Array(await value.bytes.arrayBuffer());
  if(change){if(change==='conflict')value.revision++;else bytes[bytes.length-1]^=1;value.bytes=new Blob([bytes]);await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readwrite',{durability:'strict'});tx.objectStore('blobs').put(value,'settings');tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);});}
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(b=>b.toString(16).padStart(2,'0')).join('');db.close();return {revision:value.revision,hash,bytes:Array.from(bytes)};
 },change);
}
async function kill(){const process=browser.process();const exit=new Promise(r=>process.once('exit',r));process.kill('SIGKILL');await exit;}
try{
 let page=await open('create');await receipt(page,'RSY_BROWSER_SETTINGS_SAVED');const saved=await record(page);await kill();
 page=await open('load');await receipt(page,'RSY_BROWSER_SETTINGS_RELOADED');assert.deepEqual(await record(page),saved);await page.screenshot({path:`${logs}/loaded.png`});await browser.close();
 page=await open('conflict');await receipt(page,'RSY_BROWSER_SETTINGS_WAIT');const competitor=await record(page,'conflict');await page.evaluate(()=>{globalThis.settingsCommand='edit';});await receipt(page,'RSY_BROWSER_SETTINGS_REJECTED mode=conflict');assert.deepEqual(await record(page),competitor);const corrupt=await record(page,'corrupt');await browser.close();
 page=await open('corrupt');await receipt(page,'RSY_BROWSER_SETTINGS_REJECTED mode=corrupt');assert.deepEqual(await record(page),corrupt);
 fs.writeFileSync(`${logs}/records.json`,JSON.stringify({saved,competitor,corrupt},null,2));console.log('REPLAY_SCRAPYARD_BROWSER_SETTINGS_OK');
}finally{fs.writeFileSync(`${logs}/receipts.json`,JSON.stringify(receipts,null,2));if(browser?.connected)await browser.close();}
