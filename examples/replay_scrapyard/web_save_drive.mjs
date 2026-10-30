import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
const [base,pngA,pngB]=process.argv.slice(2),logs=process.env.RSB_SAVE_LOGS;fs.mkdirSync(logs,{recursive:true});
// Only disposable uploads produced in the gate output directory may be deleted.
for(const file of [pngA,pngB])assert.equal(path.dirname(fs.realpathSync(file)),fs.realpathSync(logs));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),imageA=hash(fs.readFileSync(pngA)),imageB=hash(fs.readFileSync(pngB));
let browser,saved;const receipts=[];
async function open(mode,extra={}){
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',userDataDir:`${logs}/chrome-profile`,headless:true,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist']});
 const p=await browser.newPage();await p.setViewport({width:1280,height:704});p.lines=[];p.errors=[];
 p.on('console',m=>{const line=m.text();p.lines.push(line);fs.appendFileSync(`${logs}/${mode}.log`,line+'\n');if(/^(RSS_|RSY_RUN_|RSY_SPRAY_|RSY_SAVE_ERROR)/.test(line))console.log(line);if(/RSS_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(line))p.errors.push(line);});p.on('pageerror',e=>p.errors.push(String(e)));
 const url=new URL(base);url.search=new URLSearchParams({role:'solo',persist:'1',profile_namespace:'scrapyard-save-acceptance',save_test:mode,run:'0',encounter:'migration',mobs:'2',image_a:imageA,image_b:imageB,...(saved?{saved_tick:saved.tick,saved_hash:saved.hash}:{}),...(mode.startsWith('resume')||['missing','identity','corrupt'].includes(mode)?{resume:'1'}:{}),...extra});
 await p.goto(url.href,{waitUntil:'domcontentloaded'});return p;
}
async function until(p,prefix){const deadline=performance.now()+80000;while(performance.now()<deadline){assert.deepEqual(p.errors,[]);const line=p.lines.find(l=>l.startsWith(prefix));if(line){receipts.push(line);return;}await new Promise(r=>setTimeout(r,50));}throw new Error(`timeout ${prefix}`);}
async function database(p,operation){return await p.evaluate(async op=>{
 const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('replay/scrapyard-save-acceptance',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
 try{return await new Promise((resolve,reject)=>{
  const tx=db.transaction('blobs',op.kind==='read'?'readonly':'readwrite',{durability:'strict'}),store=tx.objectStore('blobs');let result;
  if(op.kind==='read'){const keys=store.getAllKeys(),values=store.getAll();tx.oncomplete=()=>resolve({keys:keys.result,values:values.result});}
  else{if(op.kind==='delete')store.delete(op.key);else store.put({revision:op.revision,bytes:new Blob([Uint8Array.from(atob(op.base64),c=>c.charCodeAt(0))])},op.key);tx.oncomplete=()=>resolve(true);}
  tx.onabort=()=>reject(tx.error);
 }).then(async result=>{
  if(op.kind!=='read')return result;
  const entries=[];for(let i=0;i<result.keys.length;i++){const value=result.values[i],bytes=new Uint8Array(await value.bytes.arrayBuffer());let binary='';for(let at=0;at<bytes.length;at+=32768)binary+=String.fromCharCode(...bytes.subarray(at,at+32768));entries.push({key:result.keys[i],revision:value.revision,base64:btoa(binary)});}return entries;
 });}finally{db.close();}
 },operation);}
async function kill(){const process=browser.process(),exited=new Promise(r=>process.once('exit',r));process.kill('SIGKILL');await exited;}
function missingBundle(original){const size=original.readUInt32LE(56),body=original.subarray(96,96+size),header=Buffer.from(original.subarray(0,96));header.writeUInt16LE(0,54);header.writeUInt32LE(body.length,60);crypto.createHash('sha256').update(body).digest().copy(header,64);let h=0xcbf29ce484222325n;for(const bytes of [header.subarray(0,44),header.subarray(52)])for(const b of bytes)h=BigInt.asUintN(64,(h^BigInt(b))*0x100000001b3n);header.writeBigUInt64LE(h,44);return Buffer.concat([header,body]);}
try{
 let p=await open('create');await until(p,'RSS_PICKER');await (await p.$('#replay-spray-picker')).uploadFile(pngA);await until(p,'RSS_SAVED');saved=await p.evaluate(()=>globalThis.saveReceipt);assert.equal(saved.image,imageA);
 await p.evaluate(()=>{globalThis.saveCommand='picker';});await until(p,'RSS_PICKER_NEXT');await (await p.$('#replay-spray-picker')).uploadFile(pngB);await until(p,'RSS_PREFERENCE_CHANGED');
 const entries=await database(p,{kind:'read'}),run=entries.find(e=>e.key.startsWith('run-')),spray=entries.find(e=>e.key.startsWith('spray-'));assert.ok(run&&spray);const bundle=Buffer.from(run.base64,'base64');fs.writeFileSync(`${logs}/saved.replay`,bundle);fs.writeFileSync(`${logs}/saved.json`,JSON.stringify({...saved,imageA,imageB,bytes:bundle.length},null,2));
 run.revision++;await database(p,{kind:'put',...run});await p.evaluate(()=>{globalThis.saveCommand='conflict_save';});await until(p,'RSS_SAVE_CONFLICT');assert.ok(p.lines.some(l=>l.startsWith('RSY_SAVE_ERROR browser=Conflict')));assert.deepEqual((await database(p,{kind:'read'})).find(e=>e.key===run.key),run);
 await kill();fs.unlinkSync(pngA);fs.unlinkSync(pngB);
 p=await open('spray');await until(p,'RSS_PREFERENCE_RESTORED');await browser.close();
 p=await open('slot',{save_slot:'profile'});await until(p,'RSS_PREFERENCE_RESTORED');const beforeSlot=await database(p,{kind:'read'});await p.evaluate(()=>{globalThis.saveCommand='slot_save';});await until(p,'RSS_SAVED');const afterSlot=await database(p,{kind:'read'});for(const prior of beforeSlot)assert.deepEqual(afterSlot.find(e=>e.key===prior.key),prior);assert.ok(afterSlot.some(e=>e.key==='run/profile-'+run.key.slice(4)));await browser.close();
 p=await open('resume-preference');await until(p,'RSS_RESUME_OK');await p.screenshot({path:`${logs}/resumed.png`});await database(p,{kind:'delete',key:spray.key});await browser.close();
 p=await open('resume-bundle-only');await until(p,'RSS_RESUME_OK');let current=(await database(p,{kind:'read'})).find(e=>e.key===run.key);assert.deepEqual(current,run);
 const suffix=run.key.slice(4),missing=missingBundle(bundle);await database(p,{kind:'put',key:`run/missing-${suffix}`,revision:1,base64:missing.toString('base64')});
 const wrongToken=crypto.createHash('sha256').update('browser-save-impostor').digest().subarray(0,16),wrongKey='run-'+hash(wrongToken);await database(p,{kind:'put',key:wrongKey,revision:1,base64:run.base64});
 const damaged=Buffer.from(bundle);damaged[damaged.length-1]^=1;await database(p,{kind:'put',key:`run/corrupt-${suffix}`,revision:1,base64:damaged.toString('base64')});await browser.close();
 for(const [mode,extra,expected,key,data] of [
  ['missing',{save_slot:'missing'},'RSY_SAVE_ERROR load=Codec missing asset',`run/missing-${suffix}`,missing],
  ['identity',{token:'browser-save-impostor'},'RSY_SAVE_ERROR identity',wrongKey,bundle],
  ['corrupt',{save_slot:'corrupt'},'RSY_SAVE_ERROR load=Codec',`run/corrupt-${suffix}`,damaged],
 ]){p=await open(mode,extra);await until(p,`RSS_REJECTED mode=${mode}`);assert.ok(p.lines.some(l=>l.startsWith(expected)));const records=await database(p,{kind:'read'});assert.equal(records.find(e=>e.key===key).base64,data.toString('base64'));assert.deepEqual(records.find(e=>e.key===run.key),run);await browser.close();}
 console.log('REPLAY_SCRAPYARD_BROWSER_SAVE_OK');
}finally{fs.writeFileSync(`${logs}/receipts.json`,JSON.stringify(receipts,null,2));if(browser?.connected)await browser.close();}
