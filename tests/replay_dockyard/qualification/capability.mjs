import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';

const [url,output,browserName]=process.argv.slice(2);
const result={result:'FAIL',browser:browserName,scope:'Actual ordinary production AOT/backend/authoring startup, render and checked engine shutdown only. No multiplayer/full5/performance admission from this probe.'};
const rows=[],errors=[];let browser;
const shaderDiagnostic=process.env.Q1_SHADER_DIAGNOSTIC==='1';
if(shaderDiagnostic)result.scope='Diagnostic of actual cold visual preparation without online configuration and transparent WebGL call durations. Instrumented graphics calls are not frame-budget qualification; no gameplay/full5 inference.';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const check=(ok,why)=>{if(!ok)throw Error(why);};
try{
 const firefox=browserName==='firefox';
 browser=firefox&&process.env.FIREFOX_BIDI_ENDPOINT?await puppeteer.connect({browserWSEndpoint:process.env.FIREFOX_BIDI_ENDPOINT,protocol:'webDriverBiDi'}):await puppeteer.launch({browser:firefox?'firefox':'chrome',protocol:firefox?'webDriverBiDi':'cdp',executablePath:firefox?'/Applications/Firefox.app/Contents/MacOS/firefox':'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,userDataDir:path.join(output,'profile'),dumpio:firefox,args:firefox?['--no-remote']:['--no-sandbox']});
 result.version=await browser.version();result.pid=browser.process()?.pid??null;result.argv=browser.process()?.spawnargs??null;
 if(firefox&&process.env.FIREFOX_BIDI_ENDPOINT)result.automation_endpoint=process.env.FIREFOX_BIDI_ENDPOINT;
 const page=await browser.newPage();await page.setViewport({width:1280,height:720,deviceScaleFactor:1});
 if(shaderDiagnostic)await page.evaluateOnNewDocument(()=>{
  const observation=globalThis.dockyardShaderDiagnostic={calls:[],overflow:false,totals:{},shaders:[]};
  const shaders=new WeakMap(),programs=new WeakMap();let shaderId=0,programId=0;
  const proto=globalThis.WebGL2RenderingContext?.prototype;if(!proto)return;
  const attach=proto.attachShader;
  proto.attachShader=function(program,shader){let value=programs.get(program);if(!value){value={id:++programId,shaders:[]};programs.set(program,value);}if(shaders.has(shader))value.shaders.push(shaders.get(shader));return attach.call(this,program,shader);};
  for(const name of ['compileShader','linkProgram','getProgramParameter','getShaderParameter','getUniformLocation']){
   const original=proto[name];if(!original)continue;
   proto[name]=function(...args){
    let identity;
    if(name==='compileShader'){
     const source=this.getShaderSource(args[0])||'';
     identity=shaders.get(args[0]);if(!identity){identity=++shaderId;shaders.set(args[0],identity);}
     observation.shaders.push({id:identity,source_chars:source.length,defines:source.split('\n').filter(x=>/^\s*#define\s+/.test(x)).slice(0,64)});
    }else if(name==='getShaderParameter'){identity=shaders.get(args[0]);}
    else{let value=programs.get(args[0]);if(!value){value={id:++programId,shaders:[]};programs.set(args[0],value);}identity=value;}
    const start=performance.now();try{return original.apply(this,args);}finally{
     observation.totals[name]=(observation.totals[name]||0)+1;
     if(observation.calls.length<65536)observation.calls.push({method:name,start_ms:start,elapsed_ms:performance.now()-start,identity,parameter:name.endsWith('Parameter')?args[1]:undefined});else observation.overflow=true;
    }
   };
  }
 });
 let lobby=false,shutdown=false;
 page.on('console',msg=>{
  const row={type:msg.type(),text:msg.text(),arrival_ms:performance.now()};rows.push(row);fs.appendFileSync(path.join(output,'console.ndjson'),JSON.stringify(row)+'\n');
  if(row.text.startsWith((shaderDiagnostic?'DOCKYARD_VISUALS_READY':'DOCKYARD_LOBBY')+' '))lobby=true;
  if(row.text.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK'))shutdown=true;
  if(row.type==='error'||['SCRIPT ERROR','ODIN_SCRIPT_PANIC','CONTRACT_REJECTED','SHUTDOWN_NOT_EMPTY','SHUTDOWN_LIVE','RuntimeError:'].some(v=>row.text.includes(v)))errors.push(row.text);
 });
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
 const start=performance.now();await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
 let until=Date.now()+60000;while(!lobby&&!errors.length&&Date.now()<until)await pause(50);
 result.local_cold_start_ms=performance.now()-start;
 result.observations=await page.evaluate(()=>{
  const canvas=document.querySelector('canvas'),gl=canvas?.getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');
  const sizes=[];for(let i=0;i<10000;i++){const a=performance.now();let b=performance.now();if(b>a)sizes.push(b-a);}
  return {isolation:crossOriginIsolated,shared_array_buffer:typeof SharedArrayBuffer!=='undefined',visibility:document.visibilityState,gl:gl?{renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),version:gl.getParameter(gl.VERSION)}:null,
   wasm_linear_bytes:typeof engine!=='undefined'&&engine.rtenv?.HEAPU8?engine.rtenv.HEAPU8.buffer.byteLength:null,
   timer_positive_deltas_ms:sizes.slice(0,256),navigation:performance.getEntriesByType('navigation').map(e=>e.toJSON()),resources:performance.getEntriesByType('resource').map(e=>({name:e.name,encodedBodySize:e.encodedBodySize,decodedBodySize:e.decodedBodySize,transferSize:e.transferSize,duration:e.duration}))};
 });
 // Serialize in the page so repeated program references survive BiDi's remote
 // value deduplication rather than losing later identity records.
 if(shaderDiagnostic)fs.writeFileSync(path.join(output,'shader-calls.json'),await page.evaluate(()=>JSON.stringify(globalThis.dockyardShaderDiagnostic))+'\n');
 check(lobby&&!errors.length,'actual startup failed: '+errors.join('\n'));
 await page.screenshot({path:path.join(output,'startup.png')});
 await page.evaluate(()=>engine.requestQuit());
 until=Date.now()+20000;while(!shutdown&&!errors.length&&Date.now()<until)await pause(50);
 check(shutdown&&!errors.length,'actual checked backend shutdown missing: '+errors.join('\n'));
 result.actual_lobby=true;result.actual_shutdown=true;result.result='STARTUP_ONLY_PASS';
}catch(e){result.error=String(e.stack||e);}
finally{result.errors=errors;fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(result,null,2)+'\n');if(browser)await browser.close();}
console.log(JSON.stringify({result:result.result,error:result.error,report:path.join(output,'report.json')}));
process.exit(result.result==='STARTUP_ONLY_PASS'?0:1);
