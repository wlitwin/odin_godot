import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {actors,errors,report,open,delay,check,validate,productionEnrollment,relayPairs,output,ticks,restoreClipboard} from '../online/drive.mjs';

const flow=process.env.R1_FLOW||'observer';report.flow=flow;
const scopes={observer:'Progressed late Observer, receive-only seat0, complete five-part equality and teardown.',transient:'Actual RTC closure with the original action pending, same live Client/attempt, validated replacement and five-part equality.',gap:'Actual whole game-channel discard beyond H128 followed by real connection replacement and validated complete Welcome.',frozen:'Actually hidden Client and explicit Chrome lifecycle freeze, independent authority progress, complete state after return.',cold:'Checked leave, browser restart with the same durable membership, new challenged incarnation and complete state without replaying an old action.',hostloss:'Actual authority browser closure, coordinator-confirmed stopped state, preserved five parts and real new-crew button.',hostfrozen:'Actually hidden/frozen authority, real hosting permission fencing, stopped UI and checked new-crew flow.'};
check(scopes[flow],'unknown selected lifecycle flow');report.scope=scopes[flow]+' Local functional proof; no Internet, performance or human-playtest inference.';
const press=async(a,key)=>{await a.page.bringToFront();await a.page.keyboard.press(key);await delay(100);};
async function runtimeExited(actor){
 await actor.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000});
 actor.godot_runtime_exit_observed=true;
}
async function typeAt(a,x,y,text){
 await a.page.bringToFront();await a.page.mouse.click(x,y);await delay(100);
 await a.page.keyboard.down('Meta');await a.page.keyboard.press('KeyA');await a.page.keyboard.up('Meta');
 await a.page.keyboard.type(text,{delay:40});await delay(100);
}
try{
 let host=await open('host');console.log('N1_COHORT '+host.cohort);
 let until=Date.now()+45000;while(!fs.existsSync(path.join(output,'service.ready'))&&Date.now()<until)await delay(100);
 check(fs.existsSync(path.join(output,'service.ready')),'actual service unavailable');
 let client=await productionEnrollment(host);
 if(flow==='transient'){
  until=Date.now()+20000;while(!client.SAMPLE_STATUS?.go&&!errors.length&&Date.now()<until)await delay(25);
  check(client.SAMPLE_STATUS?.go&&client.SAMPLE_STATUS.head<30,'real initial GO before scripted action unavailable');
  report.before_fault=client.SAMPLE_STATUS;
  await client.page.evaluate(()=>{
   const send=RTCDataChannel.prototype.send;
   globalThis.dockyardFault={active:true,packets:0,bytes:0};
   RTCDataChannel.prototype.send=function(data){
    if(globalThis.dockyardFault.active&&this.label==='replay-reliable-v1'){
     globalThis.dockyardFault.packets++;globalThis.dockyardFault.bytes+=data.byteLength??data.length??0;return;
    }
    return send.call(this,data);
   };
  });
  until=Date.now()+10000;while(!(client.SAMPLE_STATUS?.issued_sequence===1&&client.SAMPLE_STATUS?.pending_actions>0)&&!errors.length&&Date.now()<until)await delay(25);
  check(client.SAMPLE_STATUS?.issued_sequence===1&&client.SAMPLE_STATUS.pending_actions>0,'actual original pending attempt unavailable');
  report.pending_before_close=client.SAMPLE_STATUS;
  report.fault=await client.page.evaluate(()=>{
   const observation={...globalThis.dockyardFault};globalThis.dockyardFault.active=false;
   observation.closed=0;for(const peer of globalThis.replayTestPeers||[])if(peer.connectionState!=='closed'){peer.close();observation.closed++;}
   return observation;
  });
  check(report.fault.closed>0&&report.fault.packets>0&&report.fault.bytes>0,'actual owned RTC/fault evidence absent');
  until=Date.now()+30000;
  while((client.SAMPLE_STATUS?.recoveries||0)<1&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_STATUS?.recoveries>=1,'committed replacement scope unavailable');report.after_reconnect=client.SAMPLE_STATUS;
 }else if(flow==='gap'||flow==='frozen'){
  until=Date.now()+30000;while((client.SAMPLE_STATUS?.confirmed||0)<300&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_STATUS?.confirmed>=300,'actual established world before impairment unavailable');
  report.before_impairment=client.SAMPLE_STATUS;
  if(flow==='gap'){
   await host.page.evaluate(()=>{
    const send=RTCDataChannel.prototype.send;globalThis.dockyardGap={active:true,packets:0,bytes:0};
    RTCDataChannel.prototype.send=function(data){
     if(globalThis.dockyardGap.active&&['replay-reliable-v1','replay-unreliable-v1'].includes(this.label)){
      globalThis.dockyardGap.packets++;globalThis.dockyardGap.bytes+=data.byteLength??data.length??0;return;
     }
     return send.call(this,data);
    };
   });
   until=Date.now()+10000;
   while((host.SAMPLE_STATUS?.confirmed||0)-report.before_impairment.confirmed<=160&&!errors.length&&Date.now()<until)await delay(50);
   report.authority_at_replacement=host.SAMPLE_STATUS;
   check(report.authority_at_replacement.confirmed-report.before_impairment.confirmed>128,'actual authority gap did not exceed H128');
   report.gap_fault=await host.page.evaluate(()=>{
    const result={...globalThis.dockyardGap};globalThis.dockyardGap.active=false;result.closed=0;
    for(const peer of globalThis.replayTestPeers||[])if(peer.connectionState!=='closed'){peer.close();result.closed++;}
    return result;
   });
   check(report.gap_fault.closed>0&&report.gap_fault.packets>0&&report.gap_fault.bytes>0,'actual discarded game traffic/connection replacement unavailable');
   until=Date.now()+30000;
   while((client.SAMPLE_STATUS?.recoveries||0)<1&&!errors.length&&Date.now()<until)await delay(50);
   check(client.SAMPLE_STATUS?.recoveries>=1&&client.SAMPLE_STATUS.baseline>report.before_impairment.confirmed+128,'actual correlated complete Welcome baseline unavailable');
   report.after_impairment=client.SAMPLE_STATUS;
  }else{
   const cover=await client.browser.newPage();await cover.bringToFront();await delay(100);
   const visibility=await client.page.evaluate(()=>document.visibilityState);
   const cdp=await client.page.createCDPSession();const start=performance.now();const head=host.SAMPLE_STATUS.confirmed;
   await cdp.send('Page.setWebLifecycleState',{state:'frozen'});await delay(1000);
   const during=host.SAMPLE_STATUS;
   await cdp.send('Page.setWebLifecycleState',{state:'active'});await cover.close();await client.page.bringToFront();
   report.suspension={visibility_before:visibility,visibility_after:await client.page.evaluate(()=>document.visibilityState),elapsed_ms:performance.now()-start,authority_before:head,authority_during:during.confirmed};
   check(visibility==='hidden'&&report.suspension.visibility_after==='visible'&&during.confirmed>head,'actual hidden/frozen browser and independent authority progress unavailable');
   await cdp.detach();
  }
 }else if(flow==='cold'){
  until=Date.now()+30000;
  while(!((client.SAMPLE_STATUS?.confirmed||0)>=300&&client.SAMPLE_STATUS.pending_actions===0&&client.SAMPLE_STATUS.action_outcomes[1]===1)&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_STATUS?.confirmed>=300&&client.SAMPLE_STATUS.pending_actions===0,'actual drained original attempt before planned return unavailable');
  report.before_planned_leave=client.SAMPLE_STATUS;
  await press(client,'Escape');await client.page.mouse.click(1030,590);
  until=Date.now()+15000;while(!client.shutdown&&!errors.length&&Date.now()<until)await delay(50);
  check(client.shutdown,'original process did not complete its checked Leave Crew');
  await runtimeExited(client);
  const profile=client.profile_dir;report.original_client={checked_leave:true,shutdown:true,godot_runtime_exit_observed:true,member:client.SAMPLE_STATUS.member,incarnation:client.SAMPLE_STATUS.incarnation};
  await client.browser.close();delete actors.client;
  client=await open('returning',{profileDir:profile});client.expected_role='client';
  await typeAt(client,1000,452,'Coral');await client.page.mouse.click(1060,530);
  until=Date.now()+30000;
  while(!client.SAMPLE_STATUS?.go&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_STATUS?.go&&client.SAMPLE_STATUS.member===report.before_planned_leave.member,'actual stored membership did not rejoin');
  check(BigInt('0x'+client.SAMPLE_STATUS.incarnation)>BigInt('0x'+report.before_planned_leave.incarnation),'actual challenged new incarnation unavailable');
  report.after_cold_return=client.SAMPLE_STATUS;
 }else if(flow==='hostloss'||flow==='hostfrozen'){
  until=Date.now()+30000;while((client.SAMPLE_STATUS?.confirmed||0)<300&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_STATUS?.confirmed>=300,'actual running client before authority loss unavailable');
  report.before_authority_loss=client.SAMPLE_STATUS;
  if(flow==='hostfrozen'){
   const cover=await host.browser.newPage();await cover.bringToFront();await delay(100);
   const visibility=await host.page.evaluate(()=>document.visibilityState);const cdp=await host.page.createCDPSession();const start=performance.now();
   await cdp.send('Page.setWebLifecycleState',{state:'frozen'});await delay(3000);
   await cdp.send('Page.setWebLifecycleState',{state:'active'});await cover.close();await host.page.bringToFront();
   report.authority_suspension={visibility_before:visibility,visibility_after:await host.page.evaluate(()=>document.visibilityState),elapsed_ms:performance.now()-start};await cdp.detach();
   check(visibility==='hidden'&&report.authority_suspension.elapsed_ms>=3000,'actual authority suspension unavailable');
   until=Date.now()+15000;while(!host.SAMPLE_HOST_LOST&&!errors.length&&Date.now()<until)await delay(50);
   check(host.SAMPLE_HOST_LOST&&host.DOCKYARD_CONNECTION?.message?.includes('Hosting permission ended'),'actual authority fencing/end UI unavailable');
   await host.page.screenshot({path:path.join(output,'authority-stopped.png')});await host.page.mouse.click(1030,599);
   until=Date.now()+15000;while(!host.shutdown&&!errors.length&&Date.now()<until)await delay(50);
   check(host.shutdown,'checked authority leave did not drain');
   report.lost_authority={pid:host.browser.process().pid,method:'hidden/frozen authority then checked Leave Crew',typed_shutdown_claimed:true};
  }else{report.lost_authority={pid:host.browser.process().pid,method:'owned Browser.close',typed_shutdown_claimed:false};}
  if(host.shutdown)await runtimeExited(host);
  await host.browser.close();delete actors.host;
  until=Date.now()+30000;while(!client.SAMPLE_HOST_LOST&&!errors.length&&Date.now()<until)await delay(50);
  check(client.SAMPLE_HOST_LOST&&client.DOCKYARD_CONNECTION?.message?.includes('host is unavailable'),'actual coordinator-confirmed host-loss UI unavailable');
  report.stopped_frame=client.SAMPLE_HOST_LOST;await client.page.screenshot({path:path.join(output,'hostloss-menu.png')});
  const beforeReady=client.event_counts.DOCKYARD_MENU_READY;
  for(const key of Object.keys(client))if(key.startsWith('SAMPLE_')||['DOCKYARD_LOBBY','DOCKYARD_MENU_READY'].includes(key))delete client[key];
  await delay(1000);await client.page.bringToFront();await client.page.mouse.click(1030,633);
  until=Date.now()+30000;while((client.event_counts.DOCKYARD_MENU_READY||0)<=beforeReady&&!errors.length&&Date.now()<until)await delay(100);
  check((client.event_counts.DOCKYARD_MENU_READY||0)>beforeReady&&client.SAMPLE_REHOST_FROM,'checked real rehost button/reload unavailable');
  report.rehost_from=client.SAMPLE_REHOST_FROM;
  check(report.rehost_from.tick===report.stopped_frame.tick,'stopped confirmed state advanced before rehost');
  for(const name of ['Solver','Game','Side','Observations','Occurrences']){
   const a=report.stopped_frame.parts.find(v=>v.name===name),b=report.rehost_from.parts.find(v=>v.name===name);
   const av=Buffer.from(a.base64,'base64'),bv=Buffer.from(b.base64,'base64');
   check(createHash('sha256').update(av).digest('hex')===a.sha256&&av.equals(bv)&&a.sha256===b.sha256,'stopped five-part preservation failed: '+name);
  }
  client.expected_role='host';host=client;
  client=await productionEnrollment(host,'replacement');
  report.actual_new_crew=true;
 }else{
 until=Date.now()+30000;while((host.SAMPLE_STATUS?.confirmed||0)<300&&!errors.length&&Date.now()<until)await delay(100);
 check(host.SAMPLE_STATUS?.go&&host.SAMPLE_STATUS.confirmed>=300,'authority progress before late join unavailable');
 report.before_observer={head:host.SAMPLE_STATUS.head,confirmed:host.SAMPLE_STATUS.confirmed};
 await press(host,'Escape');await host.page.evaluate(()=>navigator.clipboard.writeText(''));
 let invitation='';until=Date.now()+10000;
 while(Date.now()<until&&!invitation){await host.page.mouse.click(1030,596);await delay(250);invitation=await host.page.evaluate(()=>navigator.clipboard.readText());}
 check(invitation.length>32,'actual new watch invitation unavailable');
 await press(host,'Escape');
 const observer=await open('observer');check(observer.cohort===host.cohort,'observer cohort differs');
 await typeAt(observer,1000,452,'Lens');await typeAt(observer,1000,488,invitation);invitation='';
 await observer.page.mouse.click(969,530);
 }
 until=Date.now()+150000;
 while(Object.values(actors).some(a=>!a.shutdown)&&!errors.length&&Date.now()<until){
  for(const a of Object.values(actors))if(!a.shutdown){const pairs=await relayPairs(a.page);if(pairs.length)a.selected_pairs=pairs;}
  await delay(100);
 }
 check(!errors.length,errors.join('\n'));
 const parts={};for(const a of Object.values(actors))parts[a.role]=validate(a);
 for(const role of Object.keys(parts).filter(v=>v!==host.role))for(const name of Object.keys(parts[host.role]))check(parts[host.role][name].equals(parts[role][name]),role+' complete part differs: '+name);
 if(flow==='observer'){
 const network=actors.observer.SAMPLE_NETWORK;
 check(network.session_role==='Observer'&&network.seat===0&&network.controls_consumed===0,'observer consumed control or occupied a seat');
 check(network.frontier_samples>0&&network.max_prediction_ahead===0,'observer prediction/frontier evidence incomplete');
 check(network.issued_sequence===0&&network.boost_fx===0,'late observer issued action or replayed old boost cosmetics');
 report.observer_receive_only=true;
 }else if(flow==='transient'){
  check(client.SAMPLE_NETWORK.issued_sequence===1,'a new action attempt was issued to hide interruption');
  check(client.SAMPLE_NETWORK.action_outcomes[1]===1&&host.SAMPLE_NETWORK.action_outcomes[1]===1,'original action outcome did not reconcile exactly once');
  report.original_attempt_outcome={sequence:1,client_applied:client.SAMPLE_NETWORK.action_applied[1],host_applied:host.SAMPLE_NETWORK.action_applied[1]};
 }else if(flow==='cold'){
  check(client.SAMPLE_NETWORK.resumed_prior_actions&&client.SAMPLE_NETWORK.issued_sequence===0,'cold return issued an old scripted action as a new attempt');
  check(client.SAMPLE_NETWORK.boost_fx===0,'cold return replayed an old boost effect');report.cold_membership_return=true;
 }else if(!['hostloss','hostfrozen'].includes(flow)){
  check(client.SAMPLE_NETWORK.issued_sequence===1&&client.SAMPLE_NETWORK.max_prediction_ahead<=8,'impaired client exceeded prediction or reissued action');
  report.impaired_full_state_restored=true;
 }
 check(Object.values(actors).every(a=>a.SAMPLE_WEB_FRAME.signature_base64===host.SAMPLE_WEB_FRAME.signature_base64),'complete signatures differ');
 report.all_five_byte_equal=true;report.result='PASS';
}catch(e){report.error=String(e.stack||e);}
finally{
 report.clipboard_restored=await restoreClipboard();
 for(const a of Object.values(actors)){
  if(report.result!=='PASS')try{await a.page.screenshot({path:path.join(output,a.role,'failed-menu.png')});}catch{}
  if(!a.shutdown)try{
   await a.page.evaluate(()=>{engine.requestQuit();});
   const until=Date.now()+15000;while(!a.shutdown&&Date.now()<until)await delay(50);
  }catch(error){errors.push(a.role+': checked failure shutdown '+String(error));}
  if(a.shutdown)try{await runtimeExited(a);}catch(error){errors.push(a.role+': full runtime exit '+String(error));}
  report[a.role]=Object.fromEntries(Object.entries(a).filter(([k])=>!['browser','page','previous_clipboard'].includes(k)));await a.browser.close();
 }
 if(errors.length)report.result='FAIL';
 report.errors=errors;fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));
process.exit(report.result==='PASS'?0:1);
