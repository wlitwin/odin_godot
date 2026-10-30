import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});let browser;
const errors=[];
try {
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:out+'/profile',args:['--no-sandbox','--enable-features=SharedArrayBuffer','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl','--disable-background-timer-throttling']});
 const page=await browser.newPage();
 page.on('console',m=>{const line=m.text();fs.appendFileSync(out+'/console.log',line+'\n');if(/SCRIPT ERROR|ERROR:|CAVE_FEEDBACK_FAIL/.test(line))errors.push(line)});
 page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url+'?role=solo&persist=0&token=feedback-browser',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>globalThis.caveFeedbackDone,{timeout:60000});assert.equal(errors.length,0,errors.join('\n'));
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,errors})+'\n');console.log('REPLAY_CAVE_FEEDBACK_BROWSER_OK');
} finally {if(browser)await browser.close()}
