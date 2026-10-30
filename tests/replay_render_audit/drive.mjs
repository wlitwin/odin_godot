import puppeteer from 'puppeteer-core';import fs from 'node:fs';import {installBufferTrace} from './trace.mjs';
const [base,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});let browser;let timer;const lines=[];
try{
 browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
 timer=setTimeout(()=>browser.process()?.kill('SIGKILL'),90000);
 const page=await browser.newPage();await page.setViewport({width:1280,height:704});await page.evaluateOnNewDocument(installBufferTrace);
 page.on('console',m=>{lines.push(m.text());fs.appendFileSync(`${out}/console.log`,m.text()+'\n');});page.on('pageerror',e=>fs.appendFileSync(`${out}/page-errors.log`,String(e)+'\n'));
 const url=new URL(base);url.search=new URLSearchParams({role:'solo',persist:'0',name:'render-probe',run:'1',waves:'1',wave_base:'4',wave_growth:'1',mobs:'8',audio:'0',stress_return:'1'});
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 const end=Date.now()+45000;while(!lines.some(x=>x.includes('REPLAY_SCRAPYARD_READY'))&&Date.now()<end)await new Promise(r=>setTimeout(r,100));
 if(!lines.some(x=>x.includes('REPLAY_SCRAPYARD_READY')))throw new Error('Game did not initialize');
 await page.screenshot({path:`${out}/staging.png`});
 await page.mouse.click(675,345);
 if(process.env.REPLAY_RENDER_SWARM==='1'){
  await page.waitForFunction(()=>globalThis.stressReceipts,{timeout:10000});
  await page.evaluate(()=>{globalThis.stressCommand={id:1,kind:'load'};});
  await page.waitForFunction(()=>globalThis.stressAck===1,{timeout:10000});
 }
 for(const [name,wait]of [['initial',500],['later',8000]]){
  await new Promise(r=>setTimeout(r,wait));await page.screenshot({path:`${out}/${name}.png`});
  fs.writeFileSync(`${out}/${name}.json`,JSON.stringify(await page.evaluate(()=>globalThis.bufferTrace),null,2));
 }
 console.log('RENDER_DIAGNOSTIC_CAPTURED');
}finally{clearTimeout(timer);if(browser?.connected)await browser.close();}
