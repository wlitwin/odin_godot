// A hidden timer loop must still obey the coordinator's real lease on freeze.
import fs from 'node:fs';
import path from 'node:path';
import {actors,errors,report,open,delay,check,productionEnrollment,output,restoreClipboard} from './drive.mjs';
report.result='FAIL';report.scope='Actual browser freeze and hosting-lease fencing with the ordinary production export. No background-throttling or lease override.';
try{
 const host=await open('host');console.log('N1_COHORT '+host.cohort);
 let until=Date.now()+45000;while(!fs.existsSync(path.join(output,'service.ready'))&&Date.now()<until)await delay(100);
 check(fs.existsSync(path.join(output,'service.ready')),'service acknowledgement unavailable');
 const client=await productionEnrollment(host);
 until=Date.now()+30000;while((client.SAMPLE_STATUS?.confirmed||0)<120&&!errors.length&&Date.now()<until)await delay(50);
 check(client.SAMPLE_STATUS?.confirmed>=120,'established world unavailable');
 const cover=await host.browser.newPage();await cover.bringToFront();
 report.visibility_before=await host.page.evaluate(()=>document.visibilityState);
 const cdp=await host.page.createCDPSession(),start=performance.now();
 await cdp.send('Page.setWebLifecycleState',{state:'frozen'});await delay(3300);
 await cdp.send('Page.setWebLifecycleState',{state:'active'});await cover.close();await host.page.bringToFront();
 report.frozen_ms=performance.now()-start;await cdp.detach();
 until=Date.now()+15000;while(!host.SAMPLE_HOST_LOST&&!errors.length&&Date.now()<until)await delay(50);
 check(report.visibility_before==='hidden'&&report.frozen_ms>=3300&&host.SAMPLE_HOST_LOST&&host.DOCKYARD_CONNECTION?.message?.includes('Hosting permission ended'),'frozen authority did not fence');
 report.frozen_host_fenced=true;
 for(const actor of [host,client]){
  await actor.page.bringToFront();
  check(await actor.page.evaluate(()=>{if(typeof engine==='undefined'||!engine.rtenv)return false;engine.requestQuit();return true;}),'cooperative quit unavailable');
 }
 until=Date.now()+15000;while((!host.shutdown||!client.shutdown)&&Date.now()<until)await delay(50);
 check(host.shutdown&&client.shutdown,'typed shutdown unavailable');
 for(const actor of [host,client])await actor.page.waitForFunction(()=>typeof engine!=='undefined'&&engine.rtenv===null,{timeout:15000,polling:100});
 check(!errors.length,errors.join('\n'));report.full_engine_exit=true;report.result='PASS';
}catch(error){report.error=String(error.stack||error);}
finally{
 report.clipboard_restored=await restoreClipboard();report.errors=errors;
 for(const actor of Object.values(actors)){
  if(!actor.shutdown)try{await actor.page.bringToFront();await actor.page.evaluate(()=>engine?.requestQuit());}catch{}
  report[actor.role]={shutdown:actor.shutdown,version:actor.version};
 }
 for(const browser of new Set(Object.values(actors).map(a=>a.browser)))await browser.close();
 fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({result:report.result,error:report.error,report:path.join(output,'report.json')}));process.exitCode=report.result==='PASS'?0:1;
