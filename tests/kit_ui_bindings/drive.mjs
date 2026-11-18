import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
const [url, output] = process.argv.slice(2);
const errors = [], lines = [];
let browser, passed = false;
process.on('SIGTERM', async () => { if (browser) await browser.close(); process.exit(124); });
const report = {result:'FAIL', scope:'Actual exported Godot Web UI bindings, typed rejection, standard attach and cleanup'};
try {
  browser = await puppeteer.launch({executablePath:process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:path.join(output,'chrome'),args:['--no-sandbox','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
  const page = await browser.newPage();
  page.on('console', msg => {
    const text = msg.text(); lines.push({type:msg.type(),text});
    if (text.includes('KIT_UI_WEB_PASS')) passed = true;
    if (msg.type()==='error' || ['SCRIPT ERROR','ODIN_SCRIPT_PANIC','SHUTDOWN_NOT_EMPTY','leaked at exit','resources still in use'].some(x=>text.includes(x))) errors.push(text);
  });
  page.on('pageerror', e=>errors.push(String(e)));
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
  const deadline = Date.now()+120000;
  while (errors.length===0 && Date.now()<deadline && await page.evaluate(()=>window.__kit_ui_exit===undefined))
    await new Promise(resolve=>setTimeout(resolve,100));
  report.exit = await page.evaluate(()=>window.__kit_ui_exit);
  report.isolated = await page.evaluate(()=>crossOriginIsolated);
  report.browser = await browser.version();
  if (!passed || report.exit!==0 || !report.isolated || errors.length) throw Error('browser UI check failed: '+errors.join('\n'));
  report.result='PASS';
} catch(error) { report.error=String(error); }
finally {
  if (browser) await browser.close();
  fs.writeFileSync(path.join(output,'console.json'),JSON.stringify({lines,errors},null,2));
  fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2));
}
console.log(JSON.stringify(report));
process.exit(report.result==='PASS'?0:1);
