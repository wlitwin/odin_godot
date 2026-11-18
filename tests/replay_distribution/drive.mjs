import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [url,output]=process.argv.slice(2),lines=[],errors=[];
let page;
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
try{
 page=await browser.newPage();await page.setViewport({width:640,height:360});
 page.on('console',m=>{const text=m.text();lines.push(text);if(/SCRIPT ERROR|ERROR:|REPLAY_PACKAGE_BROWSER_FAIL|instances were leaked|resources still in use/.test(text))errors.push(text);});page.on('pageerror',e=>errors.push(e.stack||String(e)));
 await page.goto(url,{waitUntil:'domcontentloaded'});
 const readyDeadline=Date.now()+30000;while(Date.now()<readyDeadline&&!lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_READY'))&&!errors.length)await new Promise(r=>setTimeout(r,100));
 assert.deepEqual(errors,[]);assert.ok(lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_READY')),lines.join('\n'));
 await page.click('canvas');
 const deadline=Date.now()+30000;while(Date.now()<deadline&&!lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_OK'))&&!errors.length)await new Promise(r=>setTimeout(r,100));
 assert.deepEqual(errors,[]);assert.ok(lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_OK')),lines.join('\n'));
 if(process.env.REPLAY_PACKAGE_EXPECT_EXIT==='1'){
  await page.waitForFunction(()=>window.__replay_package_exit!==undefined,{timeout:15000});
  assert.equal(await page.evaluate(()=>window.__replay_package_exit),0);
  assert.ok(lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_CLEANUP_OK')));
  await new Promise(r=>setTimeout(r,250));
  assert.deepEqual(errors,[]);
 }
 await page.screenshot({path:output+'/browser.png'});console.log('REPLAY_PACKAGE_WEB_OK');
}finally{
 const engineExit=page&&!page.isClosed()?await page.evaluate(()=>window.__replay_package_exit??null).catch(()=>null):null;
 fs.writeFileSync(output+'/browser.log',lines.join('\n')+'\n');
 fs.writeFileSync(output+'/browser-errors.json',JSON.stringify(errors,null,2)+'\n');
 fs.writeFileSync(output+'/browser-result.json',JSON.stringify({engine_exit:engineExit,scene_cleanup:lines.some(x=>x.includes('REPLAY_PACKAGE_BROWSER_CLEANUP_OK')),errors},null,2)+'\n');
 await browser.close();
}
process.exit(0);
