import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
const [url,files,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new',args:['--no-sandbox','--enable-features=SharedArrayBuffer','--ignore-gpu-blocklist','--enable-webgl']});
const logs=[],rows=[];let page,verdict={pass:false},sequence=0;
try {
 page=await browser.newPage();await page.evaluateOnNewDocument(installBufferTrace);await page.setViewport({width:800,height:600});
 page.on('console',msg=>logs.push(msg.text()));page.on('pageerror',error=>logs.push('PAGE_ERROR '+error.stack));
 await page.goto(url,{waitUntil:'domcontentloaded'});
 const state=()=>page.evaluate(()=>globalThis.scrubberState);
 const wait=async predicate=>{await page.waitForFunction(predicate,{timeout:15000});return state();};
 const expect=(ok,message)=>{if(!ok)throw Error(message);};
 const record=async name=>{const value=await state();rows.push({name,...value});return value;};
 const command=async value=>{const id=++sequence;await page.evaluate(command=>globalThis.scrubberCommand=command,{id,...value});await page.waitForFunction(id=>globalThis.scrubberState?.command===id,{},id);};
 const click=async (name,left=false)=>{
  const s=await state(),r=s.playback.controls[name],box=await page.$eval('#canvas',node=>{const r=node.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};});
  await page.mouse.click(box.x+(r[0]+(left?8:r[2]/2))*box.width/s.width,box.y+(r[1]+r[3]/2)*box.height/s.height);
 };
 const open=async name=>{
  const before=await state(),chooser=page.waitForFileChooser();await click('Open');await (await chooser).accept([path.resolve(files,name+'.rplrec')]);
  await page.waitForFunction(old=>{const p=globalThis.scrubberState?.playback;return p&&(p.playback_loads>old.playback_loads||p.playback_rejections>old.playback_rejections);},{timeout:15000},before.playback);
 };
 await wait(()=>globalThis.scrubberState?.playback?.controls?.Open);
 await page.click('#canvas');await page.keyboard.press('F8');
 const canceled=page.waitForFileChooser();await click('Open');await (await canceled).cancel();
 await wait(()=>globalThis.scrubberState?.playback.playback===0&&globalThis.scrubberState?.playback.status==='Open canceled');
 const initial=await record('canceled');expect(initial.head===0,'chooser cancellation advanced paused game');
 await open('original');const loaded=await record('loaded');
 expect(loaded.playback.playback_loads===1&&loaded.playback.playback_selected===0&&loaded.head===0&&loaded.begins===0,'load mutated live timeline/effects');
 await click('Play');await wait(()=>{const p=globalThis.scrubberState?.playback;return p&&p.playback_selected===p.playback_head&&!p.playback_playing;});
 const played=await record('played');expect(played.head===0&&played.begins===0&&played.status.includes('shots 2'),'playback presentation or effects');
 await click('slider',true);await wait(()=>globalThis.scrubberState?.playback.playback_selected===0);
 await open('bad');const rejected=await record('rejected');expect(rejected.playback.playback_rejections===1&&rejected.playback.playback_loads===1&&rejected.playback.playback_selected===0&&rejected.playback.playback===1,'invalid replacement erased recording');
 await open('oversize');const oversize=await record('oversize');expect(oversize.playback.playback_rejections===2&&oversize.playback.playback_loads===1&&oversize.head===0,'oversized replacement');
 await click('Close');await wait(()=>globalThis.scrubberState?.playback.playback===0);
 const returned=await record('returned');expect(returned.head===0&&returned.shots===0&&returned.begins===0,'return changed original timeline');
 await open('branch');await page.keyboard.down('ArrowRight');await page.keyboard.down('Space');await click('Branch');
 await wait(()=>globalThis.scrubberState?.epoch===2&&globalThis.scrubberState?.playback.playback===0);
 const branch=await record('branched');expect(branch.head===0&&branch.x===240&&branch.shots===0&&branch.begins===0,'branch state or saved pause');
 await page.keyboard.up('ArrowRight');await page.keyboard.up('Space');await command({paused:false});
 await wait(()=>globalThis.scrubberState?.head>=3);await page.keyboard.down('Space');await wait(()=>globalThis.scrubberState?.shots===1);await page.keyboard.up('Space');await command({paused:true});
 const shot=await record('new_shot');expect(shot.begins===1,'fresh branch effect');
 await open('mismatch');const mismatch=await record('mismatch');expect(mismatch.playback.playback_loads===3&&mismatch.playback.playback_selected===mismatch.playback.playback_head&&mismatch.playback.report.includes('$.shots')&&mismatch.begins===1,'mismatch inspection');
 await page.screenshot({path:out+'/mismatch.png'});
 await click('Close');await wait(()=>globalThis.scrubberState?.playback.playback===0);
 await open('empty');const empty=await record('empty');expect(empty.playback.playback_selected===900&&empty.views===0,'empty recording view');
 await click('Branch');await wait(()=>globalThis.scrubberState?.epoch===3&&globalThis.scrubberState?.playback.playback===0);
 const emptyBranch=await record('empty_branch');expect(emptyBranch.head===900&&emptyBranch.x===0&&emptyBranch.views===0&&emptyBranch.shots===0&&emptyBranch.begins===1,'empty checkpoint branch');
 // Tear down while an import is pending. The chooser is canceled only after
 // destruction so a late completion cannot recreate its owned browser state.
 const pending=page.waitForFileChooser();await click('Open');const picker=await pending;
 await page.evaluate(id=>globalThis.scrubberCommand={id,close:true},++sequence);await page.waitForFunction(()=>globalThis.scrubberClosed,{timeout:5000});await picker.cancel();
 expect(await page.$$eval('input[type=file]',inputs=>inputs.length)===0,'picker DOM leaked after teardown');
 expect(!logs.some(line=>/SCRIPT ERROR|ERROR:|PAGE_ERROR|INVALID_OPERATION|instances were leaked/.test(line)),'browser runtime error');
 const graphics=await page.evaluate(()=>globalThis.bufferTrace);expect(graphics.conflicts===0,'buffer binding conflicts');
 verdict={pass:true,observations:rows,graphics};console.log('REPLAY_PLAYBACK_BROWSER_OK');
} catch(error) {verdict={pass:false,error:error.stack,observations:rows,last:await page?.evaluate(()=>globalThis.scrubberState).catch(()=>null)};await page?.screenshot({path:out+'/failure.png'}).catch(()=>{});throw error;}
finally {fs.writeFileSync(out+'/result.json',JSON.stringify(verdict,null,2));fs.writeFileSync(out+'/console.log',logs.join('\n'));await browser.close();}
