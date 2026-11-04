// Trusted native copy/paste in a cross-origin iframe without clipboard grants.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const output=path.resolve(process.argv[2]);fs.mkdirSync(output,{recursive:false,mode:0o700});
const source=fs.readFileSync(new URL('../../../examples/replay_dockyard/web_text_entry.gd',import.meta.url),'utf8');
const javascript=source.match(/const INSTALL := """([\s\S]*?)"""/)[1];
const before=execFileSync('/usr/bin/pbpaste');
const ownValues=new Set(),report={result:'FAIL',scope:'Actual native browser input and OS clipboard in cross-origin iframe; no gameplay/performance inference.',cases:[]};
let browser,server;
const write=value=>{execFileSync('/usr/bin/pbcopy',{input:value});ownValues.add(value);};
const read=()=>execFileSync('/usr/bin/pbpaste',{encoding:'utf8'});
async function paste(page,value,firefox,frame){
 write(value);await page.bringToFront();
 if(firefox){
  await frame.browsingContext.performActions([{type:'key',id:'native-paste',actions:[
   {type:'keyDown',value:'\uE03D'},{type:'keyDown',value:'v'},{type:'keyUp',value:'v'},{type:'keyUp',value:'\uE03D'}]}]);
 }
 else{
  const client=await page.createCDPSession();
  await client.send('Input.dispatchKeyEvent',{type:'keyDown',key:'v',code:'KeyV',modifiers:4,commands:['paste']});
  await client.send('Input.dispatchKeyEvent',{type:'keyUp',key:'v',code:'KeyV',modifiers:4});await client.detach();
 }
}
async function key(page,frame,firefox,name){
 if(firefox){const value=name==='Enter'?'\uE007':'\uE00C';await frame.browsingContext.performActions([{type:'key',id:'native-paste',actions:[{type:'keyDown',value},{type:'keyUp',value}]}]);}
 else await page.keyboard.press(name);
}
try{
 server=http.createServer((req,res)=>{
  res.setHeader('Content-Type','text/html');res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
  if(req.url==='/parent')res.end(`<iframe width="900" height="600" allow="cross-origin-isolated" src="http://127.0.0.1:${server.address().port}/child"></iframe>`);
  else res.end('<!doctype html><html><body><script>'+javascript+'</script></body></html>');
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 for(const name of ['chrome','firefox']){
  const firefox=name==='firefox';browser=await puppeteer.launch({browser:firefox?'firefox':'chrome',protocol:firefox?'webDriverBiDi':'cdp',executablePath:firefox?'/Applications/Firefox.app/Contents/MacOS/firefox':'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,userDataDir:path.join(output,name),args:firefox?['--no-remote']:[]});
  const page=await browser.newPage();await page.setViewport({width:1000,height:750});
  await page.goto(`http://localhost:${server.address().port}/parent`,{waitUntil:'load'});
  const frame=page.frames().find(f=>f.url().includes('/child'));assert.ok(frame);
  const item={browser:await browser.version(),paste_cases:[]};report.cases.push(item);
  item.clipboard_policy=await frame.evaluate(()=>{
   const p=document.permissionsPolicy||document.featurePolicy;const features=p?.features?.()||[];
   return features.includes('clipboard-read')?{read:p.allowsFeature('clipboard-read'),write:p.allowsFeature('clipboard-write')}:{not_exposed:true};
  });
  if(!firefox)assert.deepEqual(item.clipboard_policy,{read:false,write:false});
  for(const value of ['VGP3G','ABCDE','RP1.0123456789abcdef.'+'12'.repeat(32)]){
   assert.equal(await frame.evaluate(()=>window.dockyardTextEntry.open({value:'old',maxLength:85})),true);
   const input=await frame.$('#dockyard-room-code');await input.focus();
   await paste(page,value,firefox,frame);
   try{await frame.waitForFunction(value=>document.querySelector('#dockyard-room-code').value===value,{timeout:5000},value);}
   catch(error){item.paste_failure=await frame.evaluate(()=>({focused:document.activeElement?.id,focus:document.hasFocus(),value:document.querySelector('#dockyard-room-code')?.value}));throw error;}
   await key(page,frame,firefox,'Enter');
   await frame.waitForFunction(()=>window.dockyardTextEntry.result!==null,{timeout:5000});
   const result=await frame.evaluate(()=>JSON.parse(window.dockyardTextEntry.take()));assert.deepEqual(result,{accepted:true,value});
   item.paste_cases.push({bytes:value.length,exact:true});
   await frame.waitForSelector('#dockyard-room-entry',{hidden:true});
  }
  write('before copy');await frame.evaluate(()=>window.dockyardTextEntry.open({value:'VGP3G',maxLength:85,copy:true}));
  await key(page,frame,firefox,'Enter');
  await frame.waitForFunction(()=>document.querySelector('#dockyard-room-entry p').textContent!=='Copy this code for your crewmate.',{timeout:5000});
  item.copy_method='native form submit';
  if(read()!=='VGP3G'){
   await frame.focus('#dockyard-room-code');
   if(firefox)await frame.browsingContext.performActions([{type:'key',id:'native-paste',actions:[{type:'keyDown',value:'\uE03D'},{type:'keyDown',value:'c'},{type:'keyUp',value:'c'},{type:'keyUp',value:'\uE03D'}]}]);
   else{await page.keyboard.down('Meta');await page.keyboard.press('KeyC');await page.keyboard.up('Meta');}
   item.copy_method='native keyboard fallback';
  }
  assert.equal(read(),'VGP3G');ownValues.add('VGP3G');item.copy_exact=true;
  const cancel=async()=>{await key(page,frame,firefox,'Escape');await frame.waitForFunction(()=>window.dockyardTextEntry.result!==null,{timeout:5000});};
  await cancel();await frame.evaluate(()=>window.dockyardTextEntry.take());
  await frame.evaluate(()=>window.dockyardTextEntry.open({value:'KEEP',maxLength:85}));await cancel();
  assert.deepEqual(await frame.evaluate(()=>JSON.parse(window.dockyardTextEntry.take())),{accepted:false,value:''});
  await frame.waitForSelector('#dockyard-room-entry',{hidden:true});
  assert.equal(await frame.evaluate(()=>window.dockyardTextEntry.take()),'null');
  item.cancelled_and_cleared=true;
  await browser.close();browser=null;
 }
 report.result='PASS';
}catch(error){report.error=String(error.stack||error);}
finally{
 if(browser)await browser.close();
 if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
 if(ownValues.has(read())){execFileSync('/usr/bin/pbcopy',{input:before});report.clipboard_restored=execFileSync('/usr/bin/pbpaste').equals(before);}
 else report.user_changed_clipboard_preserved=true;
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify(report));process.exitCode=report.result==='PASS'?0:1;
