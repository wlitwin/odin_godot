// Actual Web HUD layout, pointer hit testing and DPI invariance. No game timing gate.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const [webDirectory,outputDirectory]=process.argv.slice(2),root=fs.realpathSync(webDirectory),output=path.resolve(outputDirectory);
fs.mkdirSync(output,{recursive:false,mode:0o700});
const report={result:'FAIL',scope:'Actual Chrome WebGL HUD across eight CSS viewport/DPR arrangements, corner anchors, modal centering, pointer targets and screenshots; no hardware performance or multiplayer claim.',cases:[]};
let browser,server,layout,menuReady=false;const errors=[];
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,message){const end=Date.now()+20000;while(!predicate()&&!errors.length&&Date.now()<end)await wait(50);assert.ok(predicate(),message+' '+errors.join('; '));}
function cssRect(entry,metrics){
 const r=entry.rect,p=layout.viewport,c=metrics.canvas;
 return [c.x+r[0]*c.width/p[0],c.y+r[1]*c.height/p[1],r[2]*c.width/p[0],r[3]*c.height/p[1]];
}
function inside(r,width,height){return r[0]>=-1&&r[1]>=-1&&r[0]+r[2]<=width+1&&r[1]+r[3]<=height+1;}
try{
 server=http.createServer((req,res)=>{
  const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname),file=path.resolve(root,'.'+name);
  if(!file.startsWith(root+path.sep)){res.writeHead(404);res.end();return;}
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
  res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.png':'image/png','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
  fs.readFile(file,(error,data)=>{if(error)res.writeHead(404);res.end(error?'':data);});
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 browser=await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:path.join(output,'profile'),args:['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader']});
 report.browser=await browser.version();const page=await browser.newPage();await page.setViewport({width:1280,height:720,deviceScaleFactor:1});
 page.on('console',message=>{const text=message.text();if(text.startsWith('DOCKYARD_UI_LAYOUT '))layout=JSON.parse(text.slice('DOCKYARD_UI_LAYOUT '.length));if(text.startsWith('DOCKYARD_MENU_READY '))menuReady=true;if(message.type()==='error'||text.includes('SCRIPT ERROR'))errors.push(text);});
 page.on('pageerror',error=>errors.push(String(error)));
 const url=new URL(`http://127.0.0.1:${server.address().port}/index.html`);url.searchParams.set('service','wss://mc.laserturtle.net:62127/replay-room/dockyard');url.searchParams.set('relay','1');url.searchParams.set('ui_layout','1');
 await page.goto(url.toString(),{waitUntil:'domcontentloaded',timeout:60000});
 await until(()=>menuReady&&layout?.panels?.crew?.visible,'initialized menu and layout report');
 await page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv?.HEAPU8,{timeout:60000});
 const arrangements=[[1280,720,1],[1920,1080,1],[1920,1080,2],[960,540,1],[960,540,2],[1024,768,2],[2560,1080,1],[720,1280,2]];
 for(const [width,height,dpr] of arrangements){
  await page.setViewport({width,height,deviceScaleFactor:dpr});await wait(350);
  const metrics=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect();return {canvas:{x:r.x,y:r.y,width:r.width,height:r.height},pixels:[c.width,c.height],dpr:devicePixelRatio,isolated:crossOriginIsolated};});
  await until(()=>layout.window_pixels[0]===metrics.pixels[0]&&layout.window_pixels[1]===metrics.pixels[1],'settled resized viewport');
  assert.equal(metrics.dpr,dpr);assert.ok(metrics.isolated);
  const panels={};for(const name of ['status','help','crew']){panels[name]=cssRect(layout.panels[name],metrics);assert.ok(inside(panels[name],width,height),name+' fits '+width+'x'+height+'@'+dpr);}
  const scale=metrics.canvas.width/layout.viewport[0];
  assert.ok(Math.abs(panels.status[0]-24*scale)<1&&Math.abs(panels.status[1]-22*scale)<1,'top-left status');
  assert.ok(Math.abs(panels.crew[0]+panels.crew[2]-(width-24*scale))<1,'top-right crew');
  assert.ok(Math.abs(panels.help[1]+panels.help[3]-(height-22*scale))<1,'bottom-left help');
  const field=cssRect(layout.controls.name,metrics);await page.mouse.click(field[0]+field[2]/2,field[1]+field[3]/2);
  await until(()=>layout.controls.name.focused,'DPI-correct name field hit target');
  const code=cssRect(layout.controls.code,metrics);await page.mouse.click(code[0]+code[2]/2,code[1]+code[3]/2);
  await page.waitForSelector('#dockyard-room-code',{timeout:5000});
  const modal=await page.$eval('#dockyard-room-entry',e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height];});assert.ok(inside(modal,width,height),'native text dialog fits');
  await page.keyboard.press('Escape');await page.waitForSelector('#dockyard-room-entry',{hidden:true});await wait(100);
  await page.keyboard.press('F2');await until(()=>layout.panels.settings.visible,'settings visible');
  const settings=cssRect(layout.panels.settings,metrics);assert.ok(inside(settings,width,height),'settings fits');
  assert.ok(Math.abs(settings[0]+settings[2]/2-width/2)<scale+1&&Math.abs(settings[1]+settings[3]/2-height/2)<scale+1,'settings centered');
  await page.screenshot({path:path.join(output,`${width}x${height}-dpr${dpr}-settings.png`)});
  await page.keyboard.press('F2');await until(()=>!layout.panels.settings.visible,'settings closed');
  await page.screenshot({path:path.join(output,`${width}x${height}-dpr${dpr}.png`)});
  report.cases.push({width,height,dpr,metrics,panels,settings,camera_size:layout.camera_size,pointer_targets:true});
 }
 for(const [width,height] of [[1920,1080],[960,540]]){
  const [a,b]=report.cases.filter(c=>c.width===width&&c.height===height);
  for(const name of ['status','help','crew'])for(let i=0;i<4;i++)assert.ok(Math.abs(a.panels[name][i]-b.panels[name][i])<1,'DPR-invariant CSS layout');
  assert.ok(Math.abs(a.camera_size-b.camera_size)<0.001,'DPR-invariant camera');
 }
 await page.evaluate(()=>engine.requestQuit());await page.waitForFunction(()=>engine.rtenv===null,{timeout:20000});
 report.full_engine_exit=true;assert.deepEqual(errors,[]);report.result='PASS';
}catch(error){report.error=String(error.stack||error);}
finally{if(browser)await browser.close();if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}report.errors=errors;fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({result:report.result,cases:report.cases.length,error:report.error}));process.exitCode=report.result==='PASS'?0:1;
