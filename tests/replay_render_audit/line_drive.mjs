import puppeteer from 'puppeteer-core';import fs from 'node:fs';import {installBufferTrace} from './trace.mjs';
const [base,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
for(const mode of ['points','transform','polygon_color','polygon_modulate','polygon_points','mesh_modulate']){
 const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,protocolTimeout:15000,args:['--no-sandbox','--disable-background-timer-throttling']});const timer=setTimeout(()=>browser.process()?.kill('SIGKILL'),60000);
 try{
  const page=await browser.newPage();await page.setViewport({width:640,height:360});await page.evaluateOnNewDocument(installBufferTrace);
  page.on('console',m=>fs.appendFileSync(`${out}/${mode}.log`,m.text()+'\n'));
  await page.goto(base+'?mode='+mode,{waitUntil:'domcontentloaded',timeout:30000});await page.waitForFunction(()=>globalThis.lineAudit,{timeout:30000});
  const data=await page.evaluate(()=>({audit:globalThis.lineAudit,trace:globalThis.bufferTrace}));fs.writeFileSync(`${out}/${mode}.json`,JSON.stringify(data,null,2));await page.screenshot({path:`${out}/${mode}.png`});
  await page.setViewport({width:800,height:450});await new Promise(r=>setTimeout(r,300));
  fs.writeFileSync(`${out}/${mode}-resized.json`,JSON.stringify(await page.evaluate(()=>globalThis.bufferTrace),null,2));
 }finally{clearTimeout(timer);await browser.close();}
}
console.log('LINE_AUDIT_CAPTURED');
