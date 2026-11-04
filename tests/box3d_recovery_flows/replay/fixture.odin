package replay_recovery_flows_test

import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import v "godot:replay/view"
import game "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"
import bounds "godot:tests/box3d_bounds/replay"

Raw :: struct {bytes:[]u8,from:tr.Peer_Id,channel:tr.Channel,meta:sc.Envelope_Meta,hash:bd.Digest}
Packets :: struct {rows:[128]Raw,count,total:int}
Effects :: struct {
 rows:[256]r.Occurrence(net.Net_Event(game.Event)),count,duplicates,unconfirmed:int,
}
Flow :: struct {
 p:bounds.Pair,
 observer:net.Client(game.Game,game.Control,game.Action,game.Event,2),
 observer_endpoint,replacement_endpoint:tr.Memory_Endpoint,
 remote:tr.Peer_Id,initial:u32,
 driver_fx,observer_fx:Effects,
}
Old :: struct {input,facts,chunks,ack:Packets}
none :: proc(t:^testing.T,error:net.Error,label:string)->bool{return bounds.none(t,error,label)}
check :: proc(t:^testing.T,value:bool,label:string)->bool{return bounds.check(t,value,label)}

advance :: proc(t:^testing.T,c:^Flow,to:u64)->bool {
 if !check(t,to>=c.p.memory.now,"monotonic public Memory time"){return false}
 for _ in 0..<16 {
  if c.p.memory.now==to{return check(t,tr.memory_advance(&c.p.memory,to),"actual same-time Memory service")}
  if !check(t,tr.memory_advance(&c.p.memory,min(to,c.p.memory.now+10000)),"bounded public Memory advance"){return false}
 }
 return check(t,c.p.memory.now==to,"bounded fixture time advance completed")
}
empty :: proc(t:^testing.T){
 n,ns:=b.engine_allocation_stats();w,ws:=b.snapshot_allocation_stats();p:=ph.allocation_stats()
 contract,cs:=b.domain_contract_get();ledger,ls:=b.host_ledger_get(contract.cookie)
 check(t,ns==.Ok&&ws==.Ok&&cs==.Ok&&ls==.Ok&&n.live_bytes==0&&w.live_bytes==0&&p.live_bytes==0&&ledger.admitted_bytes==0&&ledger.owner_count==0,"all Native/provider/host owners returned")
 fmt.printf("REPLAY_FLOW_CLEANUP native=%d wrapper=%d provider=%d admitted=%d owners=%d\n",n.live_bytes,w.live_bytes,p.live_bytes,ledger.admitted_bytes,ledger.owner_count)
}
close :: proc(t:^testing.T,c:^Flow,expect_empty:bool=true){
 if c.observer.initialized{none(t,net.client_destroy(&c.observer),"observer destroy")}
 if c.p.client.initialized{none(t,net.client_destroy(&c.p.client),"driver destroy")}
 if c.p.server.initialized{none(t,net.server_destroy(&c.p.server),"authority destroy")}
 for endpoint in ([?]^tr.Memory_Endpoint{&c.p.endpoints[0],&c.p.endpoints[1],&c.observer_endpoint,&c.replacement_endpoint}) {
  if endpoint.live{wire:=tr.memory_transport(endpoint);tr.close(&wire)}
 }
 if len(c.p.memory.packets)!=0{tr.memory_destroy(&c.p.memory)}
 if c.p.codec.ready{none(t,ph.network_codec_destroy(&c.p.codec),"codec destroy")}
 if c.p.catalog_ready{check(t,b.recovery_catalog_destroy(&c.p.catalog)==.Ok,"catalog destroy");c.p.catalog_ready=false}
 if expect_empty{empty(t)}
}
authority :: proc(t:^testing.T,c:^Flow,initial:u32=4)->bool {
 c.remote=2;c.initial=initial
 cfg:=b.recovery_config_default();cfg.profile=game.PROFILE;assets:=game.assets();status:b.Status
 c.p.catalog,status=b.recovery_catalog_create(cfg,assets[:]);if !check(t,status==.Ok,"real shared catalog"){return false};c.p.catalog_ready=true
 world,value,ws:=game.world(initial,17);if !check(t,ws==.Ok,"actual shared Game/Native world"){return false}
 config:=adapter.config(&c.p.catalog,initial)
 checkpoint,ce:=ph.checkpoint_make(r.Frame(game.Game){state=value},net.Net_Event(game.Event),world,config,catalog=&c.p.catalog)
 check(t,b.world_destroy(&world)==.Ok,"source world checked destroy")
 if !check(t,ce==.None,"complete initial checkpoint"){return false};defer check(t,r.complete_checkpoint_destroy(&checkpoint)==.None,"initial checkpoint checked drop")
 if !none(t,ph.network_codec_init(&c.p.codec,&c.p.catalog,config,adapter.rules(initial,17)),"real shared codec"){return false}
 if !check(t,tr.memory_init(&c.p.memory,cfg={4,64,tr.MAX_PACKET_BYTES,8192}),"bounded Memory"){return false}
 if !check(t,tr.memory_open(&c.p.memory,&c.p.endpoints[0],1),"actual authority endpoint"){return false}
 network:=net.physics_config_default();network.snapshot_every=1
 if !none(t,net.server_init_complete(&c.p.server,&checkpoint,adapter.model(&c.p.codec),tr.memory_transport(&c.p.endpoints[0]),network,local_seat=1),"complete authority"){return false}
 if !none(t,net.server_set_local_token(&c.p.server,net.Token{0=1}),"authority token"){return false}
 return true
}
progress_alone :: proc(t:^testing.T,c:^Flow,ticks:int)->bool {
 for _ in 0..<ticks {
  now:=(c.p.server.timeline.head+1)*17
  if !advance(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"pre-enrollment pump")||!none(t,net.server_local(&c.p.server,game.Control{x=10}),"pre-enrollment control")||!none(t,net.server_step(&c.p.server),"real pre-enrollment progression"){return false}
 }
 return true
}
drain_fx :: proc(t:^testing.T,client:^net.Client(game.Game,game.Control,game.Action,game.Event,2),out:^Effects)->bool {
 changes:[320]v.Change(net.Net_Event(game.Event))
 for _ in 0..<64 {
  count:=v.drain(&client.journal,changes[:]);if count==0{return true}
  for change in changes[:count] {
   if change.occurrence.value.kind!=.Gameplay{continue}
   if !change.confirmed{out.unconfirmed+=1;continue}
   duplicate:=false;for prior in out.rows[:out.count]{if prior.id==change.occurrence.id{duplicate=true;break}}
   if duplicate{out.duplicates+=1;continue}
   if !check(t,out.count<len(out.rows),"bounded confirmed FX observer"){return false}
   out.rows[out.count]=change.occurrence;out.count+=1
  }
 }
 return check(t,false,"journal drain bound")
}
pump_clients :: proc(t:^testing.T,c:^Flow,now:u64)->bool {
 if !advance(t,c,now){return false}
 if c.p.client.initialized {
  if !none(t,net.client_pump(&c.p.client,now),"public driver pump")||!drain_fx(t,&c.p.client,&c.driver_fx){return false}
 }
 if c.observer.initialized {
  if !none(t,net.client_pump(&c.observer,now),"public observer pump")||!drain_fx(t,&c.observer,&c.observer_fx){return false}
 }
 return true
}
same_client :: proc(t:^testing.T,c:^Flow,client:^net.Client(game.Game,game.Control,game.Action,game.Event,2))->bool {
 tick:=min(c.p.server.timeline.head,client.timeline.confirmed)
 left,le:=r.capture_complete(&c.p.server.timeline,tick);if !check(t,le==.None,"authority complete5 capture"){return false};defer r.complete_checkpoint_destroy(&left)
 right,re:=r.capture_complete(&client.timeline,tick);if !check(t,re==.None,"recipient complete5 capture"){return false};defer r.complete_checkpoint_destroy(&right)
 return check(t,bounds.same5(t,&c.p,&left,&right),"actual all five canonical byte parts agree")
}
settle :: proc(t:^testing.T,c:^Flow)->bool {
 for _ in 0..<16 {
  now:=max(c.p.memory.now,max(c.p.server.now,c.p.client.now))+1
  if !pump_clients(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"real ACK/queued authority work"){return false}
  if c.p.client.phase==.Running&&c.p.client.timeline.confirmed>=c.p.server.timeline.head&&(!c.observer.initialized||(c.observer.phase==.Running&&c.observer.timeline.confirmed>=c.p.server.timeline.head)){return true}
 }
 return check(t,false,"bounded genuine convergence")
}
enroll :: proc(t:^testing.T,c:^Flow,observer:bool=false)->bool {
 before:=c.p.server.timeline.head;network:=net.physics_config_default();network.snapshot_every=1
 if observer {
  if !check(t,tr.memory_open(&c.p.memory,&c.observer_endpoint,3),"late observer endpoint"){return false}
  if !none(t,net.client_init(&c.observer,adapter.model(&c.p.codec),tr.memory_transport(&c.observer_endpoint),net.Token{0=3},spectator=true,cfg=network),"public late observer constructor"){return false}
 }else{
  if !check(t,tr.memory_open(&c.p.memory,&c.p.endpoints[1],2),"late driver endpoint"){return false}
  if !none(t,net.client_init(&c.p.client,adapter.model(&c.p.codec),tr.memory_transport(&c.p.endpoints[1]),net.Token{0=2},cfg=network),"public late driver constructor"){return false}
 }
 now:=c.p.memory.now
 if !pump_clients(t,c,now)||!advance(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"actual enrollment Hello")||!none(t,net.server_step(&c.p.server),"actual membership tick")||!settle(t,c){return false}
 if !check(t,c.p.server.timeline.head>before,"authority advanced its real membership tick"){return false}
 return observer?same_client(t,c,&c.observer):same_client(t,c,&c.p.client)
}
pair_step :: proc(t:^testing.T,c:^Flow)->bool {
 now:=max(c.p.memory.now,c.p.server.now)+17
 if !advance(t,c,now){return false}
 if !none(t,net.client_step(&c.p.client,game.Control{x=-20,z=5}),"actual future driver control"){return false}
 if !pump_clients(t,c,now)||!advance(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"actual remote control receive")||!none(t,net.server_local(&c.p.server,game.Control{x=25,z=-5}),"actual local control")||!none(t,net.server_step(&c.p.server),"ordinary authority step"){return false}
 return settle(t,c)
}
future :: proc(t:^testing.T,c:^Flow)->bool {
 // A separate observed suffix, not a retiming or filter of old issued actions.
 if !drain_fx(t,&c.p.client,&c.driver_fx){return false}
 c.driver_fx={};if c.observer.initialized{if !drain_fx(t,&c.observer,&c.observer_fx){return false};c.observer_fx={}}
 first:=c.p.server.timeline.head+1
 sequence,error:=net.client_issue(&c.p.client,game.Action{kind=.Motor});if !none(t,error,"one eligible future Motor"){return false}
 nonzero:[2]u64;settled:=false;motor_serial:u64
 for _ in 0..<24 {
  if !pair_step(t,c){return false}
  tick:=c.p.server.timeline.head;input,found:=r.read_input(&c.p.server.timeline,tick)
  if !check(t,found,"actual committed future controls"){return false}
  for value,seat in input.controls{if value.x!=0||value.z!=0{nonzero[seat]+=1}}
  entry,accepted:=net.server_accepted_input(&c.p.server,tick)
  if accepted&&entry.batch.has_action[1]&&entry.batch.sequences[1]==sequence&&entry.decisions.applied[1]{settled=true}
  events:[net.WIRE_EVENTS]r.Occurrence(net.Net_Event(game.Event));n,ee:=r.copy_events(&c.p.server.timeline,tick,events[:])
  if !check(t,ee==.None,"actual authority eligible FX"){return false}
  for event in events[:n]{if event.value.kind==.Gameplay&&event.value.value.kind==.Motor&&event.value.value.seat==2{motor_serial=event.value.value.serial}}
 }
 outcomes:[16]net.Action_Outcome;n:=net.client_outcomes(&c.p.client,outcomes[:]);matches:=0
 for outcome in outcomes[:n]{if outcome.sequence==sequence&&outcome.applied&&outcome.reason==.None{matches+=1}}
 if !check(t,settled&&matches==1&&nonzero[0]>0&&nonzero[1]>0&&motor_serial!=0,"actual future two-seat controls and exactly one settled action"){return false}
 for out in ([?]^Effects{&c.driver_fx,c.observer.initialized?&c.observer_fx:nil}) {
  if out==nil{continue};eligible:=0
  for event in out.rows[:out.count]{
   expected:[net.WIRE_EVENTS]r.Occurrence(net.Net_Event(game.Event));count,ce:=r.copy_events(&c.p.server.timeline,event.id.tick,expected[:]);found:=false
   if ce==.None{for real in expected[:count]{if reflect.equal(real,event){found=true;break}}}
   if !check(t,event.id.tick>=first&&found,"no spurious confirmed gameplay FX"){return false}
   if event.value.value.kind==.Motor&&event.value.value.serial==motor_serial{eligible+=1}
  }
  if !check(t,out.duplicates==0&&eligible==1,"eligible authoritative FX delivered exactly once"){return false}
 }
 if !same_client(t,c,&c.p.client){return false}
 return !c.observer.initialized||same_client(t,c,&c.observer)
}

append_packet :: proc(t:^testing.T,out:^Packets,bytes:[]u8,from:tr.Peer_Id,channel:tr.Channel)->bool {
 meta,_,report:=sc.inspect(bytes);if !check(t,report.error==.None,"real packet envelope"){return false}
 if !check(t,out.count<len(out.rows)&&out.total+len(bytes)<=8*net.COMPLETE_MAX_BYTES,"bounded actual packet retention"){return false}
 copy_bytes:=make([]u8,len(bytes));copy(copy_bytes,bytes);out.rows[out.count]={copy_bytes,from,channel,meta,bd.hash_bytes(bytes)};out.count+=1;out.total+=len(bytes);return true
}
capture :: proc(t:^testing.T,wire:^tr.Transport,out:^Packets)->bool {
 scratch:[tr.MAX_PACKET_BYTES]u8
 for _ in 0..<65 {
  packet:=tr.receive(wire,scratch[:]);if packet.state==.Empty{return true}
  if !check(t,packet.state==.Received,"actual public receive capture")||!append_packet(t,out,scratch[:packet.count],packet.from,packet.channel){return false}
 }
 return check(t,false,"Memory capture drain bound")
}
drop :: proc(p:^Packets){for &item in p.rows[:p.count]{delete(item.bytes);item={}};p^={}}
drop_old :: proc(p:^Old){drop(&p.input);drop(&p.facts);drop(&p.chunks);drop(&p.ack)}
deliver :: proc(t:^testing.T,packets:^Packets,sender:^tr.Transport,to:tr.Peer_Id)->bool {
 for packet in packets.rows[:packets.count]{if !check(t,bd.hash_bytes(packet.bytes)==packet.hash,"retained raw packet unchanged")||!check(t,tr.send(sender,to,packet.channel,packet.bytes)==.Sent,"actual packet delivery"){return false}}
 return true
}
retain_kinds :: proc(t:^testing.T,c:^Flow,packets:^Packets,old:^Old)->bool {
 for packet in packets.rows[:packets.count] {
  _,fingerprint,report:=sc.inspect(packet.bytes);if !check(t,report.error==.None,"captured schema identity"){return false}
  target:^Packets
  if fingerprint==c.p.server.codecs.inputs.fingerprint{target=&old.input}
  if fingerprint==c.p.server.physics.schemas.fact.fingerprint{target=&old.facts}
  if fingerprint==c.p.server.physics.schemas.chunk.fingerprint{target=&old.chunks}
  if fingerprint==c.p.server.physics.schemas.ack.fingerprint{target=&old.ack}
  if target!=nil{if !append_packet(t,target,packet.bytes,packet.from,packet.channel){return false}}
 }
 return true
}
record_old :: proc(t:^testing.T,c:^Flow,old:^Old)->bool {
 now:=max(c.p.memory.now,c.p.server.now)+17;if !advance(t,c,now){return false}
 if !none(t,net.client_step(&c.p.client,game.Control{x=-20}),"actual retained old input"){return false}
 remote:=c.p.client.wire;host:=tr.memory_transport(&c.p.endpoints[0]);packets:Packets;defer drop(&packets)
 if !advance(t,c,now)||!capture(t,&host,&packets)||!retain_kinds(t,c,&packets,old)||!deliver(t,&packets,&remote,1){return false};drop(&packets)
 if !advance(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"actual old input admission")||!none(t,net.server_local(&c.p.server,game.Control{x=25}),"local old input")||!none(t,net.server_step(&c.p.server),"actual old facts/signature/image"){return false}
 if !advance(t,c,now)||!capture(t,&remote,&packets)||!retain_kinds(t,c,&packets,old)||!deliver(t,&packets,&host,c.remote){return false};drop(&packets)
 if !advance(t,c,now)||!none(t,net.client_pump(&c.p.client,now),"actual old full-state receive"){return false}
 if !advance(t,c,now)||!capture(t,&host,&packets)||!retain_kinds(t,c,&packets,old)||!deliver(t,&packets,&remote,1){return false};drop(&packets)
 if !advance(t,c,now)||!none(t,net.server_pump(&c.p.server,now),"actual old ACK"){return false}
 if !check(t,old.input.count>0&&old.facts.count>0&&old.chunks.count>0&&old.ack.count>0,"real old input/facts+signature/chunks/ACK captured"){return false}
 return settle(t,c)
}
unchanged :: proc(t:^testing.T,c:^Flow,before:bounds.Published,checkpoint:^r.Complete_Checkpoint(game.Game,net.Net_Event(game.Event)))->bool {
 value,error:=r.capture_complete(&c.p.client.timeline,before.head)
 if !check(t,error==.None,"last published complete state retained"){return false};defer r.complete_checkpoint_destroy(&value)
 return check(t,reflect.equal(before,bounds.published(&c.p))&&bounds.same5(t,&c.p,checkpoint,&value),"scope/frontiers/held/pending/effects/complete5 unchanged")
}
bounded_memory :: proc(t:^testing.T)->b.Host_Ledger_Stats {
 contract,cs:=b.domain_contract_get();ledger,ls:=b.host_ledger_get(contract.cookie)
 check(t,cs==.Ok&&ls==.Ok&&ledger.limit_bytes==67108864&&ledger.admitted_bytes<=ledger.limit_bytes,"actual owned admission stays within unchanged64MiB")
 return ledger
}
