import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [base,control,mode,png,hash]=process.argv.slice(2),logs=process.env.RSB_LOGS;fs.mkdirSync(logs,{recursive:true});const peers=[],events=[],start=performance.now();
assert.ok(['planned','crash'].includes(mode),'supported migration mode');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const record=(event,extra={})=>events.push({event,ms:Math.round(performance.now()-start),...extra});
async function until(fn,label){const end=performance.now()+150000;while(performance.now()<end){for(const p of peers)if(!p.killed)assert.equal(p.errors.length,0,p.errors.join('\n'));if(fn())return;await wait(50);}throw new Error(`Timeout ${label}`);}
const has=(p,prefix)=>p.lines.some(x=>x.startsWith(prefix));
async function open(member){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:20000,args:['--no-sandbox','--enable-features=SharedArrayBuffer','--disable-features=WebRtcHideLocalIpsWithMdns','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});const p={member,browser,page,lines:[],errors:[],killed:false};peers.push(p);
 page.on('console',msg=>{const line=msg.text();p.lines.push(line);fs.appendFileSync(`${logs}/member-${member}.log`,line+'\n');if(/^(RSB_|RSY_SPRAY|RSY_COMBAT_RESTORED|REPLAY_SCRAPYARD_FAIL)/.test(line)){console.log(member,line);record('receipt',{member,line});}if(/RSB_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(line))p.errors.push(line);});page.on('pageerror',e=>p.errors.push(String(e)));
 const key=(member+20).toString(16).padStart(2,'0')+'00'.repeat(31),url=new URL(base);
 url.search=new URLSearchParams({member:String(member),incarnation:String(100+member),coord_key:key,coord_url:control,token:`browser-room-${member}`,persist:'0',name:`member-${member}`,role:member===1?'host':'client',latency:'120',trace:'1',migration:mode,spray_expected:hash,encounter:'migration',run:'0',mobs:'2'});
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});return p;
}
try{
 const host=await open(1);await until(()=>has(host,'RSB_PICKER_READY'),'host picker');
 const input=await host.page.$('#replay-spray-picker');assert.ok(input);await input.uploadFile(png);
 await until(()=>has(host,'RSY_SPRAY_ADOPTED'),'uploaded PNG');
 const candidate=await open(2);await until(()=>has(candidate,'REPLAY_SCRAPYARD_READY'),'candidate boot');
 const guest=await open(3);await until(()=>has(candidate,'RSB_ASSETS_READY'),'image dependency barrier');
 await host.page.evaluate(()=>{globalThis.rsbCommand='combat';});
 await until(()=>has(candidate,'RSB_BACKUP_READY'),'asset-complete active checkpoint');
 assert.ok(has(candidate,'RSB_DEPENDENCY_WAIT'));
 await Promise.all(peers.map(p=>p.page.evaluate(()=>{globalThis.rsbCommand='health';})));
 await Promise.all(peers.map(p=>p.page.waitForFunction(()=>globalThis.rsbHealth,{timeout:5000})));
 const health=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.rsbHealth)));
 fs.writeFileSync(`${logs}/startup.json`,JSON.stringify(health,null,2));
 for(const h of health){assert.equal(h.ready,1);assert.equal(h.epoch,1);assert.equal(h.resyncs,0,'startup resync');assert.equal(h.fragment_rejections,0);}
 for(const h of health.slice(1))assert.equal(h.full_snapshots,1,'one bootstrap snapshot per follower');
 record('trigger');
 if(mode==='planned')await host.page.evaluate(()=>{globalThis.rsbCommand='handoff';});
 else{host.killed=true;assert.ok(host.browser.process().kill('SIGKILL'));record('kill',{pid:host.browser.process().pid});}
 await until(()=>has(candidate,'RSB_RECOVERED')&&has(guest,'RSB_RECOVERED')&&(mode==='crash'||has(host,'RSB_RECOVERED')),'continued combat with image');
 const live=peers.filter(p=>!p.killed);
 await Promise.all(live.map(p=>p.page.evaluate(()=>{globalThis.rsbCommand='hashes';})));
 let hashes=[],common=[];const hashDeadline=performance.now()+20000;
 do{
  await wait(250);for(const p of live)assert.equal(p.errors.length,0,p.errors.join('\n'));
  hashes=await Promise.all(live.map(p=>p.page.evaluate(()=>globalThis.rsbHashes||{})));
  common=Object.keys(hashes[0]).filter(t=>hashes.every(h=>h[t]!==undefined)).map(Number).sort((a,b)=>a-b);
  fs.writeFileSync(`${logs}/hashes.json`,JSON.stringify({common,peers:hashes},null,2));
  for(const tick of common)for(const h of hashes)assert.equal(h[tick],hashes[0][tick],`complete world hash at tick ${tick}`);
 }while(common.length<10&&performance.now()<hashDeadline);
 assert.ok(common.length>=10,`only ${common.length} shared authoritative frames in 20 seconds`);
 console.log(`RSB_WORLD_EQUAL samples=${common.length} first=${common[0]} last=${common.at(-1)} hash=${hashes[0][common.at(-1)]}`);
 await guest.page.screenshot({path:`${logs}/recovered.png`});record('complete');console.log(`REPLAY_SCRAPYARD_WEB_${mode.toUpperCase()}_OK`);
}finally{fs.writeFileSync(`${logs}/events.json`,JSON.stringify(events,null,2));await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.browser.close()));}
process.exit(0);
