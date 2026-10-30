import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
const [url,verifier,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new',args:['--no-sandbox','--enable-features=SharedArrayBuffer','--ignore-gpu-blocklist','--enable-webgl']});
const logs=[];let page,verdict={pass:false};
try {
 page=await browser.newPage();await page.evaluateOnNewDocument(installBufferTrace);await page.setViewport({width:1280,height:720});
 page.on('console',msg=>logs.push(msg.text()));page.on('pageerror',error=>logs.push('PAGE_ERROR '+error.stack));
 const downloads=path.resolve(out,'downloads');fs.mkdirSync(downloads,{recursive:true});const cdp=await page.createCDPSession();await cdp.send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
 await page.goto(url,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>globalThis.recordingState?.phase==='export',{timeout:40000});
 const before=await page.evaluate(()=>globalThis.recordingState),rect=before.button;
 const canvas=await page.$eval('#canvas',node=>{const r=node.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};});
 await page.mouse.click(canvas.x+(rect[0]+rect[2]/2)*canvas.width/before.width,canvas.y+(rect[1]+rect[3]/2)*canvas.height/before.height);
 const saved=path.join(downloads,'scrapyard.rplrec'),deadline=Date.now()+15000;
 while(!fs.existsSync(saved)||fs.existsSync(saved+'.crdownload')){if(Date.now()>deadline)throw Error('download timeout');await new Promise(r=>setTimeout(r,50));}
 const verified=spawnSync(verifier,[saved],{encoding:'utf8',timeout:30000});fs.writeFileSync(path.join(out,'verify.log'),(verified.stdout||'')+(verified.stderr||''));
 if(verified.status!==0)throw Error('Downloaded recording failed verification: '+verified.stderr);
 const receipt=logs.find(line=>line.startsWith('RSY_RECORDING exports=1 '));if(!receipt)throw Error('No matching export receipt');
 const actual=Object.fromEntries([...verified.stdout.matchAll(/(\w+)=(\d+)/g)].map(m=>[m[1],Number(m[2])])),exported=Object.fromEntries([...receipt.matchAll(/(\w+)=(\d+)/g)].map(m=>[m[1],Number(m[2])]));
 if(actual.head!==exported.head||actual.bytes!==exported.bytes||actual.steps<75||actual.applied<3||actual.gameplay===0||actual.casts<2)throw Error('Recording workload/receipt mismatch');
 await page.screenshot({path:out+'/export.png'});
 await page.waitForFunction(head=>globalThis.recordingState?.head>head+15,{},actual.head);
 await page.evaluate(()=>globalThis.recordingClose=true);await page.waitForFunction(()=>globalThis.recordingClosed,{timeout:10000});
 if(logs.some(line=>/SCRIPT ERROR|ERROR:|PAGE_ERROR|INVALID_OPERATION|instances were leaked/.test(line)))throw Error('Runtime error');
 const graphics=await page.evaluate(()=>globalThis.bufferTrace);if(graphics.conflicts)throw Error('Buffer conflicts');
 verdict={pass:true,before,actual,exported,graphics};console.log('REPLAY_NETWORK_RECORDING_BROWSER_OK');
} catch(error){verdict={pass:false,error:error.stack,last:await page?.evaluate(()=>({state:globalThis.recordingState,progress:globalThis.recordingProgress,failure:globalThis.recordingFailure})).catch(()=>null)};await page?.screenshot({path:out+'/failure.png'}).catch(()=>{});throw error;}
finally {fs.writeFileSync(out+'/result.json',JSON.stringify(verdict,null,2));fs.writeFileSync(out+'/console.log',logs.join('\n'));await browser.close();}
