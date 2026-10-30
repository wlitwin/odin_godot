import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
const page=await browser.newPage();const lines=[],errors=[];
page.on('console',msg=>{const line=msg.text();lines.push(line);console.log(line);if(/SCRIPT ERROR|ERROR:|ROTATION_FAIL|instances were leaked/.test(line))errors.push(line);});
page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto(process.argv[2],{waitUntil:'domcontentloaded'});
 const end=Date.now()+60000;
 while(Date.now()<end && !lines.some(line=>line.startsWith('REPLAY_ROTATION_GODOT_OK')) && !errors.length)await new Promise(r=>setTimeout(r,100));
 assert.equal(errors.length,0,errors.join('\n'));assert.ok(lines.some(line=>line.startsWith('REPLAY_ROTATION_GODOT_OK')));assert.ok(lines.some(line=>line.startsWith('ROTATION_BODY2_OK')));assert.ok(lines.some(line=>line.startsWith('ROTATION_BODY3_OK')));
 console.log('REPLAY_ROTATION_WEB_OK');
}finally{
 if(process.env.ROTATION_BROWSER_LOG)fs.writeFileSync(process.env.ROTATION_BROWSER_LOG,lines.join('\n'));
 await browser.close();
}
process.exit(0);
