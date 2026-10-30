import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});let browser;const rows=[],errors=[];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
try {
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:out+'/profile',args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--disable-background-timer-throttling']});
 const page=await browser.newPage();page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR|ERROR:|FAIL/.test(s))errors.push(s)});page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>globalThis.scrubberState?.paused,{timeout:30000});
 let id=0;
 const state=()=>page.evaluate(()=>globalThis.scrubberState);
 async function pause(value){await page.evaluate(command=>globalThis.scrubberCommand=command,{id:++id,paused:value});await page.waitForFunction(n=>globalThis.scrubberState?.command===n,{},id)}
 await page.click('#canvas');const start=await state();rows.push({label:'paused',...start});
 await page.keyboard.down('Space');await sleep(60);await page.keyboard.up('Space');await sleep(60);
 await pause(false);await sleep(200);let s=await state();assert.equal(s.shots,start.shots);assert.ok(s.head>start.head);rows.push({label:'paused tap discarded',...s});
 await pause(true);await page.keyboard.down('Space');await page.keyboard.down('ArrowRight');await sleep(60);const held=await state();
 await pause(false);await sleep(200);s=await state();assert.equal(s.shots,held.shots);assert.equal(s.x,held.x);rows.push({label:'held controls suppressed',...s});
 await page.keyboard.up('Space');await page.keyboard.up('ArrowRight');await sleep(60);
 await page.keyboard.down('Space');await sleep(60);await page.keyboard.up('Space');await sleep(60);s=await state();assert.equal(s.shots,held.shots+1);rows.push({label:'fresh press',...s});
 await pause(true);await page.screenshot({path:out+'/paused.png'});assert.deepEqual(errors,[]);
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,rows,errors},null,2)+'\n');console.log('REPLAY_HELLO_PAUSE_BROWSER_OK');
} finally {if(browser)await browser.close()}
