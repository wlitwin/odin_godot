// Exercise the actual embedded storage helper in ordinary same-profile tabs.
import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import assert from 'node:assert/strict';
const [output, browserName='chrome'] = process.argv.slice(2);
fs.mkdirSync(output,{recursive:false,mode:0o700});
const source=fs.readFileSync(new URL('../../../replay/godot/storage/browser_seat.odin',import.meta.url),'utf8');
const script=source.match(/BROWSER_SEAT_JS :: `([\s\S]*?)`/)[1];
const server=http.createServer((_,res)=>{res.writeHead(200,{'Content-Type':'text/html'});res.end('<title>Browser seat test</title>');});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const url=`http://127.0.0.1:${server.address().port}/`,scope='dockyard-test/service';
const firefox=browserName==='firefox',report={result:'FAIL',browser:browserName,scope:'Actual browser seat JS, same default browser context; no gameplay claim.'};
let browser;
async function acquire(page){
 assert.equal(await page.evaluate(script),1);
 const id=await page.evaluate(scope=>ReplayBrowserSeatsV1.open(scope),scope);
 assert(id>0);await page.waitForFunction(id=>ReplayBrowserSeatsV1.poll(id)!==-2,{},id);
 return {id,seat:await page.evaluate(id=>ReplayBrowserSeatsV1.poll(id),id)};
}
try{
 browser=await puppeteer.launch({browser:firefox?'firefox':'chrome',protocol:firefox?'webDriverBiDi':'cdp',executablePath:firefox?'/Applications/Firefox.app/Contents/MacOS/firefox':'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,userDataDir:path.join(output,'profile'),args:firefox?['--no-remote']:['--no-sandbox']});
 report.version=await browser.version();
 const a=await browser.newPage();await a.goto(url);const first=await acquire(a);assert.equal(first.seat,0);
 const popup=await browser.waitForTarget(async target=>target.type()==='page'&&target.url()===url&&target!==a.target(),{timeout:1}).catch(()=>null);
 assert.equal(popup,null);
 const opened=new Promise(resolve=>a.once('popup',resolve));
 await a.evaluate(url=>window.open(url,'_blank'),url);const b=await opened;await b.waitForFunction(()=>document.readyState==='complete');
 assert.equal(await b.evaluate(scope=>sessionStorage.getItem('replay-party-seat-v1/'+scope),scope),'0');
 const second=await acquire(b);assert.equal(second.seat,1);report.copied_hint_isolated=true;
 const c=await browser.newPage();await c.goto(url);assert.equal((await acquire(c)).seat,2);report.three_concurrent_seats=true;
 await b.reload();const reloaded=await acquire(b);assert.equal(reloaded.seat,1);report.reload_retains_seat=true;
 await b.close();
 await a.waitForFunction(scope=>navigator.locks.query().then(q=>!q.held.some(l=>l.name==='replay-party-seat-v1/'+scope+'/1')),{},scope);
 const d=await browser.newPage();await d.goto(url);const reused=await acquire(d);assert.equal(reused.seat,1);report.closed_seat_reused=true;
 await a.evaluate(id=>ReplayBrowserSeatsV1.close(id),first.id);
 await a.waitForFunction(scope=>navigator.locks.query().then(q=>!q.held.some(l=>l.name==='replay-party-seat-v1/'+scope+'/0')),{},scope);
 const e=await browser.newPage();await e.goto(url);assert.equal((await acquire(e)).seat,0);report.legacy_seat_recovered=true;
 // Teardown while acquisition is pending must not leave an orphaned lock.
 await e.evaluate(()=>{const id=ReplayBrowserSeatsV1.open('cancelled');ReplayBrowserSeatsV1.close(id);});
 await e.waitForFunction(()=>navigator.locks.query().then(q=>!q.held.some(l=>l.name.startsWith('replay-party-seat-v1/cancelled/'))));
 report.pending_close_releases=true;
 assert.equal(await e.evaluate(()=>ReplayBrowserSeatsV1.open("bad'key")),0);
 report.result='PASS';
}catch(error){report.error=String(error.stack||error);}
finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify(report));process.exitCode=report.result==='PASS'?0:1;
