import fs from 'node:fs';
import path from 'node:path';
import {actors,errors,report,open,delay,check,validate,productionEnrollment,relayPairs,output,restoreClipboard} from '../online/drive.mjs';

report.scope='Actual headed rendered Chrome production play, browser recording and real WebAudio signal, same-artifact complete physics pair. No hardware frame-budget or human-playtest qualification.';
async function setup(page){
 await page.evaluateOnNewDocument(()=>{
  globalThis.dockyardAudio=[];
  if(typeof AudioNode==='undefined')return;
  const connect=AudioNode.prototype.connect,contexts=new WeakMap();
  AudioNode.prototype.connect=function(destination,...args){
   if(destination instanceof AudioDestinationNode){
    let state=contexts.get(this.context);
    if(!state){
     const analyser=this.context.createAnalyser();analyser.fftSize=512;
     state={analyser,samples:0,active_samples:0,max_rms:0,state:this.context.state};contexts.set(this.context,state);
     const record={samples:0,active_samples:0,max_rms:0,state:this.context.state};globalThis.dockyardAudio.push(record);
     const values=new Float32Array(512);
     setInterval(()=>{
      analyser.getFloatTimeDomainData(values);let sum=0;for(const value of values)sum+=value*value;
      const rms=Math.sqrt(sum/values.length);record.samples++;if(rms>0.00001)record.active_samples++;
      record.max_rms=Math.max(record.max_rms,rms);record.state=analyser.context.state;
     },50);
     connect.call(analyser,destination,...args);
    }
    connect.call(this,state.analyser);return destination;
   }
   return connect.call(this,destination,...args);
  };
 });
}
async function glInfo(actor){return actor.page.evaluate(()=>{
 const canvas=document.querySelector('canvas'),gl=canvas?.getContext('webgl2');
 if(!gl)return {available:false};const ext=gl.getExtension('WEBGL_debug_renderer_info');
 return {available:true,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):gl.getParameter(gl.VENDOR),version:gl.getParameter(gl.VERSION),width:canvas.width,height:canvas.height,dpr:devicePixelRatio};
});}
let recorder;
try{
 const options={rendered:true,headless:false,setup};
 const host=await open('host',options);console.log('N1_COHORT '+host.cohort);
 let until=Date.now()+45000;while(!fs.existsSync(path.join(output,'service.ready'))&&Date.now()<until)await delay(100);
 check(fs.existsSync(path.join(output,'service.ready')),'actual room service unavailable');
 const client=await productionEnrollment(host,'client',options);
 host.gl=await glInfo(host);client.gl=await glInfo(client);
 check(host.gl.available&&client.gl.available,'actual rendered WebGL context unavailable');
 check(!/SwiftShader|llvmpipe|Software/i.test(host.gl.renderer+' '+client.gl.renderer),'render capture used a software renderer');
 recorder=await host.page.screencast({path:path.join(output,'play.webm'),ffmpegPath:process.env.FFMPEG||'/run/current-system/sw/bin/ffmpeg'});
 await host.page.bringToFront();await delay(2500);
 await host.page.screenshot({path:path.join(output,'play.png')});
 await host.page.keyboard.press('F2');await delay(150);await host.page.screenshot({path:path.join(output,'settings.png')});
 await host.page.keyboard.press('F2');
 until=Date.now()+220000;let last=0;
 while((!host.shutdown||!client.shutdown)&&!errors.length&&Date.now()<until){
  if(Date.now()-last>1000){for(const actor of [host,client])if(!actor.shutdown){actor.audio=await actor.page.evaluate(()=>globalThis.dockyardAudio);const pairs=await relayPairs(actor.page);if(pairs.length)actor.selected_pairs=pairs;}last=Date.now();}
  await delay(100);
 }
 check(!errors.length,errors.join('\n'));
 await recorder.stop();recorder=null;
 const hp=validate(host),cp=validate(client);
 for(const name of Object.keys(hp))check(hp[name].equals(cp[name]),'complete part mismatch '+name);
 for(const actor of [host,client])check(actor.audio?.some(row=>row.active_samples>0&&row.max_rms>0.00001),'actual output audio signal unavailable: '+actor.role);
 report.all_five_byte_equal=true;report.actual_audio_signal=true;report.result='PASS';
}catch(e){report.error=String(e.stack||e);}
finally{
 report.clipboard_restored=await restoreClipboard();
 if(recorder)try{await recorder.stop();}catch{}
 for(const actor of Object.values(actors)){
  try{actor.audio=await actor.page.evaluate(()=>globalThis.dockyardAudio);if(!actor.shutdown)await actor.page.screenshot({path:path.join(output,actor.role,'last.png')});}catch{}
  report[actor.role]=Object.fromEntries(Object.entries(actor).filter(([key])=>!['browser','page','previous_clipboard'].includes(key)));await actor.browser.close();
 }
 report.errors=errors;report.recorder={kind:'Puppeteer actual page screencast',output_fps:30,game_fps_inferred:false};
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));
process.exit(report.result==='PASS'?0:1);
