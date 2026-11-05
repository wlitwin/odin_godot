import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [base,service,output]=process.argv.slice(2);
const source=fs.readFileSync(new URL('../../../examples/replay_dockyard/web_runtime.gd',import.meta.url),'utf8');
const script=source.match(/const INSTALL := """([\s\S]*?)"""/)[1];
const report={result:'FAIL',scope:'Actual Web engine loop plus exact application scheduling helper; startup/visibility/worker cleanup only, no multiplayer claim.'};
const errors=[],workers=new Set();let browser;
try{
 browser=await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:path.join(output,'profile'),args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader'],ignoreDefaultArgs:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const page=await browser.newPage();page.on('workercreated',w=>workers.add(w));page.on('workerdestroyed',w=>workers.delete(w));
 let menuReady=false;page.on('console',message=>{if(message.text().startsWith('DOCKYARD_MENU_READY '))menuReady=true;});
 page.on('pageerror',e=>errors.push(String(e)));
 const url=new URL(base);url.searchParams.set('service',service);url.searchParams.set('relay','1');url.searchParams.set('render','0');
 await page.goto(String(url),{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv?.MainLoop?.func,{timeout:60000});
 const readyUntil=Date.now()+60000;while(!menuReady&&Date.now()<readyUntil)await new Promise(r=>setTimeout(r,50));assert(menuReady);
 // The retained earlier export permits testing a new helper before rebuilding.
 // No model or Session fields are changed. Final multiplayer uses its own build.
 report.retained_fixture_override=await page.evaluate(script=>{
  if(globalThis.dockyardWebRuntimeV2)return false;
  globalThis.dockyardWebRuntimeV1?.close();const installed=Boolean((0,eval)(script));
  // Route this older fixture's existing scene teardown hook to the new helper.
  globalThis.dockyardWebRuntimeV1=globalThis.dockyardWebRuntimeV2;return installed;
 },script);
 assert(await page.evaluate(()=>!!globalThis.dockyardWebRuntimeV2));
 const cover=await browser.newPage();await cover.bringToFront();
 const before=await page.evaluate(()=>({visibility:document.visibilityState,frames:engine.rtenv.MainLoop.currentFrameNumber,mode:dockyardWebRuntimeV2.mode()}));
 await new Promise(r=>setTimeout(r,2500));
 const after=await page.evaluate(()=>({visibility:document.visibilityState,frames:engine.rtenv.MainLoop.currentFrameNumber,mode:dockyardWebRuntimeV2.mode()}));
 assert.equal(before.visibility,'hidden');assert.equal(after.mode,'worker');assert(after.frames-before.frames>20);
 report.hidden_frames_advanced=after.frames-before.frames;
 await page.bringToFront();assert.equal(await page.evaluate(()=>dockyardWebRuntimeV2.mode()),'raf');report.visible_raf_restored=true;
 await cover.bringToFront();await page.evaluate(()=>engine.requestQuit());
 await page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000,polling:100});
 await page.waitForFunction(()=>!globalThis.dockyardWebRuntimeV2,{timeout:5000,polling:100});
 const until=Date.now()+5000;while(workers.size&&Date.now()<until)await new Promise(r=>setTimeout(r,50));
 assert.equal(workers.size,0);assert.deepEqual(errors,[]);report.worker_count_after_exit=0;report.hidden_full_engine_exit=true;report.result='PASS';
}catch(error){report.error=String(error.stack||error);}
finally{report.errors=errors;if(browser)await browser.close();fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));process.exitCode=report.result==='PASS'?0:1;
