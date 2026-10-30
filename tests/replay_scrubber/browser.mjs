import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {installBufferTrace} from '../replay_render_audit/trace.mjs';
const [url,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new',args:['--no-sandbox','--enable-features=SharedArrayBuffer','--ignore-gpu-blocklist','--enable-webgl']});
const logs=[],rows=[];let sequence=0,verdict={pass:false},page;
try {
 page=await browser.newPage();
 const downloads=path.resolve(out,'downloads');fs.mkdirSync(downloads,{recursive:true});
 const cdp=await page.createCDPSession();await cdp.send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});await page.evaluateOnNewDocument(installBufferTrace);await page.setViewport({width:800,height:600});
 page.on('console',msg=>logs.push(msg.text()));page.on('pageerror',err=>logs.push('PAGE_ERROR '+err.stack));
 await page.goto(url,{waitUntil:'domcontentloaded'});
 const state=()=>page.evaluate(()=>globalThis.scrubberState);
 const wait=async predicate=>{await page.waitForFunction(predicate,{timeout:30000});return state();};
 const record=async name=>{const value=await state();rows.push({name,...value});return value;};
 const expect=(yes,reason)=>{if(!yes)throw Error(reason);};
 const command=async value=>{const id=++sequence;await page.evaluate(command=>globalThis.scrubberCommand=command,{id,...value});await page.waitForFunction(id=>globalThis.scrubberState?.command===id,{},id);};
 const key=async code=>{await page.keyboard.down(code);await new Promise(r=>setTimeout(r,60));await page.keyboard.up(code);};
 const click=async (name,left=false)=>{const s=await state(),r=s.controls[name],box=await page.$eval('#canvas',node=>{const r=node.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};});await page.mouse.click(box.x+(r[0]+(left?8:r[2]/2))*box.width/s.width,box.y+(r[1]+r[3]/2)*box.height/s.height);};
 const edit=async (path,text)=>{
  const s=await state(),index=s.controls.field_paths.indexOf(path);expect(index>=0,'missing field '+path);
  await click('fields');await key('Home');for(let i=0;i<=index;i++)await page.keyboard.press('ArrowDown');await key('Enter');
  await page.waitForFunction(index=>globalThis.scrubberState?.controls.field_selected===index,{},index);
  await click('value');await page.keyboard.down('Meta');await page.keyboard.press('KeyA');await page.keyboard.up('Meta');await page.keyboard.press('Backspace');await page.keyboard.type(text);await click('apply');
 };
 const save=async name=>{
  const before=await state();await click('export');await page.waitForFunction(n=>globalThis.scrubberState?.exports===n+1,{},before.exports);
  const downloaded=path.join(downloads,'hello.rplrec'),deadline=Date.now()+10000;
  while(!fs.existsSync(downloaded)||fs.existsSync(downloaded+'.crdownload')){if(Date.now()>deadline)throw Error('download timeout');await new Promise(r=>setTimeout(r,50));}
  const saved=path.join(downloads,name+'.rplrec');fs.renameSync(downloaded,saved);
  const verified=spawnSync(process.env.REPLAY_RECORDING_VERIFY,[saved],{encoding:'utf8',timeout:10000});
  fs.writeFileSync(path.join(downloads,name+'-verify.log'),(verified.stdout||'')+(verified.stderr||''));
  expect(verified.status===0&&verified.stdout.includes('REPLAY_RECORDING_OK'),'headless verification of browser recording');
  const fields=Object.fromEntries([...verified.stdout.matchAll(/(head|shots|x|epoch)=([0-9.]+)/g)].map(m=>[m[1],Number(m[2])]));
  expect(fields.head===before.head&&fields.shots===before.shots&&fields.epoch===before.epoch&&Math.abs(fields.x-before.x)<.001,'downloaded recording matches original world');
  await record('recorded_'+name);
 };
 await wait(()=>globalThis.scrubberState?.controls?.branch);
 await page.click('#canvas');await key('F8');
 await command({paused:false});await page.keyboard.down('ArrowRight');await page.keyboard.down('Space');
 await wait(()=>globalThis.scrubberState?.head>=24&&globalThis.scrubberState?.shots>=2);
 await page.keyboard.up('ArrowRight');await page.keyboard.up('Space');await command({paused:true});
 const live=await record('live');expect(live.head<100&&live.views>2,'initial retained workload');
 await key('F10');await wait(()=>globalThis.scrubberState?.active===1);
 await click('slider',true);await wait(()=>globalThis.scrubberState?.selected===0);
 const past=await record('past');expect(past.head===live.head&&past.x===live.x&&past.shots===live.shots&&past.begins===live.begins&&past.views===2,'inspection mutated history/effects');
 expect(past.status.includes('tick 0    shots 0'),'selected view');
 await edit('$.actors.count','99');await wait(()=>globalThis.scrubberState?.edit_status.includes('Model'));await record('invalid_model');expect((await state()).edited===0,'invalid model edit');
 await edit('$.shots','18446744073709551616');await wait(()=>globalThis.scrubberState?.edit_status.includes('Out_Of_Range'));await record('overflow');expect((await state()).edited===0,'overflow edit');
 await edit('$.shots','42');await wait(()=>globalThis.scrubberState?.edited===1&&globalThis.scrubberState?.status.includes('shots 42'));
 const edited=await record('edited_preview');expect(edited.shots===live.shots&&edited.begins===live.begins,'preview mutated live world/effects');
 await click('reset');await wait(()=>globalThis.scrubberState?.edited===0);expect((await state()).status.includes('shots 0'),'reset preview');
 await edit('$.shots','42');await wait(()=>globalThis.scrubberState?.edited===1);
 await save('original');await page.screenshot({path:out+'/inspection.png'});
 await click('toggle');await wait(()=>globalThis.scrubberState?.active===0);
 const resumed=await record('resume');expect(resumed.head===live.head&&resumed.epoch===live.epoch&&resumed.views===live.views&&resumed.begins===live.begins,'original resume');
 await command({paused:false});await key('F10');await wait(()=>globalThis.scrubberState?.active===1);await click('slider',true);await wait(()=>globalThis.scrubberState?.selected===0);
 // Space is gameplay fire. Arrow keys intentionally edit a focused slider;
 // native acceptance separately tests held movement with the slider unfocused.
 await edit('$.actors.values[0].body.position[0]','240');await wait(()=>globalThis.scrubberState?.edited===1);
 await page.keyboard.down('Space');await click('branch');
 await wait(()=>globalThis.scrubberState?.epoch===2&&globalThis.scrubberState?.active===0&&globalThis.scrubberState?.head>=5);
 const branched=await record('branch');expect(branched.shots===0&&branched.x===240&&branched.views===2&&branched.begins===live.begins,'branch held-input/effect guard');
 await page.keyboard.up('ArrowRight');await page.keyboard.up('Space');await new Promise(r=>setTimeout(r,50));
 await page.keyboard.down('Space');await wait(()=>globalThis.scrubberState?.shots>=1);await page.keyboard.up('Space');
 const shot=await record('new_shot');expect(shot.shots===1&&shot.begins===live.begins+1,'new branch effect');
 await command({paused:true});await save('branch');await command({paused:false});
 await wait(()=>globalThis.scrubberState?.head>=170);await command({paused:true});await key('F10');await wait(()=>globalThis.scrubberState?.active===1);await click('slider',true);
 await wait(()=>globalThis.scrubberState?.first>0&&globalThis.scrubberState?.selected===globalThis.scrubberState?.first);
 const wrapped=await record('wrapped');expect(wrapped.last-wrapped.first===127,'bounded history');
 await page.evaluate(id=>globalThis.scrubberCommand={id,close:true},++sequence);await page.waitForFunction(()=>globalThis.scrubberClosed,{timeout:5000});
 expect(!logs.some(line=>/SCRIPT ERROR|ERROR:|PAGE_ERROR|INVALID_OPERATION|instances were leaked/.test(line)),'browser runtime error');
 const graphics=await page.evaluate(()=>globalThis.bufferTrace);expect(graphics.conflicts===0,'buffer binding conflict');
 verdict={pass:true,observations:rows,graphics};console.log('REPLAY_SCRUBBER_BROWSER_OK');
} catch(error) {verdict={pass:false,error:error.stack,observations:rows,last:await page?.evaluate(()=>globalThis.scrubberState).catch(()=>null),graphics:await page?.evaluate(()=>globalThis.bufferTrace).catch(()=>null)};await page?.screenshot({path:out+'/failure.png'}).catch(()=>{});throw error;}
finally {fs.writeFileSync(out+'/result.json',JSON.stringify(verdict,null,2));fs.writeFileSync(out+'/console.log',logs.join('\n'));await browser.close();}
