// CASE_A only. Generic4/staticNative/nilOwner; controlled Memory reorder,
// NOT SDK32/ENet ordering/old-live-cause evidence.
package action_scope_case_a

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import view "godot:replay/view"
import ar "godot:tests/box3d_soak/replay/action_retire"
import f "godot:tests/replay_physics_net/fixture"

ACTION_KIND :: u16(5) // passive protocol.odin Kind observation; never packed here
MAX_SAVED :: 256
MAX_SAVED_BYTES :: 1024*1024
Wire_Action :: struct {epoch,generation,serial,sequence,tick:u64,value:f.Action,hash:bd.Digest,channel:tr.Channel}
Saved :: struct {data:net.Complete_Data,packet:tr.Received,kind:u16,tick:u64,snapshot,held,released:bool,hash:bd.Digest}
Gate :: struct {
 base:tr.Transport,codec:^ph.Network_Codec(f.Game,f.Control,f.Action,f.Event,2),chunk:^sc.Schema,
 saved:[MAX_SAVED]Saved,count:int,bytes:u64,hold_snapshots,release_snapshots,hold_first_action,release_old:bool,
 old_index:int,old_captured:bool,error:string,
}
Case :: struct {pair:ar.Pair,links:[2]rec.Link(f.Game,f.Control,f.Action,f.Event,2),gates:[2]Gate}
Reached :: struct {baseline_guard,action_issue,first_wire,resync_notice,welcome,resend,execution,full5,outcome,late_copy,cleanup:bool}
Snapshot_Diag :: struct {kind:u16,tick:u64,held,released:bool,channel:tr.Channel}
Client_State :: struct {observed:bool,phase:net.Phase,head,confirmed,generation,serial:u64}
Report :: struct {
 schema:u32,scope,stage:string,ok,setup_ok:bool,
 epoch,generation,old_serial,new_serial,original_requested,submitted,sequence,execution_tick:u64,
 player:net.Token,seat:u16,value:f.Action,
 first,resend:Wire_Action,
 pre_received,pre_count,new_received,new_count,settled,old_rejected_delta:u64,
 trigger:net.Resync_Notice,first_hash_unchanged,logical_unchanged,full5_equal,outcome_once,confirmed_result_once,old_state_unchanged:bool,
 native_live,wrapper_live,provider_live,odin_live:u64,all_drops_ok:bool,
 native_build,native_target:bd.Digest,
 reached:Reached,
 guard_client_phase:net.Phase,
 guard_client_head,guard_client_confirmed,guard_client_serial,guard_client_generation,guard_epoch:u64,
 guard_cfg_prediction,guard_cfg_future,guard_cfg_history,guard_cfg_snapshot_every,guard_cfg_lead,guard_actual_lead:u64,
 guard_catchups,guard_resyncs,guard_corrections,guard_replayed,guard_stalls,guard_facts,guard_authority_seen:u64,
 guard_server_head,guard_server_confirmed,guard_peer_serial,guard_peer_generation,guard_peer_received,guard_peer_settled:u64,
 guard_peer_found:bool,guard_peer_count:int,guard_peer_phase:i32,
 guard_snapshot_total,guard_snapshot_copied:int,guard_snapshot_overflow:bool,guard_snapshots:[8]Snapshot_Diag,
 release_before,release_after,after_ahead:Client_State,
 ack_observed,ack_matches:bool,ack:net.Physics_Ack,held_header:net.Physics_Chunk_Header,ack_hash:bd.Digest,
 ack_decode_status:sc.Error,
 ack_server_observed:bool,ack_server_head,ack_server_confirmed,ack_peer_serial,ack_peer_received:u64,ack_peer_count:int,
 ack_server_tx_tick,ack_server_tx_id:u64,ack_server_tx_purpose:net.Complete_Purpose,ack_server_tx_waiting:bool,
}

write_json :: proc(name:string,value:$T){bytes,e:=json.marshal(value);assert(e==nil);defer delete(bytes);assert(os.write_entire_file(name,bytes)==nil)}
client_state :: proc(p:^ar.Pair)->Client_State{return {true,p.client.phase,p.client.timeline.head,p.client.timeline.confirmed,p.client.generation,p.client.serial}}
check :: proc(t:^testing.T,yes:bool,stage:string)->bool {testing.expect(t,yes,stage);return yes}
none :: proc(t:^testing.T,e:net.Error,stage:string)->bool {return check(t,e==.None,fmt.tprintf("%s error=%v",stage,e))}
get64 :: proc(bytes:[]u8)->u64 {value:u64;for byte,i in bytes[:8]{value|=u64(byte)<<uint(i*8)};return value}
wire_action :: proc(c:^Case,saved:^Saved)->(out:Wire_Action,ok:bool){
 meta,payload,report:=sc.unpack_bytes(c.pair.client.codecs.action.fingerprint,saved.data.bytes,{kind=ACTION_KIND,epoch=c.pair.client.cfg.epoch,content=c.pair.client.cfg.content})
 if report.error!=.None || len(payload)!=32+c.pair.client.codecs.action_value.wire_size{return {},false}
 out={epoch=meta.epoch,generation=get64(payload[0:]),serial=get64(payload[8:]),sequence=get64(payload[16:]),tick=get64(payload[24:]),hash=saved.hash,channel=saved.packet.channel}
 if sc.decode(&c.pair.client.codecs.action_value,&out.value,payload[32:]).error!=.None{return {},false}
 return out,true
}
save :: proc(g:^Gate,packet:tr.Received,bytes:[]u8)->int {
 if g.count==MAX_SAVED || u64(len(bytes))>MAX_SAVED_BYTES-g.bytes {g.error="bounded capture exhausted";return -1}
 if g.codec.value.reserve(g.codec.value.catalog,u64(len(bytes)))!=.None{g.error="capture reserve";return -1}
 storage,e:=mem.alloc_bytes(len(bytes));if e!=.None{g.codec.value.release(g.codec.value.catalog,u64(len(bytes)));g.error="capture allocation";return -1};copy(storage,bytes)
 owned,oe:=net.complete_data_adopt(storage,context.allocator,g.codec.value)
 if oe!=.None{delete(storage);g.codec.value.release(g.codec.value.catalog,u64(len(bytes)));g.error="capture owner";return -1}
 meta,fingerprint,report:=sc.inspect(bytes);if report.error!=.None{net.complete_data_destroy(&owned);g.error="actual packet inspect";return -1}
 i:=g.count;g.count+=1;g.bytes+=u64(len(bytes));g.saved[i]={data=owned,packet=packet,kind=meta.kind,tick=meta.tick,hash=bd.hash_bytes(bytes)}
 if g.chunk!=nil && fingerprint==g.chunk.fingerprint {
  _,payload,re:=sc.unpack_bytes(g.chunk.fingerprint,bytes,{kind=meta.kind,epoch=meta.epoch,content=meta.content})
  header:net.Physics_Chunk_Header
  if re.error==.None && len(payload)>=g.chunk.wire_size && sc.decode(g.chunk,&header,payload[:g.chunk.wire_size]).error==.None {g.saved[i].snapshot=header.purpose==u32(net.Complete_Purpose.Snapshot)}
 }
 return i
}
gate_wire :: proc(g:^Gate)->tr.Transport {
 return {user=g,
 send=proc(p:rawptr,to:tr.Peer_Id,ch:tr.Channel,bytes:[]u8)->tr.Send_Result{return tr.send(&(cast(^Gate)p).base,to,ch,bytes)},
 receive=proc(p:rawptr,dst:[]u8)->tr.Received{
  g:=cast(^Gate)p
  for &s,i in g.saved[:g.count] {
   if s.held && !s.released && ((s.snapshot&&g.release_snapshots)||(i==g.old_index&&g.old_captured&&g.release_old)) {
    packet:=s.packet
    if len(dst)<packet.count{packet.state=.Buffer_Too_Small;return packet}
    if bd.hash_bytes(s.data.bytes)!=s.hash{g.error="held bytes changed";return {state=.Too_Large}}
    copy(dst,s.data.bytes);s.released=true;return packet
   }
  }
  for _ in 0..<64 {
   packet:=tr.receive(&g.base,dst);if packet.state!=.Received{return packet}
   i:=save(g,packet,dst[:packet.count]);if i<0{return {state=.Too_Large}}
   saved:=&g.saved[i]
   if g.hold_snapshots && saved.snapshot {saved.held=true;continue}
   if g.hold_first_action && !g.old_captured && saved.kind==ACTION_KIND {
    saved.held=true;g.old_captured=true;g.old_index=i;continue
   }
   return packet
  }
  return {state=.Empty}
 },
 status=proc(p:rawptr)->tr.Status{return tr.status(&(cast(^Gate)p).base)},
 connected=proc(p:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Gate)p).base,peer)},
 generation=proc(p:rawptr,peer:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^Gate)p).base,peer)},
 }
}
server_pump :: proc(t:^testing.T,c:^Case,now:u64)->bool {
 return check(t,tr.memory_advance(&c.pair.memory,now),"public Memory time") && check(t,rec.link_pump(&c.links[0],now),"public server Link pump") && none(t,net.server_pump(&c.pair.server,now),"public server pump") && check(t,c.gates[0].error=="","server gate status")
}
client_pump :: proc(t:^testing.T,c:^Case,now:u64)->bool {
 return check(t,tr.memory_advance(&c.pair.memory,now),"public Memory time") && check(t,rec.link_pump(&c.links[1],now),"public client Link pump") && none(t,net.client_pump(&c.pair.client,now),"public client pump") && check(t,c.gates[1].error=="","client gate status")
}
complete_same :: proc(c:^Case,a,z:^r.Complete_Checkpoint(f.Game,net.Net_Event(f.Event)))->bool {
 av,ae:=net.complete_view(c.pair.codec.value,a,&c.pair.server.physics.schemas.state,&c.pair.server.physics.schemas.occurrence);if ae!=.None{return false};defer net.complete_view_destroy(&av)
 zv,ze:=net.complete_view(c.pair.codec.value,z,&c.pair.server.physics.schemas.state,&c.pair.server.physics.schemas.occurrence);if ze!=.None{return false};defer net.complete_view_destroy(&zv)
 asig,ase:=bd.sign(av.frame);zsig,zse:=bd.sign(zv.frame);same:=ase==.None&&zse==.None&&bd.compare(asig,zsig)==.Match
 for part in bd.Part{same=same&&mem.compare(av.frame.parts[part],zv.frame.parts[part])==0}
 return same
}
open :: proc(t:^testing.T,c:^Case)->bool {
 p:=&c.pair;cfg:=b.recovery_config_default();cfg.profile=f.PROFILE
 assets:[4]b.Recovery_Asset;for a,i in f.assets(){assets[i]={id=a.id,kind=b.Recovery_Asset_Kind(a.kind),a=a.a,b=a.b,radius=a.radius}}
 status:b.Status;p.catalog,status=b.recovery_catalog_create(cfg,assets[:]);if !check(t,status==.Ok,"catalog"){return false}
 identity,is:=b.recovery_catalog_identity(&p.catalog);if !check(t,is==.Ok,"catalog identity"){return false}
 build:u64;for byte,i in identity.build_target[:8]{build|=u64(byte)<<uint(i*8)}
 config:=ph.config_default(f.ASSET_DECLARATION,build);config.initial_dynamic_bodies=4;config.assets[0].id=3;config.assets[1].id=4
 world,game,ws:=f.world(4);if !check(t,ws==.Ok,"fixture world"){return false}
 initial,error:=ph.checkpoint_make(r.Frame(f.Game){state=game},net.Net_Event(f.Event),world,config);b.world_destroy(&world)
 if !check(t,error==.None,"initial complete"){return false};defer r.complete_checkpoint_destroy(&initial)
 if !none(t,ph.network_codec_init(&p.codec,&p.catalog,config,ar.rules()),"existing fixture codec"){return false}
 if !check(t,tr.memory_init(&p.memory,cfg={2,64,tr.MAX_PACKET_BYTES,4096}),"Memory"){return false}
 for &e,i in p.endpoints{if !check(t,tr.memory_open(&p.memory,&e,tr.Peer_Id(i+1)),"Memory endpoint"){return false}}
 for &g,i in c.gates {g.base=tr.memory_transport(&p.endpoints[i]);g.codec=&p.codec;if !check(t,rec.link_init(&c.links[i],gate_wire(&g)),"public Link"){return false}}
 model:=net.Model(f.Game,f.Control,f.Action,f.Event,2){complete_state=true,complete_codec=p.codec.value,step=ar.step,action=ar.action,control_valid=f.control_valid,action_valid=f.action_valid,hold=f.hold,action_timing=.Receipt,state_valid=proc(g:f.Game)->bool{return g.initial==4}}
 network:=net.physics_config_default();network.snapshot_every=1
 if !none(t,net.server_init_complete(&p.server,&initial,model,rec.link_game_transport(&c.links[0]),network,local_seat=1),"server"){return false}
 if !none(t,net.server_set_local_token(&p.server,net.Token{0=1}),"server token"){return false}
 if !none(t,net.client_init(&p.client,model,rec.link_game_transport(&c.links[1]),net.Token{0=2},cfg=network),"client"){return false}
 c.gates[1].chunk=&p.client.physics.schemas.chunk
 if !client_pump(t,c,0)||!server_pump(t,c,0)||!none(t,net.server_step(&p.server),"membership")||!client_pump(t,c,0)||!server_pump(t,c,0){return false}
 return check(t,p.client.phase==.Running && p.client.timeline.confirmed==1,"actual initial Welcome")
}
close :: proc(t:^testing.T,c:^Case,report:^Report) {
 p:=&c.pair;drops:=true
 if p.client.initialized{drops=net.client_destroy(&p.client)==.None&&drops}
 if p.server.initialized{drops=net.server_destroy(&p.server)==.None&&drops}
 for &link in c.links {if link.ready{drops=rec.link_destroy(&link)==.None&&drops}}
 for &gate,index in c.gates {
  for &saved,i in gate.saved[:gate.count] {
   name:=fmt.aprintf("raw-%d-%03d.bin",index,i);assert(os.write_entire_file(name,saved.data.bytes)==nil);delete(name)
   check(t,bd.hash_bytes(saved.data.bytes)==saved.hash,"all actual raw bytes unchanged")
   record:=struct {gate,index:int,kind:u16,tick:u64,from:tr.Peer_Id,channel:tr.Channel,transport_generation:u64,held,released,snapshot:bool,sha256:bd.Digest}{index,i,saved.kind,saved.tick,saved.packet.from,saved.packet.channel,saved.packet.generation,saved.held,saved.released,saved.snapshot,saved.hash}
   metadata:=fmt.aprintf("raw-%d-%03d.json",index,i);write_json(metadata,record);delete(metadata)
   net.complete_data_destroy(&saved.data)
  }
 }
 if p.codec.ready{drops=ph.network_codec_destroy(&p.codec)==.None&&drops}
 if p.catalog._handle!=nil{drops=b.recovery_catalog_destroy(&p.catalog)==.Ok&&drops}
 if len(p.memory.packets)>0{tr.memory_destroy(&p.memory)}
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 report.native_live=engine.live_bytes;report.wrapper_live=wrapper.live_bytes;report.provider_live=ph.allocation_stats().live_bytes
 report.all_drops_ok=drops&&es==.Ok&&ws==.Ok
 report.reached.cleanup=true
 check(t,report.all_drops_ok&&report.native_live==0&&report.wrapper_live==0&&report.provider_live==0,"whole Native/provider/drop cleanup")
}

@(test)
case_a_new_scope_resend_first_admission_then_old_scope_reject :: proc(t:^testing.T){
 tracking:mem.Tracking_Allocator;backing:=context.allocator;mem.tracking_allocator_init(&tracking,backing,backing);context.allocator=mem.tracking_allocator(&tracking)
 c:=new(Case);report:=Report{schema=1,scope="CASE_A_generic4_staticOFFddff_nilOwner_publicLinkMemory_controlledReliablehold_reorder_NOTENet_NOTSDK32",stage="open"}
 contract,contract_status:=b.domain_contract_get();if contract_status==.Ok{report.native_build=contract.build;report.native_target=contract.target}
 defer {
  close(t,c,&report);free(c);report.odin_live=u64(tracking.current_memory_allocated);check(t,report.odin_live==0,"Odin allocations0")
  context.allocator=backing;mem.tracking_allocator_destroy(&tracking);write_json("case-report.json",report)
 }
 if !open(t,c){return};p:=&c.pair;report.setup_ok=true
 report.epoch=p.client.cfg.epoch;report.generation=p.client.generation;report.old_serial=p.client.serial;report.player=p.client.token;report.seat=p.client.seat
 report.stage="hold old snapshots and advance authority20";c.gates[1].hold_snapshots=true
 for tick in 2..=20 {if !server_pump(t,c,u64(tick)*17)||!none(t,net.server_step(&p.server),"ordinary authority advance"){return}}
 if !client_pump(t,c,340){return}
 // Diagnostic-only snapshot immediately before the ORIGINAL unchanged guard.
 report.reached.baseline_guard=true
 report.guard_client_phase=p.client.phase;report.guard_client_head=p.client.timeline.head;report.guard_client_confirmed=p.client.timeline.confirmed
 report.guard_client_serial=p.client.serial;report.guard_client_generation=p.client.generation;report.guard_epoch=p.client.cfg.epoch
 report.guard_cfg_prediction=u64(p.client.cfg.max_prediction);report.guard_cfg_future=u64(p.client.cfg.max_future);report.guard_cfg_history=u64(p.client.cfg.history)
 report.guard_cfg_snapshot_every=u64(p.client.cfg.snapshot_every);report.guard_cfg_lead=u64(p.client.cfg.lead);report.guard_actual_lead=u64(p.client.lead_ticks)
 report.guard_catchups=p.client.stats.snapshot_catchups;report.guard_resyncs=p.client.stats.resyncs;report.guard_corrections=p.client.stats.corrections
 report.guard_replayed=p.client.stats.replayed_ticks;report.guard_stalls=p.client.stats.stalls;report.guard_facts=p.client.facts_contiguous;report.guard_authority_seen=p.client.authority_tick_seen
 report.guard_server_head=p.server.timeline.head;report.guard_server_confirmed=p.server.timeline.confirmed
 for &peer in p.server.peers {if peer.seat==report.seat&&!peer.local {
  report.guard_peer_found=true;report.guard_peer_serial=peer.serial;report.guard_peer_generation=peer.generation
  report.guard_peer_count=peer.action_count;report.guard_peer_received=peer.action_received;report.guard_peer_settled=peer.action_settled;report.guard_peer_phase=i32(peer.phase)
 }}
 for &saved in c.gates[1].saved[:c.gates[1].count] {if saved.snapshot {
  report.guard_snapshot_total+=1
  if report.guard_snapshot_copied<len(report.guard_snapshots) {report.guard_snapshots[report.guard_snapshot_copied]={saved.kind,saved.tick,saved.held,saved.released,saved.packet.channel};report.guard_snapshot_copied+=1}
  else {report.guard_snapshot_overflow=true}
 }}
 if !check(t,p.client.phase==.Running&&p.client.timeline.confirmed==3&&p.client.timeline.head==3,"public baseline Running/head3/confirmed3; target20-baseline3>8"){return}
 report.stage="issue and hold first actual reliable Motor";c.gates[0].hold_first_action=true
 report.original_requested=p.client.timeline.head+1;report.value={kind=.Motor}
 sequence,issue_error:=net.client_issue(&p.client,report.value);report.sequence=sequence
 report.reached.action_issue=true
 if !none(t,issue_error,"ONE client_issue")||!check(t,sequence==1,"sequence1"){return}
 for queued in p.client.actions[:p.client.action_count]{if queued.sequence==sequence{report.submitted=queued.tick}}
 if !server_pump(t,c,340)||!check(t,c.gates[0].old_captured,"actual first Action captured belowLink"){return}
 peer_index:=-1;for peer,i in p.server.peers{if peer.seat==report.seat&&!peer.local{peer_index=i}}
 if !check(t,peer_index>=0,"actual peer binding"){return};peer:=&p.server.peers[peer_index]
 report.pre_received=peer.action_received;report.pre_count=u64(peer.action_count)
 if !check(t,report.pre_received==0&&report.pre_count==0,"NO old-scope admission"){return}
 first,first_ok:=wire_action(c,&c.gates[0].saved[c.gates[0].old_index]);report.first=first
 report.reached.first_wire=true
 if !check(t,first_ok&&first.channel==.Reliable&&first.serial==report.old_serial&&first.epoch==report.epoch&&first.generation==report.generation&&first.sequence==sequence&&first.tick==report.submitted&&first.value==report.value,"actual old Action wire scope/logical tuple"){return}
 report.stage="release genuine oldSnapshot2 then actual aheadSnapshot20";c.gates[1].hold_snapshots=false;c.gates[1].release_snapshots=true
 report.release_before=client_state(p)
 if !client_pump(t,c,340){return}
 report.release_after=client_state(p)
 if !check(t,p.client.timeline.confirmed>=3&&p.client.timeline.head==report.release_before.head,"oldSnapshot2 preserves confirmed>=baseline3 and unchanged head"){return}
 if !server_pump(t,c,340){return}
 report.ack_server_observed=true;report.ack_server_head=p.server.timeline.head;report.ack_server_confirmed=p.server.timeline.confirmed
 report.ack_peer_serial=peer.serial;report.ack_peer_received=peer.action_received;report.ack_peer_count=peer.action_count
 tx:=&p.server.physics.tx[peer_index];report.ack_server_tx_tick=tx.tick;report.ack_server_tx_id=tx.id;report.ack_server_tx_purpose=tx.purpose;report.ack_server_tx_waiting=tx.waiting_ack
 // Inspect only genuinely captured wire bytes after the EXISTING server pump.
 held_found:=false
 for &saved in c.gates[1].saved[:c.gates[1].count] {if saved.snapshot&&saved.tick==2 {
  meta,_,ir:=sc.inspect(saved.data.bytes)
  _,body,ur:=sc.unpack_bytes(p.client.physics.schemas.chunk.fingerprint,saved.data.bytes,meta)
  if ir.error==.None&&ur.error==.None&&len(body)>=p.client.physics.schemas.chunk.wire_size {
   decoded:=sc.decode(&p.client.physics.schemas.chunk,&report.held_header,body[:p.client.physics.schemas.chunk.wire_size]);held_found=decoded.error==.None
  }
 }}
 for &saved in c.gates[0].saved[:c.gates[0].count] {
  meta,fingerprint,ir:=sc.inspect(saved.data.bytes)
  if ir.error==.None&&fingerprint==p.client.physics.schemas.ack.fingerprint {
   ack:net.Physics_Ack;_,decoded:=sc.unpack(&p.client.physics.schemas.ack,&ack,saved.data.bytes,meta)
   if decoded.error==.None&&ack.id==report.held_header.id {
    report.ack_observed=true;report.ack=ack;report.ack_decode_status=decoded.error;report.ack_hash=saved.hash
    report.ack_matches=held_found&&saved.packet.channel==.Reliable&&ack.generation==report.held_header.generation&&ack.serial==report.held_header.serial&&ack.digest==report.held_header.digest
   }
  }
 }
 if !check(t,report.ack_observed&&report.ack_matches,"actual Physics_Ack matches heldSnapshot2 id/digest/serial"){return}
 if !client_pump(t,c,340){return}
 report.after_ahead=client_state(p)
 report.trigger=p.client.resync_notice
 report.reached.resync_notice=true
 if !check(t,p.client.phase==.Resyncing&&report.trigger.reason==.Snapshot_Ahead&&report.trigger.incoming_tick==20,"actual public Snapshot_Ahead trigger"){return}
 report.stage="public Resync and canonical Welcome";
 if !client_pump(t,c,341)||!server_pump(t,c,341)||!client_pump(t,c,341){return}
 report.new_serial=p.client.serial
 report.reached.welcome=true
 if !check(t,p.client.phase==.Running&&report.new_serial>report.old_serial&&p.client.generation==report.generation&&p.client.cfg.epoch==report.epoch,"actual sameepoch Welcome newserial"){return}
 if !server_pump(t,c,341){return}
 found:=false
 for &saved in c.gates[0].saved[:c.gates[0].count]{if saved.kind==ACTION_KIND&&!saved.held {
  candidate,ok:=wire_action(c,&saved);if ok&&candidate.sequence==sequence{report.resend=candidate;found=true}
 }}
 report.new_received=peer.action_received;report.new_count=u64(peer.action_count)
 report.reached.resend=true
 report.logical_unchanged=found&&report.first.epoch==report.resend.epoch&&report.first.generation==report.resend.generation&&report.first.sequence==report.resend.sequence&&report.first.tick==report.resend.tick&&report.first.value==report.resend.value&&report.resend.serial==report.new_serial
 if !check(t,report.logical_unchanged&&report.new_received==1&&report.new_count==1,"automatic currentserial resend FIRST admission"){return}
 report.stage="ordinary execution and complete confirmation"
 if !none(t,net.server_step(&p.server),"ordinary Receipt execution")||!client_pump(t,c,342){return}
 report.execution_tick=p.server.timeline.head
 report.reached.execution=true
 entry,entry_ok:=net.server_accepted_input(&p.server,report.execution_tick)
 if !check(t,entry_ok&&entry.batch.has_action[1]&&entry.batch.sequences[1]==sequence&&entry.decisions.applied[1]&&entry.decisions.drivers[1].serial==report.new_serial,"actual accepted execution row"){return}
 report.full5_equal=ar.full_pair(t,p,report.execution_tick);if !report.full5_equal{return}
 report.reached.full5=true
 outcomes:[net.ACTION_CAPACITY]net.Action_Outcome;recovered:[net.ACTION_CAPACITY]bool
 count:=net.client_outcomes(&p.client,outcomes[:],recovered[:]);report.outcome_once=count==1&&outcomes[0].sequence==sequence&&outcomes[0].applied&&outcomes[0].tick==report.execution_tick
 report.reached.outcome=true
 changes:[512]view.Change(net.Net_Event(f.Event));n:=view.drain(&p.client.journal,changes[:]);results:=0
 for change in changes[:n]{event:=change.occurrence.value;if change.confirmed&&event.kind==.Action_Result&&event.sequence==sequence{results+=1}}
 report.confirmed_result_once=results==1
 if !check(t,report.outcome_once&&report.confirmed_result_once,"one actual outcome/confirmed Action_Result journal delivery"){return}
 report.settled=peer.action_settled
 before,be:=r.capture_complete(&p.server.timeline,p.server.timeline.head);if !check(t,be==.None,"before old copy complete"){return};defer r.complete_checkpoint_destroy(&before)
 old_received,old_count,rejected:=peer.action_received,peer.action_count,p.server.stats.rejected_packets
 c.gates[0].release_old=true;report.stage="late old copy stale rejection"
 if !server_pump(t,c,342){return}
 report.reached.late_copy=true
 after,ae:=r.capture_complete(&p.server.timeline,p.server.timeline.head);if !check(t,ae==.None,"after old copy complete"){return};defer r.complete_checkpoint_destroy(&after)
 equal:=complete_same(c,&before,&after)
 report.old_rejected_delta=p.server.stats.rejected_packets-rejected
 report.old_state_unchanged=equal&&peer.action_received==old_received&&peer.action_count==old_count&&peer.action_settled==report.settled
 report.first_hash_unchanged=bd.hash_bytes(c.gates[0].saved[c.gates[0].old_index].data.bytes)==report.first.hash
 if !check(t,report.old_rejected_delta==1&&report.old_state_unchanged&&report.first_hash_unchanged,"old scope rejects without second admission/statechange"){return}
 report.ok=true;report.stage="DONE"
}
