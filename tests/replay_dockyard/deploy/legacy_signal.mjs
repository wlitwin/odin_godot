import WebSocket from '../../web/node_modules/ws/wrapper.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';

const [url, output]=process.argv.slice(2);
if(!url||!output)throw Error('provide signal URL and a new report path');
const sockets=[];
const wait=async predicate=>{
 const until=Date.now()+10000;
 while(Date.now()<until){const value=predicate();if(value)return value;await new Promise(r=>setTimeout(r,10));}
 throw Error('bounded legacy signaling exchange');
};
async function open(){
 const socket=new WebSocket(url,{rejectUnauthorized:true,handshakeTimeout:8000});
 const actor={socket,rows:[],errors:[]};sockets.push(actor);
 socket.on('message',data=>actor.rows.push(JSON.parse(data.toString())));
 socket.on('error',error=>actor.errors.push(error.name+': '+error.message));
 await wait(()=>{if(actor.errors.length)throw Error(actor.errors[0]);return socket.readyState===WebSocket.OPEN;});
 return actor;
}
let result;
try{
 const host=await open();host.socket.send(JSON.stringify({type:'create'}));
 const created=await wait(()=>host.rows.find(x=>x.type==='created'));
 const guest=await open();guest.socket.send(JSON.stringify({type:'join',room:created.room}));
 const joined=await wait(()=>guest.rows.find(x=>x.type==='joined'));
 assert.equal(created.id,1);assert.equal(joined.id,2);
 await wait(()=>host.rows.find(x=>x.type==='peer'&&x.id===2));
 const forward={purpose:'legacy-compatibility-probe',nonce:randomBytes(16).toString('hex')};
 host.socket.send(JSON.stringify({type:'signal',to:2,data:forward}));
 const received=await wait(()=>guest.rows.find(x=>x.type==='signal'));
 assert.equal(received.from,1);assert.deepEqual(received.data,forward);
 const reply={reply:forward.nonce};guest.socket.send(JSON.stringify({type:'signal',to:1,data:reply}));
 assert.deepEqual((await wait(()=>host.rows.find(x=>x.type==='signal'))).data,reply);
 assert.deepEqual(host.errors,[]);assert.deepEqual(guest.errors,[]);
 result={result:'PASS',url,legacy_create_join_presence_and_bidirectional_opaque_signal:true,
  authenticated_turn_offered:(created.ice||[]).some(x=>x.username&&x.credential),
  scope:'Two owned ephemeral legacy peers; no existing player room joined. No gameplay or external-network inference.'};
}catch(error){result={result:'FAIL',url,error:String(error.stack||error)};}
finally{
 for(const actor of sockets){
  if(actor.socket.readyState===WebSocket.OPEN){actor.socket.send(JSON.stringify({type:'leave'}));actor.socket.close(1000);}
 }
 await Promise.all(sockets.map(a=>a.socket.readyState===WebSocket.CLOSED?null:new Promise(resolve=>{
  const timer=setTimeout(()=>{a.socket.terminate();resolve();},2000);a.socket.once('close',()=>{clearTimeout(timer);resolve();});
 })));
 result.own_peers_closed=sockets.every(a=>a.socket.readyState===WebSocket.CLOSED);
 fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
}
console.log(JSON.stringify(result));process.exit(result.result==='PASS'?0:1);
