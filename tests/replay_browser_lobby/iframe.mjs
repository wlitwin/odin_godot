// Exercise the packaged game unmodified in a cross-origin sandbox. The test
// retains transport counters only; invitation codes and TURN credentials stay private.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import puppeteer from '../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const [game, directory, countText='2'] = process.argv.slice(2);
const count=Number(countText);
const menu={
  parallax:{host:[219,387],join:[219,474],field:[204,430],seats:2},
  'second-helping':{host:[156,330],join:[338,330],field:[192,375],seats:8},
}[game];
assert.ok(menu && directory && Number.isInteger(count) && count>=2 && count<=menu.seats,
  'Usage: node iframe.mjs parallax|second-helping EXTRACTED_WEB_DIRECTORY [PLAYERS]');
const root=fs.realpathSync(directory);
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.png':'image/png'};
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const server=http.createServer((req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
  res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
  if(req.url==='/frame'){
    res.setHeader('Content-Type','text/html');
    res.end('<style>*{margin:0;border:0}iframe{width:100vw;height:100vh}</style>'+
      '<iframe allow="cross-origin-isolated; autoplay; fullscreen; clipboard-write" '+
      'sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-downloads" '+
      'src="http://127.0.0.1:'+server.address().port+'/game/index.html"></iframe>');
    return;
  }
  const name=new URL(req.url,'http://localhost').pathname;
  const file=path.resolve(root,name.slice('/game/'.length));
  if(!name.startsWith('/game/')||!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){
    res.writeHead(404);res.end();return;
  }
  res.setHeader('Content-Type',mime[path.extname(file)]??'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});

async function traffic(frame){
  return frame.evaluate(async()=>{
    const pairs=[];
    for(const pc of globalThis.smokePeers){
      if(pc.connectionState!=='connected')continue;
      const stats=await pc.getStats();
      for(const s of stats.values())if(s.type==='candidate-pair'&&s.nominated&&s.state==='succeeded'){
        pairs.push({sent:s.bytesSent,received:s.bytesReceived,route:stats.get(s.localCandidateId)?.candidateType});
      }
    }
    return pairs;
  });
}

await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try{
  browser=await puppeteer.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args:['--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required',
      '--disable-renderer-backgrounding','--disable-background-timer-throttling','--disable-backgrounding-occluded-windows']});
  const pages=[], frames=[], errors=[];
  // Both UI layouts use a 1152x720 design size. Half-size windows lower GPU
  // load when qualifying a full table with eight engines on one machine.
  const click=(p,x,y)=>p.mouse.click(x/2,y/2);
  for(let i=0;i<count;i++){
    const context=await browser.createBrowserContext(),p=await context.newPage();
    pages.push(p);
    await p.setViewport({width:576,height:360});
    await p.evaluateOnNewDocument(()=>{
      const Peer=globalThis.RTCPeerConnection;
      globalThis.smokePeers=[];
      globalThis.RTCPeerConnection=class extends Peer{
        constructor(...args){super(...args);globalThis.smokePeers.push(this);}
      };
    });
    p.on('pageerror',e=>errors.push(e.message));
    p.on('console',m=>{if(/SCRIPT ERROR|^ERROR:|BROWSER_ROOM_PROBLEM|PARALLAX_CLOSE|ODIN_SCRIPT_PANIC/.test(m.text()))errors.push(m.text());});
    await p.goto('http://localhost:'+server.address().port+'/frame',{waitUntil:'domcontentloaded'});
    const f=await p.waitForFrame(fr=>fr.url().endsWith('/game/index.html'));frames.push(f);
    await f.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv&&!document.getElementById('status'),{timeout:75000});
    assert.ok(await f.evaluate(()=>crossOriginIsolated));
    await pause(600);
  }
  await pages[0].bringToFront();await click(pages[0],...menu.host);
  await pause(1800);
  let code='';
  for(let attempt=0;attempt<30;attempt++){
    await click(pages[0],1030,88);await pause(350);
    code=await frames[0].evaluate(()=>document.querySelector('dialog input')?.value??'');
    if(/^[A-Z2-9]{5}$/.test(code))break;
    if(game==='parallax')await pages[0].keyboard.press('Escape');
  }
  assert.ok(/^[A-Z2-9]{5}$/.test(code),'host did not display an invitation');
  await pages[0].keyboard.press('Escape');
  for(let i=1;i<count;i++){
    const p=pages[i], f=frames[i];
    await p.bringToFront();await click(p,...menu.field);
    await f.waitForSelector('dialog input',{timeout:5000});await f.focus('dialog input');
    await p.keyboard.type(code);
    if(game==='parallax')await p.keyboard.press('Enter');
    else await f.click('button[data-action=apply]');
    await f.waitForSelector('dialog',{hidden:true,timeout:5000});await pause(350);
    await click(p,...menu.join);
  }
  let stats;
  for(let attempt=0;attempt<80;attempt++){
    await pause(450);
    stats=await Promise.all(frames.map(traffic));
    if(stats[0].length===count-1&&stats.every(rows=>rows.length&&rows.every(r=>r.route==='relay'&&r.sent>7500&&r.received>7500)))break;
  }
  assert.equal(stats[0].length,count-1,'missing browser peer at host');
  assert.ok(stats.every(rows=>rows.length&&rows.every(r=>r.route==='relay'&&r.sent>7500&&r.received>7500)),
    'every client must exchange gameplay traffic over the public relay');
  for(const p of [...pages].reverse()){
    await p.bringToFront();
    if(game==='parallax'){await p.keyboard.press('Escape');await pause(100);}
    await click(p,1070,37);await pause(450);
  }
  assert.deepEqual(errors,[]);
  console.log(JSON.stringify({game,players:count,isolated:true,form_permission:false,stats,result:'BROWSER_LOBBY_PASS'}));
}finally{
  if(browser)await browser.close();
  server.closeAllConnections();
  await new Promise(resolve=>server.close(resolve));
}
