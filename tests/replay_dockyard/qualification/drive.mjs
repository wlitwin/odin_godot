import fs from 'node:fs';
import path from 'node:path';
import {actors,errors,report,open,delay,check,validate,productionEnrollment,relayPairs,output,ticks,restoreClipboard} from '../online/drive.mjs';

const browserName=process.env.Q1_BROWSER||'chrome';
const clientBrowserName=process.env.Q1_CLIENT_BROWSER||browserName;
const networkFaults=process.env.Q1_FAULTS==='1';
const sustained=process.env.Q1_SOAK==='1';
const traceFirstSlow=process.env.Q1_TRACE_FIRST_SLOW==='1';
const processObserver=process.env.Q1_PROCESS_STATE==='1';
const internalPhases=process.env.Q1_INTERNAL_PHASES==='1';
const counterDetail=process.env.Q1_COUNTERS==='1';
report.scope='Actual rendered visible browser pair, public Room.frame whole-operation samples, raw presentation intervals and bounded resource observations. Budgets assessed separately against the declared plan. Local network only.';
report.browser=browserName;
report.browsers={host:browserName,client:clientBrowserName};
report.network_faults=networkFaults;
report.sustained_job_controls=sustained;
report.operation_sampler=process.env.Q1_BUFFERED==='1'?'buffered_until_checked_close':'periodic_128_rows';
report.trace_first_slow=traceFirstSlow;
report.measurement_mode=process.env.Q1_GECKO_PROFILE==='1'?'CPU_PROFILER_DIAGNOSTIC_NOT_ADMISSION':'DECLARED_OPERATION_TIMING';
if(processObserver)report.measurement_mode='PROCESS_STATE_DIAGNOSTIC_NOT_ADMISSION';
if(internalPhases)report.measurement_mode='INTERNAL_PHASE_DIAGNOSTIC_NOT_ADMISSION';
if(counterDetail)report.measurement_mode='COUNTER_DIAGNOSTIC_NOT_ADMISSION';
if(networkFaults)report.measurement_mode='NETWORK_FAULT_FUNCTIONAL_NOT_BASELINE';
if(process.env.Q1_GECKO_PROFILE==='1')report.scope+=' Firefox CPU sampler attached: this run cannot qualify unprofiled performance.';
async function setup(page){
 await page.evaluateOnNewDocument(traceMode=>{
  const sample=globalThis.dockyardQualification={intervals:[],visibility:[],memory:[],overflow:false,timer_positive_deltas_ms:[]};
  const log=console.log;
  console.log=function(...args){
   if(args.some(v=>typeof v==='string'&&v.startsWith('SAMPLE_OPERATION_END '))&&sample.operation_end_ms===undefined)sample.operation_end_ms=performance.now();
   if(args.some(v=>typeof v==='string'&&(v.startsWith('SAMPLE_RESULT ')||v.startsWith('DOCKYARD_AUDIO_DRAINED ')||v.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK')))&&typeof engine!=='undefined'&&engine.rtenv?.HEAPU8)
    sample.pre_exit_wasm_linear_bytes=engine.rtenv.HEAPU8.buffer.byteLength;
   for(const value of args)if(traceMode&&typeof value==='string'&&value.startsWith('SAMPLE_OPERATION_SLOW ')){
    try{
     const row=JSON.parse(value.slice('SAMPLE_OPERATION_SLOW '.length));
     if(row.category==='advance1'&&row.after.repairs===row.before.repairs&&row.elapsed_us>10000&&row.clock_valid){
      const marker={row,browser_now_ms:performance.now(),browser_time_origin_ms:performance.timeOrigin};
      sample.first_slow_normal??=marker;
      sample.slow_normal_markers??=[];
      if(sample.slow_normal_markers.length<64)sample.slow_normal_markers.push(marker);else sample.trace_marker_overflow=true;
     }
    }catch{}
   }
   return log.apply(this,args);
  };
  let previous;
  function frame(now){
   if(previous!==undefined){if(sample.intervals.length>=100000){sample.overflow=true;}else sample.intervals.push([now,now-previous,document.visibilityState,document.hasFocus()]);}
   previous=now;requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  document.addEventListener('visibilitychange',()=>sample.visibility.push([performance.now(),document.visibilityState]));
  setInterval(()=>{
   if(typeof engine!=='undefined'&&engine.rtenv?.HEAPU8)sample.memory.push([performance.now(),engine.rtenv.HEAPU8.buffer.byteLength]);
  },1000);
  for(let i=0;i<10000&&sample.timer_positive_deltas_ms.length<256;i++){const a=performance.now(),b=performance.now();if(b>a)sample.timer_positive_deltas_ms.push(b-a);}
 },traceFirstSlow);
 if(networkFaults)await page.evaluateOnNewDocument(()=>{
  const original=RTCDataChannel.prototype.send,channels=new WeakMap();let random=42;
  const next=()=>{random=(Math.imul(random,1664525)+1013904223)>>>0;return random;};
  const stats=globalThis.dockyardNetworkFaults={base_delay_ms:15,jitter_ms:8,unreliable_loss_permyriad:300,delayed:0,dropped:0,bytes_delayed:0,bytes_dropped:0,queued:0,peak_queued:0,closed_before_delivery:0};
  RTCDataChannel.prototype.send=function(data){
   if(!['replay-reliable-v1','replay-unreliable-v1'].includes(this.label))return original.call(this,data);
   const source=ArrayBuffer.isView(data)?new Uint8Array(data.buffer,data.byteOffset,data.byteLength):new Uint8Array(data);
   if(this.label==='replay-unreliable-v1'&&next()%10000<stats.unreliable_loss_permyriad){stats.dropped++;stats.bytes_dropped+=source.byteLength;return;}
   if(stats.queued>=256)throw Error('bounded fault transport queue exceeded');
   const copy=new Uint8Array(source.byteLength);copy.set(source);
   let state=channels.get(this);
   if(!state){
    const channel=this;
    state={due:0,queue:[],timer:null};channels.set(this,state);
    state.schedule=()=>{
     if(state.timer!==null||!state.queue.length)return;
     state.timer=setTimeout(()=>{
      state.timer=null;
      const now=performance.now();
      while(state.queue.length&&state.queue[0].due<=now){
       const packet=state.queue.shift();stats.queued--;
       if(channel.readyState==='open')original.call(channel,packet.bytes);else stats.closed_before_delivery++;
      }
      state.schedule();
     },Math.max(1,state.queue[0].due-performance.now()));
    };
   }
   // Keep each physical channel ordered. Payload bytes and the real protocol
   // remain unchanged; transport-control and coordinator channels are untouched.
   const now=performance.now(),due=Math.max(now+stats.base_delay_ms+(next()%17)-8,state.due+.01);state.due=due;
   stats.delayed++;stats.bytes_delayed+=copy.byteLength;stats.queued++;stats.peak_queued=Math.max(stats.peak_queued,stats.queued);
   state.queue.push({due,bytes:copy});state.schedule();
  };
 });
}
async function observe(actor){
 return actor.page.evaluate(()=>{
  const canvas=document.querySelector('canvas'),gl=canvas?.getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');
  return {...globalThis.dockyardQualification,terminal_wasm_linear_bytes:typeof engine!=='undefined'&&engine.rtenv?.HEAPU8?engine.rtenv.HEAPU8.buffer.byteLength:globalThis.dockyardQualification?.pre_exit_wasm_linear_bytes??null,
   network_faults:globalThis.dockyardNetworkFaults||null,visibility_now:document.visibilityState,isolation:crossOriginIsolated,dpr:devicePixelRatio,
   viewport:[innerWidth,innerHeight],gl:gl?{renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),version:gl.getParameter(gl.VERSION)}:null,
   navigation:performance.getEntriesByType('navigation').map(x=>x.toJSON()),resources:performance.getEntriesByType('resource').map(x=>({name:x.name,encodedBodySize:x.encodedBodySize,decodedBodySize:x.decodedBodySize,transferSize:x.transferSize,duration:x.duration}))};
 });
}
try{
 check(process.env.Q1_TRACE_SYSTEM!=='1','System Trace experiment is archived; no live recorder is supported by this runner');
 check(!internalPhases||process.env.Q1_BUFFERED!=='1','internal phases use periodic whole-call rows');
 check(!counterDetail||(!internalPhases&&!processObserver&&!traceFirstSlow&&!networkFaults&&process.env.Q1_BUFFERED!=='1'&&process.env.Q1_GECKO_PROFILE!=='1'),'counter diagnostic uses periodic rows without other probes');
 const options={rendered:true,headless:false,browserName,query:{profile:counterDetail?'4':internalPhases?'3':process.env.Q1_BUFFERED==='1'?'2':'1'},setup};
 const host=await open('host',options);console.log('N1_COHORT '+host.cohort);
 if(traceFirstSlow){
  check((process.env.Q1_GECKO_PROFILE==='1'||processObserver||internalPhases)&&browserName==='firefox'&&process.env.Q1_BUFFERED!=='1','triggered trace requires Firefox diagnostics and periodic telemetry');
  host.page.on('console',message=>{
   if(report.trace_trigger||!message.text().startsWith('SAMPLE_OPERATION_SLOW '))return;
   if(processObserver&&!fs.existsSync(path.join(output,'process-state.ready')))return;
   try{
    const row=JSON.parse(message.text().slice('SAMPLE_OPERATION_SLOW '.length));
    if(row.category==='advance1'&&row.after.repairs===row.before.repairs&&row.elapsed_us>10000&&row.clock_valid)
     report.trace_trigger={role:host.role,row,node_arrival_wall_ms:Date.now()};
   }catch(error){errors.push('trace trigger row: '+String(error));}
  });
 }
 let until=Date.now()+45000;while(!fs.existsSync(path.join(output,'service.ready'))&&Date.now()<until)await delay(100);
 check(fs.existsSync(path.join(output,'service.ready')),'actual room service unavailable');
 const client=await productionEnrollment(host,'client',{...options,browserName:clientBrowserName});
 report.pair_enrolled_wall_ms=Date.now();
 until=Date.now()+720000;let last=0,nextJobAt=Date.now()+90000;
 while((!host.shutdown||!client.shutdown)&&!errors.length&&Date.now()<until&&!(traceFirstSlow&&report.trace_trigger)){
  if(processObserver&&fs.existsSync(path.join(output,'process-state.failed')))throw Error('owned process observer failed; raw recorder log retained');
  if(Date.now()-last>=1000){
   for(const actor of [host,client])if(!actor.shutdown){
    const pairs=await relayPairs(actor.page);if(pairs.length)actor.selected_pairs=pairs;
    if(actor.SAMPLE_STATUS?.error)errors.push(actor.role+': '+actor.SAMPLE_STATUS.error);
    if(actor.DOCKYARD_CONNECTION?.message?.includes('job stopped'))errors.push(actor.role+': actual job ended: '+actor.DOCKYARD_CONNECTION.message);
   }
   last=Date.now();
  }
  if(sustained&&Date.now()>=nextJobAt&&!host.shutdown){
   // Hit the real result-panel button. During Working it is hidden and the
   // scripted player ignores pointer controls, so this cannot reset live Game.
   if(!report.job_button_attempts)await host.page.screenshot({path:path.join(output,'first-result-before-job-button.png')});
   await host.page.bringToFront();await host.page.mouse.click(625,327);
   (report.job_button_attempts??=[]).push({at_wall_ms:Date.now(),x:625,y:327});
   nextJobAt=Date.now()+10000;
  }
  await delay(50);
 }
 check(!errors.length,errors.join('\n'));
 if(traceFirstSlow){
  report.trace_browser_marker=await host.page.evaluate(sequence=>globalThis.dockyardQualification?.slow_normal_markers?.find(m=>m.row.sequence===sequence)||null,report.trace_trigger?.row.sequence);
  check(!await host.page.evaluate(()=>globalThis.dockyardQualification?.trace_marker_overflow),'diagnostic marker capacity exceeded');
  report.result=report.trace_trigger?(internalPhases?'PHASE_TRACE_TRIGGERED_NOT_ADMISSION':processObserver?'PROCESS_STATE_TRIGGERED_NOT_ADMISSION':'CPU_TRACE_TRIGGERED_NOT_ADMISSION'):(internalPhases?'PHASE_TRACE_WINDOW_NO_TRIGGER_NOT_ADMISSION':processObserver?'PROCESS_STATE_WINDOW_NO_TRIGGER_NOT_ADMISSION':'CPU_TRACE_WINDOW_NO_TRIGGER_NOT_ADMISSION');
  report.gameplay_validation='NOT_RUN: diagnostic stop may precede the target, complete round and final state handshake';
  await Promise.all([host,client].map(async actor=>{
   if(!actor.shutdown)actor.diagnostic_shutdown_requested=await actor.page.evaluate(()=>{if(typeof engine==='undefined')return false;engine.requestQuit();return true;});
  }));
 }else{
 const hp=validate(host),cp=validate(client);
 for(const name of Object.keys(hp))check(hp[name].equals(cp[name]),'complete part mismatch '+name);
 report.all_five_byte_equal=true;
 check(host.SAMPLE_INPUTS?.nonzero_by_seat?.every(x=>x>0),'actual two-seat nonzero controls missing');
 if(sustained){
  check(host.SAMPLE_GAME?.round>=3&&client.SAMPLE_GAME?.round===host.SAMPLE_GAME.round,'actual repeated job transitions unavailable');
  check(host.SAMPLE_GAME.layout===(host.SAMPLE_GAME.round-1)%3,'actual NEXT JOB layout progression unavailable');
  check(host.SAMPLE_GAME.eligible_delivery_cues>=3,'no complete three-cargo delivery in sustained play');
 }
 if(networkFaults){
  for(const actor of [host,client]){
   const faults=await actor.page.evaluate(()=>globalThis.dockyardNetworkFaults);
   check(faults?.delayed>0&&faults.peak_queued<=256,'actual bounded per-actor delay/jitter evidence missing');
   actor.network_fault_observations=faults;
  }
  // Complete physics facts/images are reliable authority traffic. The real
  // client input datagrams exercise loss; require those actual dropped bytes.
  check(client.network_fault_observations.dropped>0&&client.network_fault_observations.bytes_dropped>0,'actual unreliable client input loss missing');
 }
 report.all_five_byte_equal=true;report.result='FUNCTIONAL_SAMPLES_COLLECTED';
 }
}catch(e){report.error=String(e.stack||e);}
finally{
 report.pair_finished_wall_ms=Date.now();
 report.clipboard_restored=await restoreClipboard();
 if(processObserver){
  fs.writeFileSync(path.join(output,'process-state.stop'),JSON.stringify({trigger:report.trace_trigger||null,reason:report.error||'diagnostic window ended'})+'\n');
  const controller=path.join(output,'process-state.controller.json');
  if(!fs.existsSync(controller))errors.push('owned process observer controller unavailable');
  else{
   const observer=JSON.parse(fs.readFileSync(controller,'utf8'));
   while(!fs.existsSync(path.join(output,'process-state.saved'))&&!fs.existsSync(path.join(output,'process-state.failed'))){
    if(!Number.isSafeInteger(observer.pid)||observer.pid<=0){errors.push('invalid observer process identity');break;}
    try{process.kill(observer.pid,0);}catch{errors.push('owned observer exited before terminal status');break;}
    await delay(100);
   }
  }
  report.process_state_saved_before_browser_close=fs.existsSync(path.join(output,'process-state.saved'));
  if(!report.process_state_saved_before_browser_close)errors.push('owned process observations unavailable; raw status retained');
 }
 for(const actor of Object.values(actors)){
  if(!actor.shutdown)try{
   actor.failure_shutdown_requested=await actor.page.evaluate(()=>{if(typeof engine==='undefined')return false;engine.requestQuit();return true;});
   const until=Date.now()+15000;while(!actor.shutdown&&Date.now()<until)await delay(50);
  }catch(e){errors.push(actor.role+': checked failure shutdown '+String(e));}
  if(actor.shutdown)try{
   await actor.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000});
   actor.godot_runtime_exit_observed=true;
  }catch(e){errors.push(actor.role+': full Godot runtime exit unavailable '+String(e));}
  try{const samples=await observe(actor);fs.writeFileSync(path.join(output,actor.role,'browser-samples.json'),JSON.stringify(samples)+'\n');actor.browser_observations={visibility:samples.visibility_now,isolation:samples.isolation,gl:samples.gl,overflow:samples.overflow};}catch(e){errors.push(actor.role+': sampler '+String(e));}
  report[actor.role]=Object.fromEntries(Object.entries(actor).filter(([k])=>!['browser','page','previous_clipboard'].includes(k)));await actor.browser.close();
 }
 report.errors=errors;if(errors.length)report.result='FAIL';
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));
process.exit(['FUNCTIONAL_SAMPLES_COLLECTED','CPU_TRACE_TRIGGERED_NOT_ADMISSION','PROCESS_STATE_TRIGGERED_NOT_ADMISSION','PHASE_TRACE_TRIGGERED_NOT_ADMISSION','CPU_TRACE_WINDOW_NO_TRIGGER_NOT_ADMISSION','PROCESS_STATE_WINDOW_NO_TRIGGER_NOT_ADMISSION','PHASE_TRACE_WINDOW_NO_TRIGGER_NOT_ADMISSION'].includes(report.result)?0:1);
