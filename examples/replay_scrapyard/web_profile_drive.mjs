import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const base=process.argv[2],logs=process.env.RSB_PROFILE_LOGS;fs.mkdirSync(logs,{recursive:true});let browser;const reports=[];
async function open(mode){
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:`${logs}/chrome-profile`,headless:true,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});page.lines=[];page.errors=[];
 page.on('console',m=>{const line=m.text();page.lines.push(line);fs.appendFileSync(`${logs}/${mode}.log`,line+'\n');if(/RSY_BROWSER_PROFILE|RSY_PROFILE_/.test(line))console.log(line);if(/RSY_BROWSER_PROFILE_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(line))page.errors.push(line);});page.on('pageerror',e=>page.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({role:'solo',persist:'1',profile_namespace:'scrapyard-profile-acceptance',profile_test:mode,run:'1',wave_base:'1',wave_growth:'0',waves:'1',rest:'1',barrels:'0',...(mode==='earn'?{name:'BrowserVault'}:{})});
 await page.goto(url.href,{waitUntil:'domcontentloaded'});return page;
}
async function receipt(page,prefix){const end=performance.now()+155000;while(performance.now()<end){assert.deepEqual(page.errors,[]);const line=page.lines.find(l=>l.startsWith(prefix));if(line){reports.push(line);return;}await new Promise(r=>setTimeout(r,50));}throw new Error(`timeout ${prefix}`);}
async function stored(page,change=''){
 return await page.evaluate(async change=>{
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/scrapyard-profile-acceptance',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const all=await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readonly'),s=tx.objectStore('blobs'),keys=s.getAllKeys(),values=s.getAll();tx.oncomplete=()=>resolve({keys:keys.result,values:values.result});tx.onabort=()=>reject(tx.error);});
  const at=all.keys.findIndex(k=>k.startsWith('profile-'));if(at<0)throw new Error('missing profile');
  const value=all.values[at],bytes=new Uint8Array(await value.bytes.arrayBuffer());
  if(change){if(change==='conflict')value.revision++;else bytes[bytes.length-1]^=1;value.bytes=new Blob([bytes]);await new Promise((resolve,reject)=>{const tx=db.transaction('blobs','readwrite',{durability:'strict'});tx.objectStore('blobs').put(value,all.keys[at]);tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);});}
  const identity=all.values[all.keys.indexOf('identity')],token=Array.from(new Uint8Array(await identity.bytes.arrayBuffer()));
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(b=>b.toString(16).padStart(2,'0')).join('');db.close();
  return {key:all.keys[at],count:all.keys.length,revision:value.revision,hash,token};
 },change);
}
async function kill(){const p=browser.process();const exited=new Promise(r=>p.once('exit',r));p.kill('SIGKILL');await exited;}
try{
 let p=await open('earn');await receipt(p,'RSY_BROWSER_PROFILE_EARNED');const earned=await stored(p);assert.equal(earned.count,2);assert.ok(earned.token.some(x=>x!==0));await p.screenshot({path:`${logs}/earned.png`});await kill();
 p=await open('load');await receipt(p,'RSY_BROWSER_PROFILE_RELOADED');const loaded=await stored(p);assert.deepEqual(loaded,earned);await browser.close();
 p=await open('conflict');await receipt(p,'RSY_BROWSER_PROFILE_WAIT');const competitor=await stored(p,'conflict');await p.evaluate(()=>{globalThis.profileCommand='edit';});await receipt(p,'RSY_BROWSER_PROFILE_REJECTED mode=conflict');assert.deepEqual(await stored(p),competitor);await browser.close();
 p=await open('prepare-corruption');const corrupted=await stored(p,'corrupt');await browser.close();
 p=await open('corrupt');await receipt(p,'RSY_BROWSER_PROFILE_REJECTED mode=corrupt');assert.deepEqual(await stored(p),corrupted);
 fs.writeFileSync(`${logs}/records.json`,JSON.stringify({earned,loaded,competitor,corrupted},null,2));console.log('REPLAY_SCRAPYARD_BROWSER_PROFILE_OK');
}finally{fs.writeFileSync(`${logs}/receipts.json`,JSON.stringify(reports,null,2));if(browser?.connected)await browser.close();}
