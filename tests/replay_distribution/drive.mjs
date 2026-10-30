import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [url,output]=process.argv.slice(2),lines=[],errors=[];
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
try{
 const page=await browser.newPage();await page.setViewport({width:640,height:360});
 page.on('console',m=>{const text=m.text();lines.push(text);if(/SCRIPT ERROR|ERROR:|REPLAY_PACKAGE_BROWSER_FAIL/.test(text))errors.push(text);});page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url,{waitUntil:'domcontentloaded'});
 const deadline=Date.now()+30000;while(Date.now()<deadline&&!lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_OK'))&&!errors.length)await new Promise(r=>setTimeout(r,100));
 assert.deepEqual(errors,[]);assert.ok(lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_OK')),lines.join('\n'));
 await page.screenshot({path:output+'/browser.png'});console.log('REPLAY_PACKAGE_WEB_OK');
}finally{fs.writeFileSync(output+'/browser.log',lines.join('\n')+'\n');await browser.close();}
process.exit(0);
