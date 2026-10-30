import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
const page=await browser.newPage();const lines=[],errors=[];
page.on('console',msg=>{const line=msg.text();lines.push(line);console.log(line);if(/WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:/.test(line))errors.push(line);});
page.on('pageerror',error=>errors.push(String(error)));
try{
 const url=new URL(process.argv[2]);url.searchParams.set('url',process.argv[3]);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 const until=Date.now()+60000;
 while(Date.now()<until&&!lines.some(x=>x.startsWith('WEB_AUTHORITY_CLIENT_OK'))&&!errors.length)await new Promise(r=>setTimeout(r,100));
 assert.equal(errors.length,0,errors.join('\n'));assert.ok(lines.includes('WEB_AUTHORITY_TRANSPORT_OK'));assert.ok(lines.includes('WEB_AUTHORITY_RECONNECTED'));assert.ok(lines.some(x=>x.startsWith('WEB_AUTHORITY_CLIENT_OK')));
 console.log('REPLAY_WEB_AUTHORITY_BROWSER_OK');
}finally{
 fs.writeFileSync(process.env.RWA_BROWSER_LOG,lines.join('\n'));await browser.close();
}
process.exit(0);
