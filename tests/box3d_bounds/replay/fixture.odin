package replay_bounds_test

// Real shared Box3D Game/adapter, public complete Server/Client + Memory.
// Static Release/nil Owner scope; no Core/SDK or network-performance claim.
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

Pair :: struct {
 catalog:b.Recovery_Catalog,catalog_ready:bool,codec:adapter.Codec,
 memory:tr.Memory,endpoints:[2]tr.Memory_Endpoint,
 server:net.Server(game.Game,game.Control,game.Action,game.Event,2),
 client:net.Client(game.Game,game.Control,game.Action,game.Event,2),
}
Packet :: struct {bytes:[]u8,channel:tr.Channel,meta:sc.Envelope_Meta}
Packets :: struct {items:[64]Packet,count,total:int}
Transfer :: struct {
 packets:Packets,bytes:[]u8,header:net.Physics_Chunk_Header,meta:sc.Envelope_Meta,
 hash:bd.Digest,
}
Published :: struct {
 phase:net.Phase,head,confirmed,generation,serial,baseline,view_reset:u64,
 held:[2]game.Control,authority:r.Frame(game.Game),pending_id:u64,
 has_pending,pending_checkpoint:bool,journal_confirmed:u64,journal_count:int,
}
none :: proc(t:^testing.T,error:net.Error,label:string)->bool {
 testing.expect_value(t,error,net.Error.None)
 if error!=.None{fmt.printf("REPLAY_BOUNDS_SETUP label=%s error=%v\n",label,error);return false};return true
}
check :: proc(t:^testing.T,ok:bool,label:string)->bool {
 testing.expect(t,ok,label);if !ok{fmt.printf("REPLAY_BOUNDS_SETUP label=%s\n",label)};return ok
}
open :: proc(t:^testing.T,p:^Pair)->bool {
 config:=b.recovery_config_default();config.profile=game.PROFILE
 assets:=game.assets();status:b.Status;p.catalog,status=b.recovery_catalog_create(config,assets[:])
 testing.expect_value(t,status,b.Status.Ok);if status!=.Ok{return false};p.catalog_ready=true
 world,value,ws:=game.world(4,17);testing.expect_value(t,ws,b.Status.Ok);if ws!=.Ok{return false}
 provider:=adapter.config(&p.catalog,4)
 initial,error:=ph.checkpoint_make(r.Frame(game.Game){state=value},net.Net_Event(game.Event),world,provider,catalog=&p.catalog)
 testing.expect_value(t,b.world_destroy(&world),b.Status.Ok)
 testing.expect_value(t,error,r.Error.None);if error!=.None{return false};defer r.complete_checkpoint_destroy(&initial)
 if !none(t,ph.network_codec_init(&p.codec,&p.catalog,provider,adapter.rules(4,17)),"codec"){return false}
 if !check(t,tr.memory_init(&p.memory,cfg={2,64,tr.MAX_PACKET_BYTES,4096}),"Memory"){return false}
 for &endpoint,index in p.endpoints{if !check(t,tr.memory_open(&p.memory,&endpoint,tr.Peer_Id(index+1)),"endpoint"){return false}}
 model:=adapter.model(&p.codec);network:=net.physics_config_default();network.snapshot_every=1
 if !none(t,net.server_init_complete(&p.server,&initial,model,tr.memory_transport(&p.endpoints[0]),network,local_seat=1),"server"){return false}
 if !none(t,net.server_set_local_token(&p.server,net.Token{0=1}),"Host token"){return false}
 // Spectators genuinely import complete physics but execute no predicted Game
 // callback. A bad retirement count can therefore be observed without OOB work.
 if !none(t,net.client_init(&p.client,model,tr.memory_transport(&p.endpoints[1]),net.Token{0=2},cfg=network,spectator=true),"spectator"){return false}
 if !none(t,net.client_pump(&p.client,0),"Hello"){return false}
 tr.memory_advance(&p.memory,0)
 if !none(t,net.server_pump(&p.server,0),"Host Hello")||!none(t,net.server_step(&p.server),"real authority step"){return false}
 tr.memory_advance(&p.memory,0)
 if !none(t,net.client_pump(&p.client,0),"real complete Welcome"){return false}
 tr.memory_advance(&p.memory,0)
 if !none(t,net.server_pump(&p.server,0),"actual Welcome ACK"){return false}
 drain(p)
 return check(t,p.client.spectator&&p.client.has_world&&p.client.phase==.Running&&p.client.timeline.head==p.client.timeline.confirmed,"actual admitted complete spectator")
}
close :: proc(t:^testing.T,p:^Pair){
 if p.client.initialized{testing.expect_value(t,net.client_destroy(&p.client),net.Error.None)}
 if p.server.initialized{testing.expect_value(t,net.server_destroy(&p.server),net.Error.None)}
 if len(p.memory.packets)!=0{tr.memory_destroy(&p.memory)}
 if p.codec.ready{testing.expect_value(t,ph.network_codec_destroy(&p.codec),net.Error.None)}
 if p.catalog_ready{testing.expect_value(t,b.recovery_catalog_destroy(&p.catalog),b.Status.Ok)}
 native,ns:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();provider:=ph.allocation_stats()
 contract,cs:=b.domain_contract_get();ledger,ls:=b.host_ledger_get(contract.cookie)
 testing.expect(t,ns==.Ok&&ws==.Ok&&cs==.Ok&&ls==.Ok&&native.live_bytes==0&&wrapper.live_bytes==0&&provider.live_bytes==0&&ledger.admitted_bytes==0&&ledger.owner_count==0,"all real owners/bytes returned")
 fmt.printf("REPLAY_BOUNDS_CLEANUP native=%d wrapper=%d provider=%d admitted=%d owners=%d\n",native.live_bytes,wrapper.live_bytes,provider.live_bytes,ledger.admitted_bytes,ledger.owner_count)
}
drain :: proc(p:^Pair){changes:[320]v.Change(net.Net_Event(game.Event));for v.drain(&p.client.journal,changes[:])>0{}}
published :: proc(p:^Pair)->Published {
 c:=&p.client
 return {c.phase,c.timeline.head,c.timeline.confirmed,c.generation,c.serial,c.baseline,c.view_reset,c.held,c.authority_frame,c.pending.snapshot_id,c.has_pending,c.physics.pending_checkpoint!=nil,c.journal.confirmed,c.journal.queue_count}
}
same5 :: proc(t:^testing.T,p:^Pair,left,right:^r.Complete_Checkpoint(game.Game,net.Net_Event(game.Event)))->bool {
 a,ae:=net.complete_view(p.codec.value,left,&p.server.physics.schemas.state,&p.server.physics.schemas.occurrence)
 if !none(t,ae,"left complete5"){return false};defer net.complete_view_destroy(&a)
 z,ze:=net.complete_view(p.codec.value,right,&p.server.physics.schemas.state,&p.server.physics.schemas.occurrence)
 if !none(t,ze,"right complete5"){return false};defer net.complete_view_destroy(&z)
 equal:=true;for part in bd.Part{equal=equal&&mem.compare(a.frame.parts[part],z.frame.parts[part])==0}
 return equal
}
pair_same :: proc(t:^testing.T,p:^Pair)->bool {
 tick:=p.server.timeline.head
 a,ae:=r.capture_complete(&p.server.timeline,tick);if !check(t,ae==.None,"authority complete capture"){return false};defer r.complete_checkpoint_destroy(&a)
 z,ze:=r.capture_complete(&p.client.timeline,tick);if !check(t,ze==.None,"recipient complete capture"){return false};defer r.complete_checkpoint_destroy(&z)
 return check(t,p.client.timeline.confirmed>=tick&&same5(t,p,&a,&z),"real confirmed pair complete5")
}
drop_packets :: proc(p:^Packets){for &item in p.items[:p.count]{delete(item.bytes);item={}};p^={}}
drop_transfer :: proc(x:^Transfer){drop_packets(&x.packets);delete(x.bytes);x^={}}
collect :: proc(t:^testing.T,p:^Pair,now:u64,x:^Transfer,purpose:net.Complete_Purpose)->bool {
 tr.memory_advance(&p.memory,now);wire:=tr.memory_transport(&p.endpoints[1]);scratch:[tr.MAX_PACKET_BYTES]u8
 found:=false
 for _ in 0..<65 {
  packet:=tr.receive(&wire,scratch[:]);if packet.state==.Empty{break}
  if !check(t,packet.state==.Received&&x.packets.count<len(x.packets.items),"bounded actual packet capture"){return false}
  meta,fingerprint,report:=sc.inspect(scratch[:packet.count]);if !check(t,report.error==.None,"actual envelope"){return false}
  bytes:=make([]u8,packet.count);copy(bytes,scratch[:packet.count]);x.packets.items[x.packets.count]={bytes,packet.channel,meta};x.packets.count+=1;x.packets.total+=len(bytes)
  if fingerprint!=p.client.physics.schemas.chunk.fingerprint{continue}
  _,body,ur:=sc.unpack_bytes(fingerprint,bytes,meta);size:=p.client.physics.schemas.chunk.wire_size
  if !check(t,ur.error==.None&&len(body)>=size,"public chunk schema"){return false}
  header:net.Physics_Chunk_Header
  if !check(t,sc.decode(&p.client.physics.schemas.chunk,&header,body[:size]).error==.None,"real chunk header"){return false}
  if header.purpose==u32(purpose)&&!found{x.header=header;x.meta=meta;found=true}
 }
 if !found {
  fmt.printf("REPLAY_BOUNDS_TRANSFER_MISSING wanted=%v captured=%d bytes=%d server_now=%d client_now=%d head=%d cf=%d client_phase=%v client_rejection=%v generation=%d serial=%d server_wire=%v client_wire=%v\n",purpose,x.packets.count,x.packets.total,p.server.now,p.client.now,p.client.timeline.head,p.client.timeline.confirmed,p.client.phase,p.client.rejection,p.client.generation,p.client.serial,tr.status(&p.server.wire),tr.status(&p.client.wire))
  for packet,i in x.packets.items[:min(x.packets.count,8)] {
   fmt.printf("REPLAY_BOUNDS_TRANSFER_PACKET index=%d kind=%d epoch=%d tick=%d channel=%v bytes=%d\n",i,packet.meta.kind,packet.meta.epoch,packet.meta.tick,packet.channel,len(packet.bytes))
  }
  fmt.printf("REPLAY_BOUNDS_TRANSFER_PACKET_OMITTED count=%d\n",max(x.packets.count-8,0))
  for i in 0..<min(len(p.server.peers),4) {
   peer:=p.server.peers[i];tx:=p.server.physics.tx[i]
   fmt.printf("REPLAY_BOUNDS_TRANSFER_PEER index=%d phase=%v local=%v connection=%d generation=%d serial=%d last_seen=%d checkpoint_pending=%v tx_id=%d tx_tick=%d tx_generation=%d tx_serial=%d tx_purpose=%v tx_bytes=%d tx_part=%d tx_waiting_ack=%v\n",i,peer.phase,peer.local,peer.connection,peer.generation,peer.serial,peer.last_seen,peer.checkpoint_pending,tx.id,tx.tick,tx.generation,tx.serial,tx.purpose,len(tx.data.bytes),tx.part,tx.waiting_ack)
  }
  fmt.printf("REPLAY_BOUNDS_TRANSFER_PEER_OMITTED count=%d\n",max(len(p.server.peers)-4,0))
 }
 if !check(t,found&&x.packets.total<=2*net.COMPLETE_MAX_BYTES,"genuine bounded expected transfer"){return false}
 for tx in p.server.physics.tx {
  if tx.id==x.header.id&&tx.generation==x.header.generation&&tx.serial==x.header.serial&&tx.digest==x.header.digest&&tx.purpose==purpose {
   x.bytes=make([]u8,len(tx.data.bytes));copy(x.bytes,tx.data.bytes);break
  }
 }
 if !check(t,len(x.bytes)>0&&bd.hash_bytes(x.bytes)==x.header.digest,"actual authority tx image and captured header agree"){return false}
 x.hash=bd.hash_bytes(x.bytes)
 inspection,error:=net.complete_inspect(x.bytes,p.codec.value.identity,p.server.cfg.epoch)
 return check(t,error==.None&&inspection.signature.tick==x.meta.tick&&inspection.purpose==purpose,"genuine image complete5/current epoch")
}
deliver_original :: proc(t:^testing.T,p:^Pair,x:^Transfer,parts:bool)->bool {
 sender:=tr.memory_transport(&p.endpoints[0])
 for packet in x.packets.items[:x.packets.count]{
  _,fingerprint,report:=sc.inspect(packet.bytes);if !check(t,report.error==.None,"retained envelope intact"){return false}
  is_part:=fingerprint==p.client.physics.schemas.chunk.fingerprint
  if is_part!=parts{continue}
  if !check(t,tr.send(&sender,2,packet.channel,packet.bytes)==.Sent,"original actual authority delivery"){return false}
 }
 return true
}
// Uses ONLY exported compiled field metadata and a public scalar encoder. No
// Snapshot/Welcome private type, offset mirror or private protocol parser.
scalar_mutation :: proc(t:^testing.T,schema:^sc.Schema,metadata:[]u8,path:string,value:$T)->bool {
 index,found:=sc.field_index(schema,path);if !check(t,found,fmt.tprintf("actual metadata field: %s",path)){return false}
 field:=schema.fields[index];leaf:sc.Schema
 if !check(t,sc.init(&leaf,T).error==.None,"public scalar schema"){return false};defer sc.destroy(&leaf)
 if !check(t,field.width==leaf.wire_size&&field.wire_offset>=0&&field.wire_offset+field.width<=len(metadata),"bounded actual compiled field span"){return false}
 return check(t,sc.encode(&leaf,value,metadata[field.wire_offset:field.wire_offset+field.width]).error==.None,"public scalar mutation encode")
}
send_candidate :: proc(t:^testing.T,p:^Pair,source:^Transfer,data:^net.Complete_Data,sent:^Packets)->bool {
 sender:=tr.memory_transport(&p.endpoints[0]);header:=source.header
 header.total=u32(len(data.bytes));header.parts=u32((len(data.bytes)+net.COMPLETE_PART_BYTES-1)/net.COMPLETE_PART_BYTES);header.digest=bd.hash_bytes(data.bytes)
 if !check(t,header.parts>0&&header.parts<=32,"same bounded complete transport"){return false}
 for i in 0..<int(header.parts){
  header.index=u32(i);first:=i*net.COMPLETE_PART_BYTES;last:=min(first+net.COMPLETE_PART_BYTES,len(data.bytes));size:=p.server.physics.schemas.chunk.wire_size
  body:=make([]u8,size+last-first);defer delete(body)
  if !check(t,sc.encode(&p.server.physics.schemas.chunk,header,body[:size]).error==.None,"public chunk encode"){return false}
  copy(body[size:],data.bytes[first:last]);bytes:=make([]u8,sc.HEADER_BYTES+len(body))
  if sc.pack_bytes(p.server.physics.schemas.chunk.fingerprint,source.meta,body,bytes).error!=.None{delete(bytes);return check(t,false,"public envelope pack")}
  if !check(t,sent.count<len(sent.items),"bounded candidate packet retention"){delete(bytes);return false}
  sent.items[sent.count]={bytes,.Reliable,source.meta};sent.count+=1;sent.total+=len(bytes)
  if !check(t,tr.send(&sender,2,.Reliable,bytes)==.Sent,"actual authority endpoint sends malicious candidate"){return false}
 }
 return true
}
after_rejected :: proc(t:^testing.T,p:^Pair,before:Published,original:^r.Complete_Checkpoint(game.Game,net.Net_Event(game.Event)),rejected:u64)->bool {
 state_same:=reflect.equal(before,published(p))
 after,error:=r.capture_complete(&p.client.timeline,before.head)
 full5:=error==.None
 if full5{full5=same5(t,p,original,&after);r.complete_checkpoint_destroy(&after)}
 valid:=p.client.stats.rejected_packets>rejected&&state_same&&full5
 testing.expect(t,valid,"malicious candidate must reject before pending/publication/held/frontier/effect change")
 fmt.printf("REPLAY_BOUNDS_REJECTION rejected_delta=%d published_same=%v original5_same=%v head=%d cf=%d phase=%v\n",p.client.stats.rejected_packets-rejected,state_same,full5,p.client.timeline.head,p.client.timeline.confirmed,p.client.phase)
 return valid
}
resume :: proc(t:^testing.T,p:^Pair,now:u64)->bool {
 tr.memory_advance(&p.memory,now)
 if !none(t,net.server_pump(&p.server,now),"real valid ACK"){return false}
 if !none(t,net.server_step(&p.server),"continued real valid authority step"){return false}
 tr.memory_advance(&p.memory,now)
 if !none(t,net.client_pump(&p.client,now),"continued complete recipient work"){return false}
 return pair_same(t,p)
}
// The public reconnect preserves the prior complete Timeline. The old real
// peer is first expired by server_pump at its UNCHANGED configured timeout;
// a genuine Hello/Welcome creates the replacement generation, never setters.
new_welcome :: proc(t:^testing.T,p:^Pair,x:^Transfer)->(u64,bool){
 now:=max(p.server.now,p.client.now)+p.server.cfg.timeout_ms+1
 // Memory accepts at most10000 per call. This fixture's unchanged10000ms
 // timeout needs that legal boundary followed by one actual service tick.
 if !check(t,tr.memory_advance(&p.memory,now-1),"Memory reaches configured timeout boundary"){return now,false}
 if !check(t,tr.memory_advance(&p.memory,now),"Memory crosses actual peer timeout"){return now,false}
 if !none(t,net.server_pump(&p.server,now),"ordinary peer timeout"){return now,false}
 if !none(t,net.client_reconnect(&p.client,tr.memory_transport(&p.endpoints[1])),"public reconnect"){return now,false}
 if !none(t,net.client_pump(&p.client,now),"real replacement Hello"){return now,false}
 if !check(t,tr.memory_advance(&p.memory,now),"Memory services real replacement Hello"){return now,false}
 if !none(t,net.server_pump(&p.server,now),"admit actual replacement peer")||!none(t,net.server_step(&p.server),"real Welcome authority step"){return now,false}
 return now,collect(t,p,now,x,.Welcome)
}
